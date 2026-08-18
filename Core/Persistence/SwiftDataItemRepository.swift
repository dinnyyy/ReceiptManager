import Foundation
import SwiftData
import ReceiptVaultCore

@MainActor
final class SwiftDataItemRepository: ItemRepository {
    private let modelContext: ModelContext
    private let outbox: OutboxQueue

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.outbox = OutboxQueue(modelContext: modelContext)
    }

    func save(_ item: Item) throws {
        let descriptor = FetchDescriptor<ItemEntity>(predicate: #Predicate { $0.id == item.id })
        let entity: ItemEntity
        if let existing = try modelContext.fetch(descriptor).first {
            existing.update(from: item)
            entity = existing
        } else {
            entity = ItemEntity(domain: item)
            modelContext.insert(entity)
        }

        if let warranty = item.warranty {
            if let existingWarranty = entity.warranty {
                existingWarranty.update(from: warranty)
            } else {
                entity.warranty = WarrantyEntity(domain: warranty)
            }
        } else {
            entity.warranty = nil
        }

        try relinkPurchases(entity: entity, purchaseIDs: item.purchaseIDs)
        try modelContext.save()
        outbox.enqueue(kind: .upsertItem, entityID: item.id, entityType: .item)
    }

    func fetch(id: UUID) throws -> Item? {
        let descriptor = FetchDescriptor<ItemEntity>(predicate: #Predicate { $0.id == id })
        return try modelContext.fetch(descriptor).first?.toDomain()
    }

    func search(_ query: ItemSearchQuery, workspaceID: UUID) throws -> [Item] {
        let descriptor = FetchDescriptor<ItemEntity>(predicate: #Predicate { $0.workspaceID == workspaceID })
        var results = try modelContext.fetch(descriptor)

        if let text = query.text?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !text.isEmpty {
            results = results.filter { entity in
                [entity.name, entity.brand, entity.model, entity.serialNumber, entity.location]
                    .compactMap { $0?.lowercased() }
                    .contains { $0.contains(text) }
            }
        }
        if let location = query.location {
            results = results.filter { $0.location == location }
        }
        if query.warrantyEndingSoonOnly {
            results = results.filter { $0.warranty?.toDomain().status() == .expiringSoon }
        }

        switch query.sort {
        case .nameAZ:
            results.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .recentlyAdded:
            results.sort { $0.createdAt > $1.createdAt }
        case .warrantyEndingSoon:
            results.sort { ($0.warranty?.expiryDate?.isoString ?? "9999") < ($1.warranty?.expiryDate?.isoString ?? "9999") }
        }

        return results.map { $0.toDomain() }
    }

    func delete(id: UUID) throws {
        let descriptor = FetchDescriptor<ItemEntity>(predicate: #Predicate { $0.id == id })
        guard let entity = try modelContext.fetch(descriptor).first else { return }
        let wasSynced = entity.syncState == .synced || entity.syncState == .syncing
        modelContext.delete(entity)
        try modelContext.save()
        if wasSynced {
            outbox.enqueue(kind: .deleteItem, entityID: id, entityType: .item)
        }
    }

    func linkPurchase(itemID: UUID, purchaseID: UUID, allocatedValue: Decimal?) throws {
        guard let item = try modelContext.fetch(FetchDescriptor<ItemEntity>(predicate: #Predicate { $0.id == itemID })).first,
              let purchase = try modelContext.fetch(FetchDescriptor<PurchaseEntity>(predicate: #Predicate { $0.id == purchaseID })).first
        else { return }
        if !item.purchases.contains(where: { $0.id == purchaseID }) {
            item.purchases.append(purchase)
        }
        try modelContext.save()
        outbox.enqueue(kind: .upsertItem, entityID: itemID, entityType: .item)
    }

    func unlinkPurchase(itemID: UUID, purchaseID: UUID) throws {
        guard let item = try modelContext.fetch(FetchDescriptor<ItemEntity>(predicate: #Predicate { $0.id == itemID })).first else { return }
        item.purchases.removeAll { $0.id == purchaseID }
        try modelContext.save()
        outbox.enqueue(kind: .upsertItem, entityID: itemID, entityType: .item)
    }

    func itemsWithWarrantyExpiringSoon(workspaceID: UUID, withinDays: Int) throws -> [Item] {
        let today = DateOnly.today()
        return try search(ItemSearchQuery(sort: .warrantyEndingSoon), workspaceID: workspaceID).filter { item in
            guard let expiry = item.warranty?.expiryDate else { return false }
            let days = today.days(until: expiry)
            return days >= 0 && days <= withinDays
        }
    }

    private func relinkPurchases(entity: ItemEntity, purchaseIDs: Set<UUID>) throws {
        let descriptor = FetchDescriptor<PurchaseEntity>(predicate: #Predicate { purchase in purchaseIDs.contains(purchase.id) })
        entity.purchases = try modelContext.fetch(descriptor)
    }
}
