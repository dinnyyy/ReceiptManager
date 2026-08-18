import Foundation
import ReceiptVaultCore

public struct PurchaseSearchQuery: Sendable {
    public var text: String?
    public var purposes: Set<PurchasePurpose>?
    public var dateFrom: DateOnly?
    public var dateTo: DateOnly?
    public var folderID: UUID?
    public var tagID: UUID?
    public var minAmount: Decimal?
    public var maxAmount: Decimal?
    public var status: PurchaseStatus?
    public var sort: PurchaseSort = .newest

    public init(
        text: String? = nil, purposes: Set<PurchasePurpose>? = nil, dateFrom: DateOnly? = nil,
        dateTo: DateOnly? = nil, folderID: UUID? = nil, tagID: UUID? = nil, minAmount: Decimal? = nil,
        maxAmount: Decimal? = nil, status: PurchaseStatus? = nil, sort: PurchaseSort = .newest
    ) {
        self.text = text
        self.purposes = purposes
        self.dateFrom = dateFrom
        self.dateTo = dateTo
        self.folderID = folderID
        self.tagID = tagID
        self.minAmount = minAmount
        self.maxAmount = maxAmount
        self.status = status
        self.sort = sort
    }
}

public enum PurchaseSort: Sendable, Equatable, Hashable {
    case newest, oldest, amountHighToLow, amountLowToHigh, merchantAZ
}

/// Local-first repository (spec 9.3, 9.4): every write lands in SwiftData
/// first and is immediately visible to the UI; syncing to Supabase happens
/// afterward via the outbox and never blocks a save.
@MainActor
public protocol PurchaseRepository {
    func saveDraft(_ purchase: Purchase) throws
    func fetch(id: UUID) throws -> Purchase?
    func search(_ query: PurchaseSearchQuery, workspaceID: UUID) throws -> [Purchase]
    func delete(id: UUID) throws
    func recentPurchases(workspaceID: UUID, limit: Int) throws -> [Purchase]
    func purchasesNeedingReview(workspaceID: UUID) throws -> [Purchase]
    func count(workspaceID: UUID, status: PurchaseStatus?) throws -> Int
}
