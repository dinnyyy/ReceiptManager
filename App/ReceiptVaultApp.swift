import SwiftUI
import SwiftData

@main
struct ReceiptVaultApp: App {
    @State private var environment = AppEnvironment.live()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
        }
        .modelContainer(environment.modelContainer)
    }
}
