import SwiftUI

/// Spec 5.1 (Launch/session restore): restore a signed-in session quickly
/// and never block behind unnecessary splash animation. If sync fails,
/// Home still opens from cache with a non-blocking status message - that
/// behavior lives in `HomeView`/the sync engine, not here; this view's only
/// job is "do we have a session or not."
struct RootView: View {
    @Environment(AppEnvironment.self) private var environment

    enum LaunchState: Equatable {
        case restoring
        case signedOut
        case signedIn
    }

    @State private var launchState: LaunchState = .restoring
    @State private var router = AppRouter()

    var body: some View {
        Group {
            switch launchState {
            case .restoring:
                LaunchView()
            case .signedOut:
                OnboardingView(onSignedIn: { launchState = .signedIn })
            case .signedIn:
                MainTabView()
                    .environment(router)
            }
        }
        .task {
            await restoreSession()
        }
    }

    private func restoreSession() async {
        if let session = await environment.authService.restoreSession() {
            await environment.bootstrapWorkspace(for: session)
            launchState = .signedIn
        } else {
            launchState = .signedOut
        }
    }
}
