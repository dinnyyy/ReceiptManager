import Foundation
import SwiftData
import ReceiptVaultCore

@MainActor
final class SwiftDataAttachmentRepository: AttachmentRepository {
    private let modelContext: ModelContext
    private let outbox: OutboxQueue

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.outbox = OutboxQueue(modelContext: modelContext)
    }

    func save(_ attachment: Attachment, localFilePath: String?) throws {
        let entity = AttachmentEntity(domain: attachment, localFilePath: localFilePath)

        if let purchaseID = attachment.purchaseID {
            let descriptor = FetchDescriptor<PurchaseEntity>(predicate: #Predicate { $0.id == purchaseID })
            entity.purchase = try modelContext.fetch(descriptor).first
        }
        if let itemID = attachment.itemID {
            let descriptor = FetchDescriptor<ItemEntity>(predicate: #Predicate { $0.id == itemID })
            entity.item = try modelContext.fetch(descriptor).first
        }

        modelContext.insert(entity)
        try modelContext.save()
        outbox.enqueue(kind: .uploadAttachment, entityID: attachment.id, entityType: .attachment)
    }

    func delete(id: UUID) throws {
        let descriptor = FetchDescriptor<AttachmentEntity>(predicate: #Predicate { $0.id == id })
        guard let entity = try modelContext.fetch(descriptor).first else { return }
        let wasSynced = entity.syncState == .synced || entity.syncState == .syncing
        let storagePath = entity.storagePath
        modelContext.delete(entity)
        try modelContext.save()
        if wasSynced {
            outbox.enqueue(kind: .deleteAttachment, entityID: id, entityType: .attachment)
        }
        _ = storagePath // storage cleanup happens in SyncEngine.deleteAttachment via the outbox
    }

    func attachments(purchaseID: UUID) throws -> [Attachment] {
        let descriptor = FetchDescriptor<PurchaseEntity>(predicate: #Predicate { $0.id == purchaseID })
        return try modelContext.fetch(descriptor).first?.attachments.map { $0.toDomain() } ?? []
    }
}
