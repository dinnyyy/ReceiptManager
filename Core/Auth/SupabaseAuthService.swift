import Foundation
import Supabase

@MainActor
final class SupabaseAuthService: AuthService {
    private let backend: SupabaseBackend
    private let appleCoordinator = AppleSignInCoordinator()
    private(set) var currentSession: AuthSession?

    init(backend: SupabaseBackend) {
        self.backend = backend
    }

    func restoreSession() async -> AuthSession? {
        guard let session = await backend.currentSession() else {
            currentSession = nil
            return nil
        }
        let mapped = Self.map(session)
        currentSession = mapped
        return mapped
    }

    func signInWithApple() async throws -> AuthSession {
        let result = try await appleCoordinator.signIn()
        let session = try await backend.signInWithApple(idToken: result.identityToken, nonce: result.rawNonce)
        let mapped = Self.map(session)
        currentSession = mapped
        return mapped
    }

    func requestEmailOTP(email: String) async throws {
        try await backend.requestEmailOTP(email: email)
    }

    func verifyEmailOTP(email: String, code: String) async throws -> AuthSession {
        let session = try await backend.verifyEmailOTP(email: email, code: code)
        let mapped = Self.map(session)
        currentSession = mapped
        return mapped
    }

    func signOut() async {
        try? await backend.signOut()
        currentSession = nil
    }

    private static func map(_ session: Session) -> AuthSession {
        AuthSession(userID: session.user.id, email: session.user.email)
    }
}
