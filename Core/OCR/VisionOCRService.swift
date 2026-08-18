import Vision
import UIKit
import PDFKit
import Foundation
import ReceiptVaultCore

/// On-device text recognition via `VNRecognizeTextRequest` (spec 6.2):
/// "use Apple Vision text recognition on-device for printed receipts...
/// Do not require a cloud AI/OCR provider for ordinary receipts." PDF
/// pages are rendered to images first since Vision's text request operates
/// on images, not PDF content streams directly.
final class VisionOCRService: OCRService {
    func recognizeText(imageFileURLs: [URL]) async throws -> OCRResult {
        var allLines: [String] = []
        for url in imageFileURLs {
            let images = try Self.images(from: url)
            for image in images {
                let lines = try await Self.recognizeText(in: image)
                allLines.append(contentsOf: lines)
            }
        }
        // Spec 5.6 acceptance: "OCR failure is non-fatal." An empty result
        // is not thrown here - the caller (ReviewViewModel) still shows the
        // Review screen with blank fields and the original evidence intact
        // (spec 6.2, 6.3), it just has nothing to prefill.
        return OCRResult(lines: allLines)
    }

    private static func images(from url: URL) throws -> [UIImage] {
        if url.pathExtension.lowercased() == "pdf" {
            guard let document = PDFDocument(url: url), document.pageCount > 0 else {
                throw OCRServiceError.imageLoadFailed(url)
            }
            var images: [UIImage] = []
            for pageIndex in 0..<document.pageCount {
                guard let page = document.page(at: pageIndex) else { continue }
                let bounds = page.bounds(for: .mediaBox)
                guard bounds.width > 0, bounds.height > 0 else { continue }
                let renderer = UIGraphicsImageRenderer(size: bounds.size)
                let image = renderer.image { context in
                    UIColor.white.set()
                    context.fill(bounds)
                    context.cgContext.translateBy(x: 0, y: bounds.size.height)
                    context.cgContext.scaleBy(x: 1, y: -1)
                    page.draw(with: .mediaBox, to: context.cgContext)
                }
                images.append(image)
            }
            guard !images.isEmpty else { throw OCRServiceError.imageLoadFailed(url) }
            return images
        }

        guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else {
            throw OCRServiceError.imageLoadFailed(url)
        }
        return [image]
    }

    private static func recognizeText(in image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage else { return [] }
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                // Vision doesn't guarantee reading order; approximate
                // top-to-bottom by vertical position (Vision's coordinate
                // origin is bottom-left, so higher y = higher on the page)
                // per spec 6.2 "preserving line order as well as possible."
                let lines = observations
                    .sorted { $0.boundingBox.origin.y > $1.boundingBox.origin.y }
                    .compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
