import Foundation

/// The central record (spec section 21). One purchase can carry multiple
/// purposes and link to multiple items without duplicating the underlying
/// evidence - see CLAUDE.md section 1 for why this is the whole product
/// thesis, not an implementation detail.
public struct Purchase: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let workspaceID: UUID
    public var status: PurchaseStatus
    public var merchantName: String?
    public var purchaseDate: DateOnly?
    public var totalAmount: Decimal?
    public var gstAmount: Decimal?
    public var currency: String
    public var receiptNumber: String?
    public var category: String?
    public var folderID: UUID?
    public var purposes: Set<PurchasePurpose>
    public var tagIDs: Set<UUID>
    public var notes: String?
    public var rawOCRText: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var syncState: SyncState

    public init(
        id: UUID = UUID(),
        workspaceID: UUID,
        status: PurchaseStatus = .draft,
        merchantName: String? = nil,
        purchaseDate: DateOnly? = nil,
        totalAmount: Decimal? = nil,
        gstAmount: Decimal? = nil,
        currency: String = "AUD",
        receiptNumber: String? = nil,
        category: String? = nil,
        folderID: UUID? = nil,
        purposes: Set<PurchasePurpose> = [],
        tagIDs: Set<UUID> = [],
        notes: String? = nil,
        rawOCRText: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncState: SyncState = .localOnly
    ) {
        self.id = id
        self.workspaceID = workspaceID
        self.status = status
        self.merchantName = merchantName
        self.purchaseDate = purchaseDate
        self.totalAmount = totalAmount
        self.gstAmount = gstAmount
        self.currency = currency
        self.receiptNumber = receiptNumber
        self.category = category
        self.folderID = folderID
        self.purposes = purposes
        self.tagIDs = tagIDs
        self.notes = notes
        self.rawOCRText = rawOCRText
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncState = syncState
    }

    public var financialYear: AustralianFinancialYear? {
        purchaseDate.map(AustralianFinancialYear.init(containing:))
    }

    /// Spec 5.7 acceptance criteria: "No more than three required decisions
    /// after scanning for a normal high-confidence receipt." A purchase is
    /// save-ready once it has evidence to point back to; merchant/date/total
    /// may legitimately stay blank for an unreadable receipt (spec 7.2).
    public var hasMinimumDataToSave: Bool {
        merchantName != nil || purchaseDate != nil || totalAmount != nil || !purposes.isEmpty
    }
}
