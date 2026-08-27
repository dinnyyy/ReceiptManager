import Foundation
import CryptoKit
import ReceiptVaultCore

enum AttachmentServiceError: Error {
    case missingParent
    case fileReadFailed
}

/// The on-device half of attachment handling (stage into the sandbox,
/// hash, look up, delete) - shared by `SupabaseAttachmentService` and
/// `LocalOnlyAttachmentService` so the local-only dev mode isn't a
/// separate reimplementation of this logic.
struct LocalAttachmentFileStore {
    private let fileManager = FileManager.default

    var attachmentsDirectory: URL {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = documents.appendingPathComponent("Attachments", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    func stage(_ file: LocalAttachment, workspaceID: UUID, purchaseID: UUID?, itemID: UUID?) throws -> StagedAttachment {
        guard purchaseID != nil || itemID != nil else { throw AttachmentServiceError.missingParent }

        let attachmentID = UUID()
        let ext = file.fileURL.pathExtension.isEmpty ? "jpg" : file.fileURL.pathExtension
        guard let storagePath = Attachment.storagePath(
            workspaceID: workspaceID, purchaseID: purchaseID, itemID: itemID, attachmentID: attachmentID, fileExtension: ext
        ) else { throw AttachmentServiceError.missingParent }

        let localURL = attachmentsDirectory.appendingPathComponent("\(attachmentID).\(ext)")
        try fileManager.copyItem(at: file.fileURL, to: localURL)

        guard let data = try? Data(contentsOf: localURL) else { throw AttachmentServiceError.fileReadFailed }
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()

        return StagedAttachment(
            id: attachmentID, localFileURL: localURL, storagePath: storagePath,
            mimeType: file.mimeType, bytes: data.count, sha256: hash
        )
    }

    func localFileURL(forStoragePath storagePath: String) -> URL? {
        guard let filename = storagePath.split(separator: "/").last else { return nil }
        return attachmentsDirectory.appendingPathComponent(String(filename))
    }

    func fileExists(at url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }

    func deleteLocal(storagePath: String) {
        if let local = localFileURL(forStoragePath: storagePath) {
            try? fileManager.removeItem(at: local)
        }
    }
}
