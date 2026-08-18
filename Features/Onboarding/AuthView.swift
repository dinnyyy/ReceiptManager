import SwiftUI

/// Spec 5.2: Sign in with Apple as primary, email OTP as secondary, no
/// password anywhere. Kept as its own sheet (not folded into
/// OnboardingView) so "Restore Purchase"/legal links have a stable home
/// regardless of which onboarding card the user was last on.
struct AuthView: View {
    let onSignedIn: () -> Void

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    private enum Stage {
        case chooseMethod
        case emailEntry
        case codeEntry(email: String)
    }

    @State private var stage: Stage = .chooseMethod
    @State private var email = ""
    @State private var code = ""
    @State private var isBusy = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                switch stage {
                case .chooseMethod:
                    chooseMethodContent
                case .emailEntry:
                    emailEntryContent
                case .codeEntry(let email):
                    codeEntryContent(email: email)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()
                legalLinks
            }
            .padding(24)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var chooseMethodContent: some View {
        VStack(spacing: 16) {
            Text("Sign in to Receipt Vault")
                .font(.title2.bold())

            Button {
                Task { await signInWithApple() }
            } label: {
                Label("Sign in with Apple", systemImage: "apple.logo")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.black)
            .controlSize(.large)
            .disabled(isBusy)

            Button {
                stage = .emailEntry
            } label: {
                Text("Continue with email")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(isBusy)

            Button("Restore Purchases") {
                Task { try? await environment.subscriptionService.restorePurchases() }
            }
            .font(.footnote)
            .padding(.top, 8)
        }
    }

    private var emailEntryContent: some View {
        VStack(spacing: 16) {
            Text("Enter your email")
                .font(.title2.bold())
            TextField("you@example.com", text: $email)
                .textFieldStyle(.roundedBorder)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button {
                Task { await requestCode() }
            } label: {
                Text("Send code")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isBusy || !email.contains("@"))
        }
    }

    private func codeEntryContent(email: String) -> some View {
        VStack(spacing: 16) {
            Text("Enter the code we sent to \(email)")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            TextField("123456", text: $code)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.title2.monospacedDigit())

            Button {
                Task { await verifyCode(email: email) }
            } label: {
                Text("Verify")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isBusy || code.count < 4)
        }
    }

    private var legalLinks: some View {
        HStack(spacing: 16) {
            Link("Privacy Policy", destination: LegalLinks.privacyPolicy)
            Link("Terms", destination: LegalLinks.terms)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    private func signInWithApple() async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            _ = try await environment.authService.signInWithApple()
            environment.analyticsService.track(.accountCreated(authMethod: "apple", appVersion: AppVersion.current))
            await completeSignIn()
        } catch {
            errorMessage = "Sign in with Apple didn't complete. Please try again."
        }
    }

    private func requestCode() async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            try await environment.authService.requestEmailOTP(email: email)
            stage = .codeEntry(email: email)
        } catch {
            errorMessage = "Couldn't send a code to that address. Check it and try again."
        }
    }

    private func verifyCode(email: String) async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            _ = try await environment.authService.verifyEmailOTP(email: email, code: code)
            environment.analyticsService.track(.accountCreated(authMethod: "email_otp", appVersion: AppVersion.current))
            await completeSignIn()
        } catch {
            errorMessage = "That code didn't work. Check it and try again."
        }
    }

    private func completeSignIn() async {
        if let session = environment.authService.currentSession {
            await environment.bootstrapWorkspace(for: session)
        }
        dismiss()
        onSignedIn()
    }
}

enum LegalLinks {
    // Spec 5.14, 20: URLs are founder-controlled configuration, not
    // developer-invented legal text. Placeholder targets until real pages
    // are published.
    static let privacyPolicy = URL(string: "https://example.com/privacy")!
    static let terms = URL(string: "https://example.com/terms")!
}

enum AppVersion {
    static var current: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0"
    }
}

#Preview {
    AuthView(onSignedIn: {})
        .environment(AppEnvironment.preview())
}
