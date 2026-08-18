import SwiftData
import Foundation
import ReceiptVaultCore

/// SwiftData's local cache/outbox copy of a Purchase (spec 9.1, 9.4).
/// Dates are stored as ISO "yyyy-MM-dd" strings, not `Date`, because
/// `DateOnly` (ReceiptVaultCore) is explicitly date-only - round-tripping
/// through `Date`/`Calendar` here would reintroduce the timezone bugs that
/// type exists to prevent.
@Model
final class PurchaseEntity {
    @Attribute(.unique) var id: UUID
    var workspaceID: UUID
    var statusRaw: String
    var merchantName: String?
    var purchaseDateISO: String?
    var totalAmount: Decimal?
    var gstAmount: Decimal?
    var currency: String
    var receiptNumber: String?
    var category: String?
    var folderID: UUID?
    var purposesRaw: [String]
    var tagIDs: [UUID]
    var notes: String?
    var rawOCRText: String?
    var ocrEngine: String?
    var createdAt: Date
    var updatedAt: Date
    var syncStateRaw: String
    var lastSyncError: String?

    @Relationship(deleteRule: .cascade, inverse: \AttachmentEntity.purchase)
    var attachments: [AttachmentEntity] = []

    @Relationship(deleteRule: .nullify, inverse: \ItemEntity.purchases)
    var items: [ItemEntity] = []

    init(
        id: UUID = UUID(),
        workspaceID: UUID,
        statusRaw: String = PurchaseStatus.draft.rawValue,
        merchantName: String? = nil,
        purchaseDateISO: String? = nil,
        totalAmount: Decimal? = nil,
        gstAmount: Decimal? = nil,
        currency: String = "AUD",
        receiptNumber: String? = nil,
        category: String? = nil,
        folderID: UUID? = nil,
        purposesRaw: [String] = [],
        tagIDs: [UUID] = [],
        notes: String? = nil,
        rawOCRText: String? = nil,
        ocrEngine: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncStateRaw: String = SyncState.localOnly.rawValue
    ) {
        self.id = id
        self.workspaceID = workspaceID
        self.statusRaw = statusRaw
        self.merchantName = merchantName
        self.purchaseDateISO = purchaseDateISO
        self.totalAmount = totalAmount
        self.gstAmount = gstAmount
        self.currency = currency
        self.receiptNumber = receiptNumber
        self.category = category
        self.folderID = folderID
        self.purposesRaw = purposesRaw
        self.tagIDs = tagIDs
        self.notes = notes
        self.rawOCRText = rawOCRText
        self.ocrEngine = ocrEngine
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStateRaw = syncStateRaw
    }
}

extension PurchaseEntity {
    var status: PurchaseStatus {
        get { PurchaseStatus(rawValue: statusRaw) ?? .draft }
        set { statusRaw = newValue.rawValue }
    }

    var purchaseDate: DateOnly? {
        get { purchaseDateISO.flatMap(DateOnly.init(isoString:)) }
        set { purchaseDateISO = newValue?.isoString }
    }

    var purposes: Set<PurchasePurpose> {
        get { Set(purposesRaw.compactMap(PurchasePurpose.init(rawValue:))) }
        set { purposesRaw = newValue.map(\.rawValue) }
    }

    var syncState: SyncState {
        get { SyncState(rawValue: syncStateRaw) ?? .localOnly }
        set { syncStateRaw = newValue.rawValue }
    }

    func toDomain() -> Purchase {
        Purchase(
            id: id, workspaceID: workspaceID, status: status, merchantName: merchantName,
            purchaseDate: purchaseDate, totalAmount: totalAmount, gstAmount: gstAmount,
            currency: currency, receiptNumber: receiptNumber, category: category, folderID: folderID,
            purposes: purposes, tagIDs: Set(tagIDs), notes: notes, rawOCRText: rawOCRText,
            createdAt: createdAt, updatedAt: updatedAt, syncState: syncState
        )
    }

    func update(from purchase: Purchase) {
        workspaceID = purchase.workspaceID
        status = purchase.status
        merchantName = purchase.merchantName
        purchaseDate = purchase.purchaseDate
        totalAmount = purchase.totalAmount
        gstAmount = purchase.gstAmount
        currency = purchase.currency
        receiptNumber = purchase.receiptNumber
        category = purchase.category
        folderID = purchase.folderID
        purposes = purchase.purposes
        tagIDs = Array(purchase.tagIDs)
        notes = purchase.notes
        rawOCRText = purchase.rawOCRText
        updatedAt = purchase.updatedAt
        syncState = purchase.syncState
    }

    convenience init(domain purchase: Purchase) {
        self.init(
            id: purchase.id, workspaceID: purchase.workspaceID, statusRaw: purchase.status.rawValue,
            merchantName: purchase.merchantName, purchaseDateISO: purchase.purchaseDate?.isoString,
            totalAmount: purchase.totalAmount, gstAmount: purchase.gstAmount, currency: purchase.currency,
            receiptNumber: purchase.receiptNumber, category: purchase.category, folderID: purchase.folderID,
            purposesRaw: purchase.purposes.map(\.rawValue), tagIDs: Array(purchase.tagIDs),
            notes: purchase.notes, rawOCRText: purchase.rawOCRText, createdAt: purchase.createdAt,
            updatedAt: purchase.updatedAt, syncStateRaw: purchase.syncState.rawValue
        )
    }
}
