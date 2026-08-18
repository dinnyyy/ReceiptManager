import SwiftUI
import SwiftData

@main
struct ReceiptVaultApp: App {
    @State private var environment = AppEnvironment.live()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
        }
        .modelContainer(environment.modelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            // Spec 9.4: "Retries... resume on app foreground/network
            // availability." Network-recovery resumption lives in
            // SyncEngine's NWPathMonitor callback; this covers the other
            // trigger.
            if newPhase == .active {
                environment.syncEngine?.drainOutbox()
            }
        }
    }
}
