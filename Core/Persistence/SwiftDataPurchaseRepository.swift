import Foundation
import SwiftData
import ReceiptVaultCore

/// Local-first: every method reads/writes SwiftData directly and returns
/// immediately (spec 9.4). Search runs entirely against the local cache -
/// for a personal vault (spec 17.3: "100+ record seeded vault" is the
/// stated test scale) that comfortably meets the "within about one second"
/// acceptance criterion (spec 5.10) without a network round trip.
@MainActor
final class SwiftDataPurchaseRepository: PurchaseRepository {
    private let modelContext: ModelContext
    private let outbox: OutboxQueue

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.outbox = OutboxQueue(modelContext: modelContext)
    }

    func saveDraft(_ purchase: Purchase) throws {
        let descriptor = FetchDescriptor<PurchaseEntity>(predicate: #Predicate { $0.id == purchase.id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.update(from: purchase)
        } else {
            modelContext.insert(PurchaseEntity(domain: purchase))
        }
        try modelContext.save()
        outbox.enqueue(kind: .upsertPurchase, entityID: purchase.id, entityType: .purchase)
    }

    func fetch(id: UUID) throws -> Purchase? {
        let descriptor = FetchDescriptor<PurchaseEntity>(predicate: #Predicate { $0.id == id })
        return try modelContext.fetch(descriptor).first?.toDomain()
    }

    func search(_ query: PurchaseSearchQuery, workspaceID: UUID) throws -> [Purchase] {
        let descriptor = FetchDescriptor<PurchaseEntity>(
            predicate: #Predicate { $0.workspaceID == workspaceID }
        )
        var results = try modelContext.fetch(descriptor)

        if let status = query.status {
            results = results.filter { $0.status == status }
        } else {
            // Default vault view excludes drafts that never made it past
            // Review (spec 5.10 implicitly lists saved/needs_review records).
            results = results.filter { $0.status != .draft }
        }
        if let purposes = query.purposes, !purposes.isEmpty {
            results = results.filter { !$0.purposes.isDisjoint(with: purposes) }
        }
        if let dateFrom = query.dateFrom {
            results = results.filter { ($0.purchaseDate ?? dateFrom) >= dateFrom }
        }
        if let dateTo = query.dateTo {
            results = results.filter { ($0.purchaseDate ?? dateTo) <= dateTo }
        }
        if let folderID = query.folderID {
            results = results.filter { $0.folderID == folderID }
        }
        if let tagID = query.tagID {
            results = results.filter { $0.tagIDs.contains(tagID) }
        }
        if let minAmount = query.minAmount {
            results = results.filter { ($0.totalAmount ?? minAmount) >= minAmount }
        }
        if let maxAmount = query.maxAmount {
            results = results.filter { ($0.totalAmount ?? maxAmount) <= maxAmount }
        }
        if let text = query.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            let needle = text.lowercased()
            results = results.filter { entity in
                [entity.merchantName, entity.receiptNumber, entity.notes, entity.rawOCRText]
                    .compactMap { $0?.lowercased() }
                    .contains { $0.contains(needle) }
            }
        }

        return sort(results, by: query.sort).map { $0.toDomain() }
    }

    func delete(id: UUID) throws {
        let descriptor = FetchDescriptor<PurchaseEntity>(predicate: #Predicate { $0.id == id })
        guard let entity = try modelContext.fetch(descriptor).first else { return }
        let wasSynced = entity.syncState == .synced || entity.syncState == .syncing
        modelContext.delete(entity)
        try modelContext.save()
        if wasSynced {
            // Spec 9.4: "Deleting a synced record queues server/storage
            // cleanup if offline" - always queue it; the sync engine drops
            // no-op deletes for records that never made it to the server.
            outbox.enqueue(kind: .deletePurchase, entityID: id, entityType: .purchase)
        }
    }

    func recentPurchases(workspaceID: UUID, limit: Int) throws -> [Purchase] {
        try search(PurchaseSearchQuery(sort: .newest), workspaceID: workspaceID).prefix(limit).map { $0 }
    }

    func purchasesNeedingReview(workspaceID: UUID) throws -> [Purchase] {
        try search(PurchaseSearchQuery(status: .needsReview), workspaceID: workspaceID)
    }

    func count(workspaceID: UUID, status: PurchaseStatus?) throws -> Int {
        try search(PurchaseSearchQuery(status: status), workspaceID: workspaceID).count
    }

    private func sort(_ entities: [PurchaseEntity], by sort: PurchaseSort) -> [PurchaseEntity] {
        switch sort {
        case .newest:
            return entities.sorted { ($0.purchaseDate?.isoString ?? "", $0.createdAt) > ($1.purchaseDate?.isoString ?? "", $1.createdAt) }
        case .oldest:
            return entities.sorted { ($0.purchaseDate?.isoString ?? "", $0.createdAt) < ($1.purchaseDate?.isoString ?? "", $1.createdAt) }
        case .amountHighToLow:
            return entities.sorted { ($0.totalAmount ?? 0) > ($1.totalAmount ?? 0) }
        case .amountLowToHigh:
            return entities.sorted { ($0.totalAmount ?? 0) < ($1.totalAmount ?? 0) }
        case .merchantAZ:
            return entities.sorted { ($0.merchantName ?? "").localizedCaseInsensitiveCompare($1.merchantName ?? "") == .orderedAscending }
        }
    }
}
