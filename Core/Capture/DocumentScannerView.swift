import SwiftUI
import VisionKit

/// Wraps `VNDocumentCameraViewController` (spec 5.5, 9.1): native
/// auto-crop/perspective-correction document scanning, multi-page support.
/// No SwiftUI-native equivalent exists, so this is a thin
/// `UIViewControllerRepresentable`. Writes each scanned page to a temp
/// file immediately (spec 5.5 acceptance: "Store scanner-produced page
/// image(s) locally before OCR/upload") and hands back file URLs, not
/// in-memory `UIImage`s, so the caller never has to worry about losing
/// data if OCR takes a moment to start.
struct DocumentScannerView: UIViewControllerRepresentable {
    let onComplete: (_ pageFileURLs: [URL]) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete, onCancel: onCancel)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onComplete: (_ pageFileURLs: [URL]) -> Void
        let onCancel: () -> Void

        init(onComplete: @escaping (_ pageFileURLs: [URL]) -> Void, onCancel: @escaping () -> Void) {
            self.onComplete = onComplete
            self.onCancel = onCancel
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var urls: [URL] = []
            for pageIndex in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: pageIndex)
                guard let data = image.jpegData(compressionQuality: 0.9) else { continue }
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("jpg")
                do {
                    try data.write(to: url)
                    urls.append(url)
                } catch {
                    continue
                }
            }
            // Spec 5.5 acceptance: "At least one readable page required."
            // An empty result (every page somehow failed to write) is
            // treated the same as a cancel - never hand Review a draft
            // with zero evidence.
            if urls.isEmpty {
                onCancel()
            } else {
                onComplete(urls)
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            onCancel()
        }
    }
}
