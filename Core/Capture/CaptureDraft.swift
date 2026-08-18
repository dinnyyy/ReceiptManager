import Foundation

/// In-memory only, before OCR/Review has produced anything worth saving.
/// The id assigned here becomes the eventual `Purchase.id` (spec 5.5
/// acceptance: "generate client UUID purchase draft" as soon as capture
/// completes, before any network work begins).
struct CaptureDraft: Identifiable {
    let id: UUID
    var fileURLs: [URL]
    var source: AnalyticsEvent.CaptureSource

    init(id: UUID = UUID(), fileURLs: [URL], source: AnalyticsEvent.CaptureSource) {
        self.id = id
        self.fileURLs = fileURLs
        self.source = source
    }

    static func manual() -> CaptureDraft {
        CaptureDraft(fileURLs: [], source: .manual)
    }
}
