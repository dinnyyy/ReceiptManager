import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

/// Bridges `ASAuthorizationController`'s delegate-based Sign in with Apple
/// flow to async/await, and generates the nonce Apple's flow requires for
/// replay protection (hashed nonce sent to Apple, raw nonce sent to
/// Supabase so it can verify the identity token matches).
@MainActor
final class AppleSignInCoordinator: NSObject {
    struct Result {
        let identityToken: String
        let rawNonce: String
    }

    enum CoordinatorError: Error {
        case missingIdentityToken
        case invalidCredentialType
    }

    private var continuation: CheckedContinuation<Result, Error>?
    private var currentRawNonce: String?

    func signIn() async throws -> Result {
        let rawNonce = Self.randomNonceString()
        currentRawNonce = rawNonce

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.email, .fullName]
        request.nonce = Self.sha256(rawNonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            controller.performRequests()
        }
    }

    private static func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        while remainingLength > 0 {
            var randomBytes = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
            precondition(status == errSecSuccess, "Unable to generate secure random nonce bytes")
            for byte in randomBytes where remainingLength > 0 {
                if byte < charset.count {
                    result.append(charset[Int(byte)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation?.resume(throwing: CoordinatorError.invalidCredentialType)
            continuation = nil
            return
        }
        guard let tokenData = credential.identityToken, let token = String(data: tokenData, encoding: .utf8) else {
            continuation?.resume(throwing: CoordinatorError.missingIdentityToken)
            continuation = nil
            return
        }
        continuation?.resume(returning: Result(identityToken: token, rawNonce: currentRawNonce ?? ""))
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first ?? ASPresentationAnchor()
    }
}
