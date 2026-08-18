import Foundation
import SwiftData

/// Thin insert-only helper repositories call after a local write (spec
/// 9.4: "write... to SwiftData first, then enqueue upload/upsert work").
/// `SyncEngine` is the only thing that reads/drains this queue.
@MainActor
final class OutboxQueue {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func enqueue(kind: OutboxOperationKind, entityID: UUID, entityType: OutboxEntityType) {
        // Collapse redundant work: if this exact entity already has a
        // pending upsert queued, editing it again shouldn't pile up
        // duplicate outbox rows - the newest local state is what will be
        // read and pushed regardless of how many times it was queued.
        let kindRaw = kind.rawValue
        let descriptor = FetchDescriptor<OutboxOperationEntity>(
            predicate: #Predicate { $0.entityID == entityID && $0.kindRaw == kindRaw }
        )
        if let existing = try? modelContext.fetch(descriptor), !existing.isEmpty {
            return
        }
        modelContext.insert(OutboxOperationEntity(kind: kind, entityID: entityID, entityType: entityType))
        try? modelContext.save()
    }

    func pendingOperations() throws -> [OutboxOperationEntity] {
        var descriptor = FetchDescriptor<OutboxOperationEntity>()
        descriptor.sortBy = [SortDescriptor(\.createdAt, order: .forward)]
        return try modelContext.fetch(descriptor)
    }

    func remove(_ operation: OutboxOperationEntity) {
        modelContext.delete(operation)
        try? modelContext.save()
    }

    func recordFailure(_ operation: OutboxOperationEntity, error: String) {
        operation.retryCount += 1
        operation.lastAttemptAt = Date()
        operation.lastError = error
        try? modelContext.save()
    }
}
