import Foundation
import CryptoKit
import SwiftData
import ReceiptVaultCore

enum AttachmentServiceError: Error {
    case missingParent
    case fileReadFailed
}

/// Stages captured files into the app sandbox immediately (spec 5.5
/// acceptance: "Store scanner-produced page image(s) locally before
/// OCR/upload"), then uploads to the private `proof-files` bucket using
/// the deterministic path convention from `Attachment.storagePath(...)` so
/// a retried upload after a network failure overwrites the same object
/// instead of creating an orphan (spec 9.4, 10.1).
final class SupabaseAttachmentService: AttachmentService {
    private let backend: SupabaseBackend
    private let modelContext: ModelContext
    private let fileManager = FileManager.default

    init(backend: SupabaseBackend, modelContext: ModelContext) {
        self.backend = backend
        self.modelContext = modelContext
    }

    private var attachmentsDirectory: URL {
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

    func upload(_ attachment: StagedAttachment) async throws {
        let data = try Data(contentsOf: attachment.localFileURL)
        try await backend.uploadFile(data: data, storagePath: attachment.storagePath, mimeType: attachment.mimeType)
    }

    func fetchDisplayURL(storagePath: String) async throws -> URL {
        // Prefer the local cached copy so Purchase Detail/attachment
        // previews never wait on the network for something already on
        // device (spec 10.2: signed URLs only "when an API/preview
        // requires a URL outside the authenticated SDK flow").
        if let local = localFileURL(forStoragePath: storagePath), fileManager.fileExists(atPath: local.path) {
            return local
        }
        return try await backend.createSignedURL(storagePath: storagePath)
    }

    func delete(storagePath: String) async throws {
        try await backend.deleteFile(storagePath: storagePath)
        if let local = localFileURL(forStoragePath: storagePath) {
            try? fileManager.removeItem(at: local)
        }
    }

    private func localFileURL(forStoragePath storagePath: String) -> URL? {
        guard let filename = storagePath.split(separator: "/").last else { return nil }
        return attachmentsDirectory.appendingPathComponent(String(filename))
    }
}
