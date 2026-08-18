import Foundation
import SwiftData
import Network
import Supabase
import ReceiptVaultCore

/// Drains the outbox in the background, retrying with exponential backoff
/// and resuming automatically on network recovery or app foreground (spec
/// 9.4). A record's own `syncState` (visible in the UI) is updated as each
/// operation starts/succeeds/fails; failure never removes the local
/// record - only the outbox entry for that attempt is retried later.
@MainActor
final class SyncEngine {
    private let modelContext: ModelContext
    private let outbox: OutboxQueue
    private let backend: SupabaseBackend
    private let attachmentService: AttachmentService
    private let pathMonitor = NWPathMonitor()

    private var isNetworkAvailable = true
    private var isDraining = false

    init(modelContext: ModelContext, backend: SupabaseBackend, attachmentService: AttachmentService) {
        self.modelContext = modelContext
        self.outbox = OutboxQueue(modelContext: modelContext)
        self.backend = backend
        self.attachmentService = attachmentService

        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                let wasUnavailable = !self.isNetworkAvailable
                self.isNetworkAvailable = path.status == .satisfied
                if wasUnavailable, self.isNetworkAvailable {
                    self.drainOutbox()
                }
            }
        }
        pathMonitor.start(queue: DispatchQueue.global(qos: .utility))
    }

    func drainOutbox() {
        guard !isDraining, isNetworkAvailable else { return }
        isDraining = true
        Task { [weak self] in
            await self?.processQueue()
            self?.isDraining = false
        }
    }

    private func processQueue() async {
        guard let operations = try? outbox.pendingOperations() else { return }
        for operation in operations {
            guard isNetworkAvailable else { return }
            setEntitySyncState(operation, to: .syncing)
            do {
                try await process(operation)
                outbox.remove(operation)
                setEntitySyncState(operation, to: .synced)
            } catch {
                outbox.recordFailure(operation, error: String(describing: error))
                setEntitySyncState(operation, to: .failed)
                await backoff(retryCount: operation.retryCount)
            }
        }
    }

    /// Exponential backoff capped at 5 minutes, so a burst of failures
    /// (e.g. the network just dropped mid-drain) doesn't hammer the API.
    private func backoff(retryCount: Int) async {
        let seconds = min(pow(2.0, Double(retryCount)), 300)
        try? await Task.sleep(for: .seconds(seconds))
    }

    private func process(_ operation: OutboxOperationEntity) async throws {
        switch operation.kind {
        case .upsertPurchase: try await upsertPurchase(operation.entityID)
        case .upsertItem: try await upsertItem(operation.entityID)
        case .uploadAttachment: try await uploadAttachment(operation.entityID)
        case .deletePurchase: try await deletePurchase(operation.entityID)
        case .deleteItem: try await deleteItem(operation.entityID)
        case .deleteAttachment: try await deleteAttachment(operation.entityID)
        }
    }

    // MARK: - Purchases

    private struct PurchaseUpsertRow: Encodable {
        let id: UUID
        let workspace_id: UUID
        let status: String
        let merchant_name: String?
        let purchase_date: String?
        let total_amount: Decimal?
        let gst_amount: Decimal?
        let currency: String
        let receipt_number: String?
        let category: String?
        let folder_id: UUID?
        let notes: String?
        let raw_ocr_text: String?
        let ocr_engine: String?
    }

    private func upsertPurchase(_ id: UUID) async throws {
        guard let entity = try fetchPurchaseEntity(id) else { return }
        let row = PurchaseUpsertRow(
            id: entity.id, workspace_id: entity.workspaceID, status: entity.statusRaw,
            merchant_name: entity.merchantName, purchase_date: entity.purchaseDateISO,
            total_amount: entity.totalAmount, gst_amount: entity.gstAmount, currency: entity.currency,
            receipt_number: entity.receiptNumber, category: entity.category, folder_id: entity.folderID,
            notes: entity.notes, raw_ocr_text: entity.rawOCRText, ocr_engine: entity.ocrEngine
        )
        try await backend.client.from("purchases").upsert(row).execute()
        try await backend.client.from("purchase_purposes").delete().eq("purchase_id", value: entity.id).execute()
        if !entity.purposesRaw.isEmpty {
            let rows = entity.purposesRaw.map { ["purchase_id": entity.id.uuidString, "purpose": $0] }
            try await backend.client.from("purchase_purposes").insert(rows).execute()
        }

        // Any attachments staged locally but not yet uploaded ride along
        // with the purchase upsert rather than waiting for their own turn
        // in the queue, so Purchase Detail shows evidence as "synced" as
        // soon as the purchase itself is.
        for attachment in entity.attachments where attachment.syncState != .synced {
            outbox.enqueue(kind: .uploadAttachment, entityID: attachment.id, entityType: .attachment)
        }
    }

    private func deletePurchase(_ id: UUID) async throws {
        try await backend.client.from("purchases").delete().eq("id", value: id).execute()
    }

    // MARK: - Items

    private struct ItemUpsertRow: Encodable {
        let id: UUID
        let workspace_id: UUID
        let name: String
        let brand: String?
        let model: String?
        let serial_number: String?
        let original_value: Decimal?
        let location: String?
        let notes: String?
    }

    private func upsertItem(_ id: UUID) async throws {
        guard let entity = try fetchItemEntity(id) else { return }
        let row = ItemUpsertRow(
            id: entity.id, workspace_id: entity.workspaceID, name: entity.name, brand: entity.brand,
            model: entity.model, serial_number: entity.serialNumber, original_value: entity.originalValue,
            location: entity.location, notes: entity.notes
        )
        try await backend.client.from("items").upsert(row).execute()

        try await backend.client.from("purchase_items").delete().eq("item_id", value: entity.id).execute()
        if !entity.purchases.isEmpty {
            let rows = entity.purchases.map { ["purchase_id": $0.id.uuidString, "item_id": entity.id.uuidString] }
            try await backend.client.from("purchase_items").insert(rows).execute()
        }

        if let warranty = entity.warranty {
            try await upsertWarranty(warranty, itemID: entity.id, workspaceID: entity.workspaceID)
        }
    }

    private struct WarrantyUpsertRow: Encodable {
        let id: UUID
        let workspace_id: UUID
        let item_id: UUID
        let provider: String?
        let start_date: String?
        let expiry_date: String?
        let details: String?
        let reminder_enabled: Bool
    }

    private func upsertWarranty(_ warranty: WarrantyEntity, itemID: UUID, workspaceID: UUID) async throws {
        let row = WarrantyUpsertRow(
            id: warranty.id, workspace_id: workspaceID, item_id: itemID, provider: warranty.provider,
            start_date: warranty.startDateISO, expiry_date: warranty.expiryDateISO,
            details: warranty.details, reminder_enabled: warranty.reminderEnabled
        )
        try await backend.client.from("warranties").upsert(row).execute()
    }

    private func deleteItem(_ id: UUID) async throws {
        try await backend.client.from("items").delete().eq("id", value: id).execute()
    }

    // MARK: - Attachments

    private func uploadAttachment(_ id: UUID) async throws {
        let descriptor = FetchDescriptor<AttachmentEntity>(predicate: #Predicate { $0.id == id })
        guard let entity = try modelContext.fetch(descriptor).first, let localPath = entity.localFilePath else { return }

        let data = try Data(contentsOf: URL(fileURLWithPath: localPath))
        try await backend.uploadFile(data: data, storagePath: entity.storagePath, mimeType: entity.mimeType)

        struct AttachmentUpsertRow: Encodable {
            let id: UUID
            let workspace_id: UUID
            let purchase_id: UUID?
            let item_id: UUID?
            let type: String
            let storage_path: String
            let original_filename: String?
            let mime_type: String
            let bytes: Int?
            let sha256: String?
        }
        let row = AttachmentUpsertRow(
            id: entity.id, workspace_id: entity.workspaceID, purchase_id: entity.purchase?.id,
            item_id: entity.item?.id, type: entity.typeRaw, storage_path: entity.storagePath,
            original_filename: entity.originalFilename, mime_type: entity.mimeType,
            bytes: entity.bytes, sha256: entity.sha256
        )
        try await backend.client.from("attachments").upsert(row).execute()
        entity.syncState = .synced
        try? modelContext.save()
    }

    private func deleteAttachment(_ id: UUID) async throws {
        try await backend.client.from("attachments").delete().eq("id", value: id).execute()
    }

    // MARK: - Helpers

    private func fetchPurchaseEntity(_ id: UUID) throws -> PurchaseEntity? {
        try modelContext.fetch(FetchDescriptor<PurchaseEntity>(predicate: #Predicate { $0.id == id })).first
    }

    private func fetchItemEntity(_ id: UUID) throws -> ItemEntity? {
        try modelContext.fetch(FetchDescriptor<ItemEntity>(predicate: #Predicate { $0.id == id })).first
    }

    private func setEntitySyncState(_ operation: OutboxOperationEntity, to state: SyncState) {
        switch operation.entityType {
        case .purchase:
            if let entity = try? fetchPurchaseEntity(operation.entityID) {
                entity.syncState = state
                try? modelContext.save()
            }
        case .item:
            if let entity = try? fetchItemEntity(operation.entityID) {
                entity.syncState = state
                try? modelContext.save()
            }
        case .attachment:
            let descriptor = FetchDescriptor<AttachmentEntity>(predicate: #Predicate { $0.id == operation.entityID })
            if let entity = try? modelContext.fetch(descriptor).first {
                entity.syncState = state
                try? modelContext.save()
            }
        }
    }
}
