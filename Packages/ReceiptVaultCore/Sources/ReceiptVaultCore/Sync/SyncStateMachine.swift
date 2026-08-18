import Foundation

/// Error thrown when code tries to move a record through a sync transition
/// that isn't valid from its current state - a bug in the caller, not a
/// runtime condition to recover from.
public struct InvalidSyncTransition: Error, Equatable {
    public let from: SyncState
    public let to: SyncState
}

/// Validates transitions through the local-first sync pipeline (spec 9.4).
/// A record's sync state is always visible in the UI and failure never
/// makes it disappear, so the state machine only needs to guarantee the
/// *shape* of the pipeline is followed - it doesn't own retry timing or
/// network calls, which live in the app's sync engine.
public enum SyncStateMachine {
    private static let allowedTransitions: [SyncState: Set<SyncState>] = [
        .localOnly: [.pendingUpload],
        .pendingUpload: [.syncing],
        .syncing: [.synced, .failed],
        .failed: [.pendingUpload, .syncing],
        // A synced record can be edited locally again (re-enters the
        // outbox) or re-synced directly after a lightweight retry.
        .synced: [.pendingUpload, .syncing],
    ]

    public static func canTransition(from: SyncState, to: SyncState) -> Bool {
        allowedTransitions[from]?.contains(to) ?? false
    }

    @discardableResult
    public static func transition(from: SyncState, to: SyncState) throws -> SyncState {
        guard canTransition(from: from, to: to) else {
            throw InvalidSyncTransition(from: from, to: to)
        }
        return to
    }
}
