import SwiftUI
import Foundation

/// Spec 4.1 navigation: three tabs (Home, Vault, Items), a persistent Scan
/// button, and a Settings entry point - "the app should feel like a vault,
/// not an accounting dashboard," so this deliberately stays this small.
enum AppTab: Hashable {
    case home, vault, items
}

enum PaywallTrigger: Hashable {
    case freeLimitReached
    case proOnlyExport
    case gatedItemFeature
}

/// Route destinations pushed onto a tab's own `NavigationPath`. Each tab
/// keeps independent history (spec 4.1: Home/Vault/Items are peers, not a
/// single shared stack), matching standard iOS tab-bar navigation.
enum AppRoute: Hashable {
    case purchaseDetail(UUID)
    case itemDetail(UUID)
    case itemEdit(UUID?, prefillFromPurchase: UUID?)
}

@Observable
@MainActor
final class AppRouter {
    var selectedTab: AppTab = .home
    var homePath = NavigationPath()
    var vaultPath = NavigationPath()
    var itemsPath = NavigationPath()

    var isCaptureSheetPresented = false
    var isSettingsPresented = false
    var paywallTrigger: PaywallTrigger?

    func navigate(to route: AppRoute, in tab: AppTab? = nil) {
        let target = tab ?? selectedTab
        selectedTab = target
        switch target {
        case .home: homePath.append(route)
        case .vault: vaultPath.append(route)
        case .items: itemsPath.append(route)
        }
    }

    func presentCaptureSheet() {
        isCaptureSheetPresented = true
    }

    func presentPaywall(_ trigger: PaywallTrigger) {
        paywallTrigger = trigger
    }
}
