import Foundation
import SwiftData
import ReceiptVaultCore

/// Stages captured files into the app sandbox immediately (spec 5.5
/// acceptance: "Store scanner-produced page image(s) locally before
/// OCR/upload"), then uploads to the private `proof-files` bucket using
/// the deterministic path convention from `Attachment.storagePath(...)` so
/// a retried upload after a network failure overwrites the same object
/// instead of creating an orphan (spec 9.4, 10.1).
final class SupabaseAttachmentService: AttachmentService {
    private let backend: SupabaseBackend
    private let modelContext: ModelContext
    private let store = LocalAttachmentFileStore()

    init(backend: SupabaseBackend, modelContext: ModelContext) {
        self.backend = backend
        self.modelContext = modelContext
    }

    func stage(_ file: LocalAttachment, workspaceID: UUID, purchaseID: UUID?, itemID: UUID?) throws -> StagedAttachment {
        try store.stage(file, workspaceID: workspaceID, purchaseID: purchaseID, itemID: itemID)
    }

    func upload(_ attachment: StagedAttachment) async throws {
        let data = try Data(contentsOf: attachment.localFileURL)
        try await backend.uploadFile(data: data, storagePath: attachment.storagePath, mimeType: attachment.mimeType)
    }

    func fetchDisplayURL(storagePath: String) async throws -> URL {
        // Prefer the local cached copy so Purchase Detail/attachment
        // previews never wait on the network for something already on
        // device (spec 10.2: signed URLs only "when an API/preview
        // requires a URL outside the authenticated SDK flow").
        if let local = store.localFileURL(forStoragePath: storagePath), store.fileExists(at: local) {
            return local
        }
        return try await backend.createSignedURL(storagePath: storagePath)
    }

    func delete(storagePath: String) async throws {
        try await backend.deleteFile(storagePath: storagePath)
        store.deleteLocal(storagePath: storagePath)
    }
}
