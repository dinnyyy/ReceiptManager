import SwiftUI

/// Spec 4.1: three tabs (Home, Vault, Items) plus a persistent Scan entry
/// point and Settings, available from every tab rather than buried in one.
struct MainTabView: View {
    @Environment(AppRouter.self) private var router
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        @Bindable var router = router
        // Classic tag-based TabView, not the iOS 18-only `Tab(value:)`
        // builder API, so this stays compatible with the iOS 17.0
        // deployment target set in project.yml (SwiftData is the actual
        // floor; see CLAUDE.md section 20 on the minimum-version decision).
        TabView(selection: $router.selectedTab) {
            NavigationStack(path: $router.homePath) {
                HomeView()
                    .navigationDestination(for: AppRoute.self, destination: destination)
            }
            .tabItem { Label("Home", systemImage: "house.fill") }
            .tag(AppTab.home)

            NavigationStack(path: $router.vaultPath) {
                VaultView()
                    .navigationDestination(for: AppRoute.self, destination: destination)
            }
            .tabItem { Label("Vault", systemImage: "archivebox.fill") }
            .tag(AppTab.vault)

            NavigationStack(path: $router.itemsPath) {
                ItemsView()
                    .navigationDestination(for: AppRoute.self, destination: destination)
            }
            .tabItem { Label("Items", systemImage: "shippingbox.fill") }
            .tag(AppTab.items)
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
            ItemEditView(itemID: id, prefillFromPurchaseID: prefillPurchaseID, onSaved: {})
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
