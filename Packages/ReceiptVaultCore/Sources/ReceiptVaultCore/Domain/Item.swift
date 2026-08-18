import Foundation

/// A real-world asset/product acquired in a purchase (spec 5.9, 21). Can
/// exist without a linked purchase, serial number, or warranty (spec 5.9
/// acceptance criteria) - the app must stay useful even with partial data.
public struct Item: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let workspaceID: UUID
    public var name: String
    public var brand: String?
    public var model: String?
    public var serialNumber: String?
    public var originalValue: Decimal?
    public var location: String?
    public var notes: String?
    public var purchaseIDs: Set<UUID>
    public var warranty: Warranty?
    public var createdAt: Date
    public var updatedAt: Date
    public var syncState: SyncState

    public init(
        id: UUID = UUID(),
        workspaceID: UUID,
        name: String,
        brand: String? = nil,
        model: String? = nil,
        serialNumber: String? = nil,
        originalValue: Decimal? = nil,
        location: String? = nil,
        notes: String? = nil,
        purchaseIDs: Set<UUID> = [],
        warranty: Warranty? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncState: SyncState = .localOnly
    ) {
        self.id = id
        self.workspaceID = workspaceID
        self.name = name
        self.brand = brand
        self.model = model
        self.serialNumber = serialNumber
        self.originalValue = originalValue
        self.location = location
        self.notes = notes
        self.purchaseIDs = purchaseIDs
        self.warranty = warranty
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncState = syncState
    }

    /// Spec 5.11: "Items without linked purchase remain valid but clearly
    /// show 'No purchase proof linked'."
    public var hasLinkedPurchaseProof: Bool { !purchaseIDs.isEmpty }
}
