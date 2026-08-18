import SwiftUI
import ReceiptVaultCore

struct ItemDetailView: View {
    let itemID: UUID

    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ItemDetailViewModel?
    @State private var isEditPresented = false
    @State private var isExportPresented = false

    var body: some View {
        Group {
            if let viewModel, let item = viewModel.item {
                detail(viewModel, item)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Item")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil {
                viewModel = ItemDetailViewModel(itemID: itemID, environment: environment)
            }
            await viewModel?.load()
        }
        .onChange(of: viewModel?.didDelete) { _, didDelete in
            if didDelete == true { dismiss() }
        }
    }

    @ViewBuilder
    private func detail(_ viewModel: ItemDetailViewModel, _ item: Item) -> some View {
        Form {
            Section {
                Text(item.name).font(.title3.bold())
                let subtitle = [item.brand, item.model].compactMap { $0 }.joined(separator: " ")
                if !subtitle.isEmpty { Text(subtitle).foregroundStyle(.secondary) }
                if let serial = item.serialNumber {
                    LabeledContent("Serial", value: serial)
                }
                if let value = item.originalValue {
                    LabeledContent("Value", value: Money.format(value))
                }
                if let location = item.location {
                    LabeledContent("Location", value: location)
                }
            }

            if !viewModel.photos.isEmpty {
                Section("Photos") {
                    ScrollView(.horizontal) {
                        HStack {
                            ForEach(Array(viewModel.photos.enumerated()), id: \.offset) { _, image in
                                Image(uiImage: image)
                                    .resizable().scaledToFill()
                                    .frame(width: 90, height: 90)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
            }

            if let warranty = item.warranty {
                Section("Warranty") {
                    WarrantyStatusBadge(status: warranty.status())
                    if let provider = warranty.provider { LabeledContent("Provider", value: provider) }
                    if let expiry = warranty.expiryDate { LabeledContent("Expires", value: DateFormatting.shortAU(expiry)) }
                    if let details = warranty.details, !details.isEmpty { Text(details).font(.footnote) }
                }
            }

            Section("Purchase evidence") {
                if viewModel.linkedPurchases.isEmpty {
                    Text("No purchase proof linked yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.linkedPurchases) { purchase in
                        Button {
                            router.navigate(to: .purchaseDetail(purchase.id), in: .items)
                        } label: {
                            PurchaseRowView(purchase: purchase)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let notes = item.notes, !notes.isEmpty {
                Section("Notes") { Text(notes) }
            }

            Section {
                Button { isExportPresented = true } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                Button(role: .destructive) {
                    viewModel.isDeleteConfirmationPresented = true
                } label: {
                    Label("Delete item", systemImage: "trash")
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { isEditPresented = true }
            }
        }
        .sheet(isPresented: $isEditPresented) {
            NavigationStack {
                ItemEditView(itemID: itemID, prefillFromPurchaseID: nil) {
                    Task { await viewModel.load() }
                }
            }
        }
        .sheet(isPresented: $isExportPresented) {
            ExportBuilderView(preselectedItemIDs: [itemID])
        }
        .confirmationDialog(
            "Delete this item? Its linked purchase evidence is kept.",
            isPresented: Binding(get: { viewModel.isDeleteConfirmationPresented }, set: { viewModel.isDeleteConfirmationPresented = $0 }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { Task { await viewModel.delete() } }
            Button("Cancel", role: .cancel) {}
        }
    }
}

#Preview {
    NavigationStack {
        ItemDetailView(itemID: UUID())
    }
    .environment(AppEnvironment.preview())
    .environment(AppRouter())
}
