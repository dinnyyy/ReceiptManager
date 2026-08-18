import SwiftUI
import UserNotifications

/// Spec 5.14: "Give users control over data, reminders and account state."
struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var viewModel: SettingsViewModel?
    @State private var isDeleteConfirmationPresented = false
    @State private var deleteConfirmationText = ""

    private let deletePhrase = "DELETE"

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    content(viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
        .task {
            if viewModel == nil {
                viewModel = SettingsViewModel(environment: environment)
            }
            await viewModel?.load()
        }
        .onChange(of: viewModel?.didSignOut) { _, didSignOut in
            if didSignOut == true { dismiss() }
        }
        .onChange(of: viewModel?.didDeleteAccount) { _, didDelete in
            if didDelete == true { dismiss() }
        }
    }

    @ViewBuilder
    private func content(_ viewModel: SettingsViewModel) -> some View {
        Form {
            Section("Account") {
                if let email = viewModel.email {
                    LabeledContent("Email", value: email)
                }
                LabeledContent("Saved purchases", value: "\(viewModel.savedPurchaseCount)")
                LabeledContent("Items", value: "\(viewModel.itemCount)")
            }

            Section("Notifications") {
                LabeledContent("Warranty reminders", value: notificationStatusText(viewModel.notificationStatus))
                if viewModel.notificationStatus == .denied {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                }
            }

            Section {
                Button {
                    viewModel.exportAllData()
                } label: {
                    Label("Export all my data", systemImage: "square.and.arrow.up")
                }
            } footer: {
                Text("Works even without a subscription. Produces CSV files for your purchases and items.")
            }

            Section("Legal & support") {
                Link("Privacy Policy", destination: LegalLinks.privacyPolicy)
                Link("Terms", destination: LegalLinks.terms)
                Link("Support", destination: LegalLinks.terms)
            }

            Section {
                Button("Sign out") {
                    Task { await viewModel.signOut() }
                }
            }

            Section {
                Button(role: .destructive) {
                    deleteConfirmationText = ""
                    isDeleteConfirmationPresented = true
                } label: {
                    Label("Delete account", systemImage: "trash")
                }
                if let deleteErrorMessage = viewModel.deleteErrorMessage {
                    Text(deleteErrorMessage).font(.footnote).foregroundStyle(.red)
                }
            } footer: {
                Text("Permanently deletes your account and all purchase, item and warranty data. This can't be undone.")
            }
        }
        .sheet(isPresented: $isDeleteConfirmationPresented) {
            NavigationStack {
                Form {
                    Section {
                        Text("This permanently deletes your account and every purchase, item, attachment and warranty record. This cannot be undone.")
                            .font(.subheadline)
                    }
                    Section("Type \(deletePhrase) to confirm") {
                        TextField(deletePhrase, text: $deleteConfirmationText)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                    }
                    Section {
                        Button("Permanently delete my account", role: .destructive) {
                            Task {
                                await viewModel.deleteAccount()
                                isDeleteConfirmationPresented = false
                            }
                        }
                        .disabled(deleteConfirmationText != deletePhrase || viewModel.isDeletingAccount)
                    }
                }
                .navigationTitle("Delete account")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { isDeleteConfirmationPresented = false }
                    }
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { !viewModel.exportAllFileURLs.isEmpty },
            set: { if !$0 { viewModel.exportAllFileURLs = [] } }
        )) {
            NavigationStack {
                VStack(spacing: 16) {
                    Text("Your export is ready.")
                    ShareLink(items: viewModel.exportAllFileURLs) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .navigationTitle("Export")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium])
        }
    }

    private func notificationStatusText(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized, .provisional, .ephemeral: return "On"
        case .denied: return "Off"
        case .notDetermined: return "Not set"
        @unknown default: return "Unknown"
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppEnvironment.preview())
}
