import SwiftUI
import ReceiptVaultCore

/// Spec 9.4: "UI shows sync state: synced, syncing/pending, failed."
/// Deliberately quiet when synced (spec 5.8 acceptance: "record reflects
/// sync state if pending/failed" - synced is the assumed default, not
/// something to shout about) and always paired with text, never colour
/// alone (spec 16.1).
struct SyncStateBadge: View {
    let state: SyncState

    var body: some View {
        switch state {
        case .synced:
            EmptyView()
        case .localOnly, .pendingUpload:
            Label("Saved on iPhone", systemImage: "iphone")
                .labelStyle(.iconOnly)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Saved on this iPhone, not yet backed up")
        case .syncing:
            ProgressView()
                .controlSize(.mini)
                .accessibilityLabel("Backing up")
        case .failed:
            Label("Backup failed, tap to retry", systemImage: "exclamationmark.arrow.triangle.2.circlepath")
                .labelStyle(.iconOnly)
                .font(.caption)
                .foregroundStyle(.orange)
                .accessibilityLabel("Backup failed, tap to retry")
        }
    }
}
