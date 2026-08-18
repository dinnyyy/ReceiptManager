import SwiftUI
import ReceiptVaultCore

/// Spec 5.11: "Let users treat important purchases as real assets."
struct ItemsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router
    @State private var viewModel: ItemsViewModel?
    @State private var isCreatePresented = false

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Items")
        .scanToolbar()
        .task {
            if viewModel == nil {
                viewModel = ItemsViewModel(environment: environment)
            }
            viewModel?.load()
        }
    }

    @ViewBuilder
    private func content(_ viewModel: ItemsViewModel) -> some View {
        @Bindable var viewModel = viewModel
        VStack(spacing: 0) {
            Toggle("Warranty ending soon", isOn: $viewModel.warrantyEndingSoonOnly)
                .padding(.horizontal)
                .padding(.vertical, 6)

            if viewModel.results.isEmpty {
                emptyState
            } else {
                List(viewModel.results) { item in
                    Button {
                        router.navigate(to: .itemDetail(item.id), in: .items)
                    } label: {
                        ItemRowView(item: item)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search items, brand, serial…")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isCreatePresented = true
                } label: {
                    Label("Add item", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isCreatePresented) {
            NavigationStack {
                ItemEditView(itemID: nil, prefillFromPurchaseID: nil) {
                    viewModel.load()
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "shippingbox")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No items yet")
                .font(.headline)
            Text("Link a purchase to an item to track its serial number, warranty and location.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
    }
}

struct ItemRowView: View {
    let item: Item

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name).font(.body)
                let subtitle = [item.brand, item.model].compactMap { $0 }.joined(separator: " ")
                if !subtitle.isEmpty {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                if let location = item.location {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let warranty = item.warranty {
                WarrantyStatusBadge(status: warranty.status())
            }
        }
        .padding(.vertical, 4)
    }
}

struct WarrantyStatusBadge: View {
    let status: WarrantyStatus

    var body: some View {
        switch status {
        case .none:
            EmptyView()
        case .active:
            Text("Active").font(.caption2).foregroundStyle(.secondary)
        case .expiringSoon:
            Label("Ending soon", systemImage: "clock.badge.exclamationmark")
                .font(.caption2)
                .foregroundStyle(.orange)
        case .expired:
            Label("Expired", systemImage: "xmark.circle")
                .font(.caption2)
                .foregroundStyle(.red)
        }
    }
}

#Preview {
    NavigationStack {
        ItemsView()
    }
    .environment(AppEnvironment.preview())
    .environment(AppRouter())
}
