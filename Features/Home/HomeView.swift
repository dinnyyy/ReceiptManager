import SwiftUI
import ReceiptVaultCore

/// Spec 5.3. Copy per spec 22: "Keep proof of what you buy" - no charts,
/// no accounting dashboard language.
struct HomeView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router
    @State private var viewModel: HomeViewModel?

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Home")
        .scanToolbar()
        .task {
            if viewModel == nil {
                viewModel = HomeViewModel(environment: environment)
            }
            viewModel?.load()
        }
    }

    @ViewBuilder
    private func content(_ viewModel: HomeViewModel) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                scanCTA

                if viewModel.isEmpty {
                    emptyState
                } else {
                    if viewModel.needsReviewCount > 0 {
                        inboxCard(count: viewModel.needsReviewCount)
                    }
                    if !viewModel.itemsWithWarrantyEndingSoon.isEmpty {
                        warrantyCard(items: viewModel.itemsWithWarrantyEndingSoon)
                    }
                    if !viewModel.recentPurchases.isEmpty {
                        recentSection(viewModel.recentPurchases)
                    }
                }
            }
            .padding()
        }
        .refreshable { await viewModel.refresh() }
    }

    private var scanCTA: some View {
        Button {
            router.presentCaptureSheet()
        } label: {
            Label("Scan receipt", systemImage: "camera.viewfinder")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Keep proof of what you buy")
                .font(.headline)
            Text("Scan your first receipt to get started. It'll be searchable for tax, warranty or insurance whenever you need it.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
        .padding(.horizontal, 24)
    }

    private func inboxCard(count: Int) -> some View {
        Button {
            router.vaultStatusFilterRequest = .needsReview
            router.selectedTab = .vault
        } label: {
            HomeAttentionCard(
                systemImage: "tray.full",
                title: "Inbox",
                subtitle: "\(count) item\(count == 1 ? "" : "s") need checking"
            )
        }
        .buttonStyle(.plain)
    }

    private func warrantyCard(items: [Item]) -> some View {
        Button {
            router.selectedTab = .items
        } label: {
            HomeAttentionCard(
                systemImage: "clock.badge.exclamationmark",
                title: "Warranty ending soon",
                subtitle: items.count == 1 ? items[0].name : "\(items.count) items within 30 days"
            )
        }
        .buttonStyle(.plain)
    }

    private func recentSection(_ purchases: [Purchase]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent")
                .font(.headline)
            VStack(spacing: 0) {
                ForEach(purchases) { purchase in
                    Button {
                        router.navigate(to: .purchaseDetail(purchase.id), in: .home)
                    } label: {
                        PurchaseRowView(purchase: purchase)
                            .padding(.horizontal, 12)
                    }
                    .buttonStyle(.plain)
                    if purchase.id != purchases.last?.id {
                        Divider().padding(.leading, 12)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

private struct HomeAttentionCard: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .environment(AppEnvironment.preview())
    .environment(AppRouter())
}
