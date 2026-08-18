import SwiftUI

/// Spec 5.1: "App wordmark/logo only if load exceeds an instant; otherwise
/// go directly to Home." Session restore is normally fast (local cache
/// check first), so this view is intentionally plain rather than an
/// animated splash the user waits through on every launch.
struct LaunchView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.doc.fill")
                .font(.system(size: 40))
                .foregroundStyle(.tint)
            Text("Receipt Vault")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .accessibilityHidden(true) // purely decorative; nothing to announce during a fast restore
    }
}

#Preview {
    LaunchView()
}
