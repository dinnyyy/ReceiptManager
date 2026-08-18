import SwiftUI

/// Spec 4.1: three tabs (Home, Vault, Items) plus a persistent Scan entry
/// point and Settings, available from every tab rather than buried in one.
struct MainTabView: View {
    @Environment(AppRouter.self) private var router
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            Tab("Home", systemImage: "house.fill", value: AppTab.home) {
                NavigationStack(path: $router.homePath) {
                    HomeView()
                        .navigationDestination(for: AppRoute.self, destination: destination)
                }
            }
            Tab("Vault", systemImage: "archivebox.fill", value: AppTab.vault) {
                NavigationStack(path: $router.vaultPath) {
                    VaultView()
                        .navigationDestination(for: AppRoute.self, destination: destination)
                }
            }
            Tab("Items", systemImage: "shippingbox.fill", value: AppTab.items) {
                NavigationStack(path: $router.itemsPath) {
                    ItemsView()
                        .navigationDestination(for: AppRoute.self, destination: destination)
                }
            }
        }
        .sheet(isPresented: $router.isCaptureSheetPresented) {
            CaptureSourceSheet()
        }
        .sheet(isPresented: $router.isSettingsPresented) {
            SettingsView()
        }
        .sheet(item: $router.paywallTrigger) { trigger in
            PaywallView(trigger: trigger)
        }
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .purchaseDetail(let id):
            PurchaseDetailView(purchaseID: id)
        case .itemDetail(let id):
            ItemDetailView(itemID: id)
        case .itemEdit(let id, let prefillPurchaseID):
            ItemEditView(itemID: id, prefillFromPurchaseID: prefillPurchaseID)
        }
    }
}

extension PaywallTrigger: Identifiable {
    public var id: Self { self }
}

/// Shared toolbar affordance for the persistent Scan button (spec 4.1
/// "GLOBAL: Persistent + Scan button"). Applied by each tab's root screen
/// so it's always one tap away regardless of which tab is active.
struct ScanToolbarButton: ViewModifier {
    @Environment(AppRouter.self) private var router

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.presentCaptureSheet()
                } label: {
                    Label("Scan receipt", systemImage: "camera.viewfinder")
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    router.isSettingsPresented = true
                } label: {
                    Label("Settings", systemImage: "person.crop.circle")
                }
            }
        }
    }
}

extension View {
    func scanToolbar() -> some View {
        modifier(ScanToolbarButton())
    }
}
