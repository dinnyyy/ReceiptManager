import Foundation

public struct AuthSession: Equatable, Sendable {
    public let userID: UUID
    public let email: String?

    public init(userID: UUID, email: String?) {
        self.userID = userID
        self.email = email
    }
}

public enum AuthError: Error, Equatable {
    case notSignedIn
    case cancelled
    case network(String)
    case sessionExpired
}

/// Sign in with Apple (primary) + Supabase email OTP (secondary), per spec
/// 5.2 and 9.3. Implemented by `SupabaseAuthService` (Core/Backend); a mock
/// implementation backs SwiftUI previews and unit tests.
@MainActor
public protocol AuthService: AnyObject {
    var currentSession: AuthSession? { get }

    /// Restores a cached session on launch without a network round trip
    /// where possible (spec 5.1 acceptance criteria: "No permanent
    /// blank/loading screen").
    func restoreSession() async -> AuthSession?

    func signInWithApple() async throws -> AuthSession
    func requestEmailOTP(email: String) async throws
    func verifyEmailOTP(email: String, code: String) async throws -> AuthSession
    func signOut() async
    func deleteAccount() async throws
}
