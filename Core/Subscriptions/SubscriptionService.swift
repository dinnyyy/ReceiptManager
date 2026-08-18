import Foundation
import ReceiptVaultCore

public struct EntitlementState: Equatable, Sendable {
    public let plan: SubscriptionPlan
    public let isActive: Bool
    public let expiresAt: Date?

    public init(plan: SubscriptionPlan, isActive: Bool, expiresAt: Date?) {
        self.plan = plan
        self.isActive = isActive
        self.expiresAt = expiresAt
    }

    public static let free = EntitlementState(plan: .free, isActive: true, expiresAt: nil)
}

public struct SubscriptionProduct: Identifiable, Sendable {
    public let id: String
    public let plan: SubscriptionPlan
    public let displayName: String
    public let displayPrice: String

    public init(id: String, plan: SubscriptionPlan, displayName: String, displayPrice: String) {
        self.id = id
        self.plan = plan
        self.displayName = displayName
        self.displayPrice = displayPrice
    }
}

public enum SubscriptionError: Error {
    case productsUnavailable
    case purchaseFailed(String)
    case userCancelled
    case verificationFailed
}

/// StoreKit 2 wrapper (spec 5.13, 9.3, 11). Product identifiers are App
/// Store Connect configuration, never hard-coded UI strings (spec 11) - the
/// concrete implementation reads them from `Core/Subscriptions/Products.plist`
/// or build settings, not from this protocol.
@MainActor
public protocol SubscriptionService: AnyObject {
    var entitlement: EntitlementState { get }
    func loadProducts() async throws -> [SubscriptionProduct]
    func purchase(_ product: SubscriptionProduct) async throws
    func restorePurchases() async throws
}
