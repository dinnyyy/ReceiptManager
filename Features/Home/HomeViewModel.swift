import Foundation
import Observation
import ReceiptVaultCore

/// Spec 5.3: "Make the next action obvious and surface only useful
/// attention items." Loads straight from the local SwiftData cache (spec
/// 5.3 acceptance: "Home loads from cache immediately then refreshes") -
/// there is no network call on the happy path at all, since this is a
/// local-first app; pull-to-refresh only exists to nudge a sync retry.
@MainActor
@Observable
final class HomeViewModel {
    private let environment: AppEnvironment

    var recentPurchases: [Purchase] = []
    var needsReviewCount = 0
    var itemsWithWarrantyEndingSoon: [Item] = []
    var isEmpty = false

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func load() {
        guard let workspaceID = environment.currentWorkspaceID else { return }
        recentPurchases = (try? environment.purchaseRepository.recentPurchases(workspaceID: workspaceID, limit: 10)) ?? []
        needsReviewCount = (try? environment.purchaseRepository.purchasesNeedingReview(workspaceID: workspaceID).count) ?? 0
        itemsWithWarrantyEndingSoon = (try? environment.itemRepository.itemsWithWarrantyExpiringSoon(workspaceID: workspaceID, withinDays: 30)) ?? []
        isEmpty = recentPurchases.isEmpty && needsReviewCount == 0
    }

    func refresh() async {
        environment.syncEngine?.drainOutbox()
        load()
    }
}
