import SwiftUI
import ReceiptVaultCore

/// Spec 5.13, 22.1: benefits are framed around capacity/Proof
/// Packs/asset features, never "AI" as the pitch.
struct PaywallView: View {
    let trigger: PaywallTrigger

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var products: [SubscriptionProduct] = []
    @State private var isBusy = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "lock.doc.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.tint)

                    Text(headline)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: 10) {
                        BenefitRow(text: "Unlimited saved purchases")
                        BenefitRow(text: "Tax, Warranty and Insurance Proof Packs")
                        BenefitRow(text: "Item, serial number and warranty tracking")
                        BenefitRow(text: "Full search across every purchase")
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    if products.isEmpty {
                        ProgressView().padding()
                    } else {
                        ForEach(products) { product in
                            Button {
                                Task { await purchase(product) }
                            } label: {
                                HStack {
                                    Text(product.displayName)
                                    Spacer()
                                    Text(product.displayPrice).font(.headline)
                                }
                                .padding()
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(isBusy)
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage).font(.footnote).foregroundStyle(.red)
                    }

                    Button("Restore Purchases") {
                        Task { await restore() }
                    }
                    .font(.footnote)
                    .disabled(isBusy)

                    // Spec 11.1: existing records stay visible and
                    // exportable even without a subscription.
                    Text("Existing purchases stay safe and visible even if you don't subscribe.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task { await loadProducts() }
    }

    private var headline: String {
        switch trigger {
        case .freeLimitReached: return "You've reached the free limit"
        case .proOnlyExport: return "Proof Packs are a Solo Pro feature"
        case .gatedItemFeature: return "This feature is part of Solo Pro"
        }
    }

    private func loadProducts() async {
        products = (try? await environment.subscriptionService.loadProducts()) ?? []
        if products.isEmpty {
            errorMessage = "Couldn't load subscription options right now. Please try again later."
        }
    }

    private func purchase(_ product: SubscriptionProduct) async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            try await environment.subscriptionService.purchase(product)
            environment.analyticsService.track(.subscriptionStarted(productID: product.id, offerType: "standard"))
            dismiss()
        } catch SubscriptionError.userCancelled {
            // Not an error worth surfacing.
        } catch {
            errorMessage = "That didn't go through. Your existing purchases are unaffected - please try again."
        }
    }

    private func restore() async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            try await environment.subscriptionService.restorePurchases()
            dismiss()
        } catch {
            errorMessage = "Couldn't restore purchases right now. Please try again."
        }
    }
}

private struct BenefitRow: View {
    let text: String
    var body: some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .foregroundStyle(.primary)
            .font(.subheadline)
    }
}

#Preview {
    PaywallView(trigger: .proOnlyExport)
        .environment(AppEnvironment.preview())
}
