import Foundation

extension AppEnvironment {
    /// Idempotent (spec 5.2 acceptance criteria: "Workspace creation is
    /// idempotent") - calls the `create_initial_workspace` RPC, which
    /// returns the user's existing personal workspace if one already
    /// exists rather than creating a duplicate. Safe to call on every
    /// launch.
    func bootstrapWorkspace(for session: AuthSession) async {
        do {
            let workspace = try await SupabaseBackend.shared.createInitialWorkspace()
            currentWorkspaceID = workspace.id
        } catch {
            // Spec 5.1: "If sync fails, Home still opens with cached
            // records and a non-blocking status message." Fall back to a
            // previously-cached workspace id (if any) rather than blocking
            // sign-in entirely on a network failure.
            if currentWorkspaceID == nil {
                currentWorkspaceID = UserDefaults.standard.string(forKey: Self.cachedWorkspaceIDKey).flatMap(UUID.init(uuidString:))
            }
        }
        if let workspaceID = currentWorkspaceID {
            UserDefaults.standard.set(workspaceID.uuidString, forKey: Self.cachedWorkspaceIDKey)
        }
    }

    private static let cachedWorkspaceIDKey = "com.receiptvault.cachedWorkspaceID"
}
