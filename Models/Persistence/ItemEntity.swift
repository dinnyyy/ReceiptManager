import SwiftData
import Foundation
import ReceiptVaultCore

@Model
final class ItemEntity {
    @Attribute(.unique) var id: UUID
    var workspaceID: UUID
    var name: String
    var brand: String?
    var model: String?
    var serialNumber: String?
    var originalValue: Decimal?
    var location: String?
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
    var syncStateRaw: String

    var purchases: [PurchaseEntity] = []

    @Relationship(deleteRule: .cascade, inverse: \AttachmentEntity.item)
    var attachments: [AttachmentEntity] = []

    @Relationship(deleteRule: .cascade)
    var warranty: WarrantyEntity?

    init(
        id: UUID = UUID(),
        workspaceID: UUID,
        name: String,
        brand: String? = nil,
        model: String? = nil,
        serialNumber: String? = nil,
        originalValue: Decimal? = nil,
        location: String? = nil,
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncStateRaw: String = SyncState.localOnly.rawValue
    ) {
        self.id = id
        self.workspaceID = workspaceID
        self.name = name
        self.brand = brand
        self.model = model
        self.serialNumber = serialNumber
        self.originalValue = originalValue
        self.location = location
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStateRaw = syncStateRaw
    }
}

extension ItemEntity {
    var syncState: SyncState {
        get { SyncState(rawValue: syncStateRaw) ?? .localOnly }
        set { syncStateRaw = newValue.rawValue }
    }

    func toDomain() -> Item {
        Item(
            id: id, workspaceID: workspaceID, name: name, brand: brand, model: model,
            serialNumber: serialNumber, originalValue: originalValue, location: location, notes: notes,
            purchaseIDs: Set(purchases.map(\.id)), warranty: warranty?.toDomain(),
            createdAt: createdAt, updatedAt: updatedAt, syncState: syncState
        )
    }

    func update(from item: Item) {
        workspaceID = item.workspaceID
        name = item.name
        brand = item.brand
        model = item.model
        serialNumber = item.serialNumber
        originalValue = item.originalValue
        location = item.location
        notes = item.notes
        updatedAt = item.updatedAt
        syncState = item.syncState
    }

    convenience init(domain item: Item) {
        self.init(
            id: item.id, workspaceID: item.workspaceID, name: item.name, brand: item.brand,
            model: item.model, serialNumber: item.serialNumber, originalValue: item.originalValue,
            location: item.location, notes: item.notes, createdAt: item.createdAt,
            updatedAt: item.updatedAt, syncStateRaw: item.syncState.rawValue
        )
    }
}
