import Foundation
import StoreKit
import ReceiptVaultCore

/// Spec 5.13, 9.3, 11: StoreKit 2, Free + Solo Pro monthly/annual. Product
/// identifiers are App Store Connect configuration (never hard-coded UI
/// strings) - `productIDs` below are the *identifiers*, not prices; prices
/// always come from the `Product` StoreKit hands back.
///
/// NOTE for the first real Xcode build (see CLAUDE.md section 4): this API
/// shape matches StoreKit 2 as of this writing but is unverified by
/// compilation in this dev environment.
@MainActor
final class StoreKitSubscriptionService: SubscriptionService {
    private(set) var entitlement: EntitlementState = .free
    private var updatesTask: Task<Void, Never>?

    private let productIDs = ["solo_pro_monthly", "solo_pro_annual"]

    init() {
        updatesTask = Task { [weak self] in await self?.observeTransactionUpdates() }
        Task { [weak self] in await self?.refreshEntitlement() }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProducts() async throws -> [SubscriptionProduct] {
        let products = try await Product.products(for: productIDs)
        guard !products.isEmpty else { throw SubscriptionError.productsUnavailable }
        return products
            .sorted { $0.price < $1.price }
            .map { SubscriptionProduct(id: $0.id, plan: Self.plan(for: $0.id), displayName: $0.displayName, displayPrice: $0.displayPrice) }
    }

    func purchase(_ product: SubscriptionProduct) async throws {
        let storeProducts = try await Product.products(for: [product.id])
        guard let storeProduct = storeProducts.first else { throw SubscriptionError.productsUnavailable }

        let result = try await storeProduct.purchase()
        switch result {
        case .success(let verification):
            let transaction = try Self.checkVerified(verification)
            await transaction.finish()
            await refreshEntitlement()
        case .userCancelled:
            throw SubscriptionError.userCancelled
        case .pending:
            break // awaiting approval (e.g. Ask to Buy); entitlement updates via Transaction.updates
        @unknown default:
            break
        }
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
        await refreshEntitlement()
    }

    private func refreshEntitlement() async {
        var newest: Transaction?
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? Self.checkVerified(result) else { continue }
            if newest == nil || transaction.purchaseDate > newest!.purchaseDate {
                newest = transaction
            }
        }
        // Spec 11.1: an expired subscription never deletes data - a missing
        // entitlement here just means the free-tier gating rules apply
        // again, never that local records vanish.
        if let newest {
            entitlement = EntitlementState(plan: Self.plan(for: newest.productID), isActive: true, expiresAt: newest.expirationDate)
        } else {
            entitlement = .free
        }
    }

    private func observeTransactionUpdates() async {
        for await update in Transaction.updates {
            guard let transaction = try? Self.checkVerified(update) else { continue }
            await transaction.finish()
            await refreshEntitlement()
        }
    }

    private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw SubscriptionError.verificationFailed
        case .verified(let safe): return safe
        }
    }

    private static func plan(for productID: String) -> SubscriptionPlan {
        productID.contains("annual") ? .soloProAnnual : .soloProMonthly
    }
}
