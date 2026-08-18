import Foundation
import ReceiptVaultCore

public enum ItemSort: Sendable, Equatable, Hashable {
    case nameAZ, warrantyEndingSoon, recentlyAdded
}

public struct ItemSearchQuery: Sendable {
    public var text: String?
    public var warrantyEndingSoonOnly: Bool = false
    public var location: String?
    public var sort: ItemSort = .recentlyAdded

    public init(text: String? = nil, warrantyEndingSoonOnly: Bool = false, location: String? = nil, sort: ItemSort = .recentlyAdded) {
        self.text = text
        self.warrantyEndingSoonOnly = warrantyEndingSoonOnly
        self.location = location
        self.sort = sort
    }
}

@MainActor
public protocol ItemRepository {
    func save(_ item: Item) throws
    func fetch(id: UUID) throws -> Item?
    func search(_ query: ItemSearchQuery, workspaceID: UUID) throws -> [Item]
    func delete(id: UUID) throws
    func linkPurchase(itemID: UUID, purchaseID: UUID, allocatedValue: Decimal?) throws
    func unlinkPurchase(itemID: UUID, purchaseID: UUID) throws
    func itemsWithWarrantyExpiringSoon(workspaceID: UUID, withinDays: Int) throws -> [Item]
}
