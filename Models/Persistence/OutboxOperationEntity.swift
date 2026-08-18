import SwiftData
import Foundation

/// One pending unit of sync work (spec 9.4: "write the purchase and local
/// attachment references to SwiftData first, then enqueue upload/upsert
/// work"). The sync engine (Core/Sync) drains this queue in order, retrying
/// with backoff on failure; a record's own `syncStateRaw` is what the UI
/// reads, this table is purely the engine's work list.
@Model
final class OutboxOperationEntity {
    @Attribute(.unique) var id: UUID
    var kindRaw: String
    var entityID: UUID
    var entityTypeRaw: String
    var createdAt: Date
    var retryCount: Int
    var lastAttemptAt: Date?
    var lastError: String?

    init(
        id: UUID = UUID(),
        kindRaw: String,
        entityID: UUID,
        entityTypeRaw: String,
        createdAt: Date = Date(),
        retryCount: Int = 0,
        lastAttemptAt: Date? = nil,
        lastError: String? = nil
    ) {
        self.id = id
        self.kindRaw = kindRaw
        self.entityID = entityID
        self.entityTypeRaw = entityTypeRaw
        self.createdAt = createdAt
        self.retryCount = retryCount
        self.lastAttemptAt = lastAttemptAt
        self.lastError = lastError
    }
}

public enum OutboxOperationKind: String {
    case upsertPurchase
    case upsertItem
    case uploadAttachment
    case deletePurchase
    case deleteItem
    case deleteAttachment
}

public enum OutboxEntityType: String {
    case purchase
    case item
    case attachment
}

extension OutboxOperationEntity {
    var kind: OutboxOperationKind {
        get { OutboxOperationKind(rawValue: kindRaw) ?? .upsertPurchase }
        set { kindRaw = newValue.rawValue }
    }

    var entityType: OutboxEntityType {
        get { OutboxEntityType(rawValue: entityTypeRaw) ?? .purchase }
        set { entityTypeRaw = newValue.rawValue }
    }

    convenience init(kind: OutboxOperationKind, entityID: UUID, entityType: OutboxEntityType) {
        self.init(kindRaw: kind.rawValue, entityID: entityID, entityTypeRaw: entityType.rawValue)
    }
}
