import Foundation

/// Temporary dev-mode auth: always "signed in" as a fixed local user, no
/// network call ever made. Used by `AppEnvironment.localOnly()` so the app
/// can be built and run without a Supabase project configured.
///
/// This is not part of the shipped product - see the flag at the top of
/// `ReceiptVaultApp.swift` for how to switch back to real auth once
/// `Config/Secrets.xcconfig` is filled in.
@MainActor
final class LocalOnlyAuthService: AuthService {
    let currentSession: AuthSession? = AuthSession(
        userID: UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!,
        email: "local-dev@device"
    )

    func restoreSession() async -> AuthSession? { currentSession }
    func signInWithApple() async throws -> AuthSession { currentSession! }
    func requestEmailOTP(email: String) async throws {}
    func verifyEmailOTP(email: String, code: String) async throws -> AuthSession { currentSession! }
    func signOut() async {}
    func deleteAccount() async throws {}
}
