import Foundation
import ReceiptVaultCore

public struct OCRResult: Sendable {
    /// Text in reading order, one entry per recognized line, across all
    /// pages. Kept as a flat array (not per-page) because
    /// `ReceiptFieldScorer` scores line-by-line regardless of page
    /// boundaries.
    public let lines: [String]
    public let rawText: String

    public init(lines: [String]) {
        self.lines = lines
        self.rawText = lines.joined(separator: "\n")
    }
}

/// On-device text recognition (spec 6.2, 9.3). Kept behind a protocol so a
/// cloud fallback for difficult/handwritten documents can be added later
/// (spec 6.3) without touching Capture/Review screens. The real
/// implementation (`VisionOCRService`, Core/OCR) wraps
/// `VNRecognizeTextRequest`; this protocol itself has no VisionKit/Vision
/// import so it stays testable.
public protocol OCRService {
    func recognizeText(imageFileURLs: [URL]) async throws -> OCRResult
}

public enum OCRServiceError: Error {
    case noReadablePage
    case imageLoadFailed(URL)
}
