import Foundation
import ReceiptVaultCore

public struct LocalAttachment: Sendable {
    public let fileURL: URL
    public let type: AttachmentType
    public let mimeType: String
    public let originalFilename: String?

    public init(fileURL: URL, type: AttachmentType, mimeType: String, originalFilename: String? = nil) {
        self.fileURL = fileURL
        self.type = type
        self.mimeType = mimeType
        self.originalFilename = originalFilename
    }
}

public struct StagedAttachment: Sendable {
    public let id: UUID
    public let localFileURL: URL
    public let storagePath: String
    public let mimeType: String
    public let bytes: Int
    public let sha256: String

    public init(id: UUID, localFileURL: URL, storagePath: String, mimeType: String, bytes: Int, sha256: String) {
        self.id = id
        self.localFileURL = localFileURL
        self.storagePath = storagePath
        self.mimeType = mimeType
        self.bytes = bytes
        self.sha256 = sha256
    }
}

/// Stage a captured file into the app sandbox, then upload it to private
/// Supabase Storage (spec 9.3, 10.1, 10.2). Uploads are idempotent via the
/// deterministic storage path in `Attachment.storagePath(...)`.
public protocol AttachmentService {
    func stage(_ file: LocalAttachment, workspaceID: UUID, purchaseID: UUID?, itemID: UUID?) throws -> StagedAttachment
    func upload(_ attachment: StagedAttachment) async throws
    /// Returns a short-lived signed URL or a local cache URL suitable for
    /// display (spec 10.2: "short-lived signed URLs only when required").
    func fetchDisplayURL(storagePath: String) async throws -> URL
    func delete(storagePath: String) async throws
}
