import Foundation

/// Original evidence: a receipt image, invoice PDF, item photo, serial
/// label photo, warranty document, or valuation (spec 6.5, 7). Always
/// belongs to a purchase, an item, or both - never neither (enforced again
/// at the database layer by the `attachments` check constraint).
public struct Attachment: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let workspaceID: UUID
    public var purchaseID: UUID?
    public var itemID: UUID?
    public var type: AttachmentType
    public var storagePath: String
    public var originalFilename: String?
    public var mimeType: String
    public var bytes: Int?
    public var sha256: String?
    public var pageCount: Int?
    public var createdAt: Date
    public var syncState: SyncState

    public init(
        id: UUID = UUID(),
        workspaceID: UUID,
        purchaseID: UUID? = nil,
        itemID: UUID? = nil,
        type: AttachmentType,
        storagePath: String,
        originalFilename: String? = nil,
        mimeType: String,
        bytes: Int? = nil,
        sha256: String? = nil,
        pageCount: Int? = nil,
        createdAt: Date = Date(),
        syncState: SyncState = .localOnly
    ) {
        self.id = id
        self.workspaceID = workspaceID
        self.purchaseID = purchaseID
        self.itemID = itemID
        self.type = type
        self.storagePath = storagePath
        self.originalFilename = originalFilename
        self.mimeType = mimeType
        self.bytes = bytes
        self.sha256 = sha256
        self.pageCount = pageCount
        self.createdAt = createdAt
        self.syncState = syncState
    }

    public var isValid: Bool { purchaseID != nil || itemID != nil }

    /// Deterministic storage path convention (spec 10.1):
    /// `{workspace_id}/purchases/{purchase_id}/{attachment_id}.{ext}` or
    /// `{workspace_id}/items/{item_id}/{attachment_id}.{ext}`. Deterministic
    /// so repeated upload attempts after a network failure overwrite the
    /// same object instead of creating orphaned duplicates (spec 9.4:
    /// "Uploads are idempotent using deterministic storage path").
    public static func storagePath(
        workspaceID: UUID, purchaseID: UUID?, itemID: UUID?, attachmentID: UUID, fileExtension: String
    ) -> String? {
        let ext = fileExtension.hasPrefix(".") ? String(fileExtension.dropFirst()) : fileExtension
        if let purchaseID {
            return "\(workspaceID)/purchases/\(purchaseID)/\(attachmentID).\(ext)"
        }
        if let itemID {
            return "\(workspaceID)/items/\(itemID)/\(attachmentID).\(ext)"
        }
        return nil
    }
}
