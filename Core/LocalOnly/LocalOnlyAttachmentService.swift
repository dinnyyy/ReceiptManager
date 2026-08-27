import Foundation
import ReceiptVaultCore

/// Temporary dev-mode attachment handling: stages files into the app
/// sandbox exactly like the real service, but never uploads anywhere -
/// everything stays on-device. See `LocalOnlyAuthService` for why this
/// exists.
final class LocalOnlyAttachmentService: AttachmentService {
    private let store = LocalAttachmentFileStore()

    func stage(_ file: LocalAttachment, workspaceID: UUID, purchaseID: UUID?, itemID: UUID?) throws -> StagedAttachment {
        try store.stage(file, workspaceID: workspaceID, purchaseID: purchaseID, itemID: itemID)
    }

    func upload(_ attachment: StagedAttachment) async throws {
        // No backend to upload to in local-only mode.
    }

    func fetchDisplayURL(storagePath: String) async throws -> URL {
        guard let local = store.localFileURL(forStoragePath: storagePath), store.fileExists(at: local) else {
            throw AttachmentServiceError.fileReadFailed
        }
        return local
    }

    func delete(storagePath: String) async throws {
        store.deleteLocal(storagePath: storagePath)
    }
}
