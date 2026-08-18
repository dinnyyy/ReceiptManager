import XCTest
@testable import ReceiptVaultCore

final class SyncStateMachineTests: XCTestCase {
    func testValidForwardPath() throws {
        var state = SyncState.localOnly
        state = try SyncStateMachine.transition(from: state, to: .pendingUpload)
        state = try SyncStateMachine.transition(from: state, to: .syncing)
        state = try SyncStateMachine.transition(from: state, to: .synced)
        XCTAssertEqual(state, .synced)
    }

    func testFailureAndRetryPath() throws {
        var state = SyncState.syncing
        state = try SyncStateMachine.transition(from: state, to: .failed)
        state = try SyncStateMachine.transition(from: state, to: .pendingUpload)
        state = try SyncStateMachine.transition(from: state, to: .syncing)
        XCTAssertEqual(state, .syncing)
    }

    func testEditingASyncedRecordReentersOutbox() throws {
        let state = try SyncStateMachine.transition(from: .synced, to: .pendingUpload)
        XCTAssertEqual(state, .pendingUpload)
    }

    func testInvalidTransitionsThrow() {
        // Can't jump straight from localOnly to synced, skipping the outbox.
        XCTAssertThrowsError(try SyncStateMachine.transition(from: .localOnly, to: .synced)) { error in
            XCTAssertEqual(error as? InvalidSyncTransition, InvalidSyncTransition(from: .localOnly, to: .synced))
        }
        // Can't go "backwards" from pendingUpload to localOnly.
        XCTAssertThrowsError(try SyncStateMachine.transition(from: .pendingUpload, to: .localOnly))
        XCTAssertFalse(SyncStateMachine.canTransition(from: .localOnly, to: .synced))
    }
}
