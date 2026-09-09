import Foundation
import Supabase

/// Thin wrapper around the Supabase Swift SDK client. Every other service
/// (`SupabaseAuthService`, `SupabaseAttachmentService`, the sync engine)
/// depends on this narrow surface instead of importing `Supabase` directly,
/// so an SDK version bump only needs review in one file.
///
/// NOTE for whoever does the first real Xcode build (see CLAUDE.md section
/// 4: this dev environment has no Swift toolchain, so these calls are
/// unverified by compilation): the method names below match the
/// supabase-swift 2.x API as of this writing. Xcode's autocomplete/compiler
/// will immediately flag anything that's drifted since - fix signatures
/// here first, the rest of the app never touches the SDK directly.
final class SupabaseBackend: Sendable {
    static let shared = SupabaseBackend()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(supabaseURL: SupabaseConfig.url, supabaseKey: SupabaseConfig.anonKey)
    }

    // MARK: - Auth

    func currentSession() async -> Session? {
        try? await client.auth.session
    }

    func signInWithApple(idToken: String, nonce: String?) async throws -> Session {
        try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: nonce)
        )
    }

    func requestEmailOTP(email: String) async throws {
        try await client.auth.signInWithOTP(email: email)
    }

    struct MissingSessionAfterOTPVerification: Error {}

    func verifyEmailOTP(email: String, code: String) async throws -> Session {
        let response = try await client.auth.verifyOTP(email: email, token: code, type: .email)
        switch response {
        case .session(let session):
            return session
        case .user:
            // Email OTP sign-in always yields a session on success; `.user`
            // is only the email-change confirmation-pending case, which
            // shouldn't occur for `type: .email`.
            throw MissingSessionAfterOTPVerification()
        }
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    /// Spec 5.14: permanent, in-app account deletion. Invokes the
    /// `delete-account` Edge Function (supabase/functions/delete-account),
    /// which is the only thing with service-role rights to cascade the
    /// deletion and then remove the auth.users row itself.
    func deleteAccount() async throws {
        struct EmptyResponse: Decodable {}
        _ = try await client.functions.invoke("delete-account") as EmptyResponse
    }

    // MARK: - RPCs (supabase/migrations/20260817000010_rpc_functions.sql)

    struct WorkspaceRow: Decodable, Sendable {
        let id: UUID
        let name: String
        let type: String
        let ownerUserID: UUID
        let createdAt: Date

        enum CodingKeys: String, CodingKey {
            case id, name, type
            case ownerUserID = "owner_user_id"
            case createdAt = "created_at"
        }
    }

    func createInitialWorkspace() async throws -> WorkspaceRow {
        try await client
            .rpc("create_initial_workspace")
            .single()
            .execute()
            .value
    }

    // MARK: - Storage (private "proof-files" bucket, spec 10.1/10.2)

    func uploadFile(data: Data, storagePath: String, mimeType: String) async throws {
        try await client.storage.from("proof-files").upload(
            path: storagePath, file: data, options: FileOptions(contentType: mimeType, upsert: true)
        )
    }

    func createSignedURL(storagePath: String, expiresInSeconds: Int = 300) async throws -> URL {
        try await client.storage.from("proof-files").createSignedURL(path: storagePath, expiresIn: expiresInSeconds)
    }

    func deleteFile(storagePath: String) async throws {
        _ = try await client.storage.from("proof-files").remove(paths: [storagePath])
    }
}
