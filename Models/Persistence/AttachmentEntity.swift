import SwiftData
import Foundation
import ReceiptVaultCore

@Model
final class AttachmentEntity {
    @Attribute(.unique) var id: UUID
    var workspaceID: UUID
    var typeRaw: String
    var storagePath: String
    var originalFilename: String?
    var mimeType: String
    var bytes: Int?
    var sha256: String?
    var pageCount: Int?
    var localFilePath: String? // sandbox-relative path to the staged/cached file, if present locally
    var createdAt: Date
    var syncStateRaw: String

    var purchase: PurchaseEntity?
    var item: ItemEntity?

    init(
        id: UUID = UUID(),
        workspaceID: UUID,
        typeRaw: String,
        storagePath: String,
        originalFilename: String? = nil,
        mimeType: String,
        bytes: Int? = nil,
        sha256: String? = nil,
        pageCount: Int? = nil,
        localFilePath: String? = nil,
        createdAt: Date = Date(),
        syncStateRaw: String = SyncState.localOnly.rawValue
    ) {
        self.id = id
        self.workspaceID = workspaceID
        self.typeRaw = typeRaw
        self.storagePath = storagePath
        self.originalFilename = originalFilename
        self.mimeType = mimeType
        self.bytes = bytes
        self.sha256 = sha256
        self.pageCount = pageCount
        self.localFilePath = localFilePath
        self.createdAt = createdAt
        self.syncStateRaw = syncStateRaw
    }
}

extension AttachmentEntity {
    var type: AttachmentType {
        get { AttachmentType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }

    var syncState: SyncState {
        get { SyncState(rawValue: syncStateRaw) ?? .localOnly }
        set { syncStateRaw = newValue.rawValue }
    }

    func toDomain() -> Attachment {
        Attachment(
            id: id, workspaceID: workspaceID, purchaseID: purchase?.id, itemID: item?.id, type: type,
            storagePath: storagePath, originalFilename: originalFilename, mimeType: mimeType,
            bytes: bytes, sha256: sha256, pageCount: pageCount, createdAt: createdAt, syncState: syncState
        )
    }

    convenience init(domain attachment: Attachment, localFilePath: String? = nil) {
        self.init(
            id: attachment.id, workspaceID: attachment.workspaceID, typeRaw: attachment.type.rawValue,
            storagePath: attachment.storagePath, originalFilename: attachment.originalFilename,
            mimeType: attachment.mimeType, bytes: attachment.bytes, sha256: attachment.sha256,
            pageCount: attachment.pageCount, localFilePath: localFilePath, createdAt: attachment.createdAt,
            syncStateRaw: attachment.syncState.rawValue
        )
    }
}
