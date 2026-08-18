import SwiftUI
import ReceiptVaultCore

struct VaultView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router
    @State private var viewModel: VaultViewModel?

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Vault")
        .scanToolbar()
        .task {
            if viewModel == nil {
                viewModel = VaultViewModel(environment: environment)
            }
            let requested = router.vaultStatusFilterRequest
            router.vaultStatusFilterRequest = nil
            viewModel?.onAppear(initialStatusFilter: requested)
        }
    }

    @ViewBuilder
    private func content(_ viewModel: VaultViewModel) -> some View {
        @Bindable var viewModel = viewModel
        VStack(spacing: 0) {
            filterBar(viewModel)

            if viewModel.results.isEmpty {
                noResultsState(viewModel)
            } else {
                List(selection: viewModel.isMultiSelectMode ? $viewModel.selectedPurchaseIDs : .constant([])) {
                    ForEach(viewModel.results) { purchase in
                        if viewModel.isMultiSelectMode {
                            PurchaseRowView(purchase: purchase)
                                .tag(purchase.id)
                        } else {
                            Button {
                                router.navigate(to: .purchaseDetail(purchase.id), in: .vault)
                            } label: {
                                PurchaseRowView(purchase: purchase)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listStyle(.plain)
                .environment(\.editMode, .constant(viewModel.isMultiSelectMode ? .active : .inactive))
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search merchant, amount, item, serial…")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(viewModel.isMultiSelectMode ? "Done" : "Select") {
                    viewModel.toggleMultiSelect()
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if viewModel.isMultiSelectMode, !viewModel.selectedPurchaseIDs.isEmpty {
                Button {
                    viewModel.isExportPresented = true
                } label: {
                    Label("Export \(viewModel.selectedPurchaseIDs.count) selected", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding()
                .background(.bar)
            }
        }
        .sheet(isPresented: $viewModel.isExportPresented) {
            ExportBuilderView(preselectedPurchaseIDs: viewModel.selectedPurchaseIDs)
        }
    }

    private func filterBar(_ viewModel: VaultViewModel) -> some View {
        @Bindable var viewModel = viewModel
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu {
                    ForEach(PurchasePurpose.allCases, id: \.self) { purpose in
                        Toggle(purpose.displayName, isOn: Binding(
                            get: { viewModel.selectedPurposes.contains(purpose) },
                            set: { isOn in
                                if isOn { viewModel.selectedPurposes.insert(purpose) } else { viewModel.selectedPurposes.remove(purpose) }
                            }
                        ))
                    }
                } label: {
                    FilterChipLabel(title: "Purpose", isActive: !viewModel.selectedPurposes.isEmpty)
                }

                Menu {
                    Button("All years") { viewModel.selectedFinancialYear = nil }
                    ForEach(viewModel.availableFinancialYears, id: \.startYear) { fy in
                        Button(fy.label) { viewModel.selectedFinancialYear = fy }
                    }
                } label: {
                    FilterChipLabel(title: viewModel.selectedFinancialYear?.label ?? "Financial year", isActive: viewModel.selectedFinancialYear != nil)
                }

                Menu {
                    Button("All") { viewModel.statusFilter = nil }
                    Button("Needs review") { viewModel.statusFilter = .needsReview }
                    Button("Saved") { viewModel.statusFilter = .saved }
                } label: {
                    FilterChipLabel(title: "Status", isActive: viewModel.statusFilter != nil)
                }

                Menu {
                    Button("Newest") { viewModel.sort = .newest }
                    Button("Oldest") { viewModel.sort = .oldest }
                    Button("Amount: high to low") { viewModel.sort = .amountHighToLow }
                    Button("Amount: low to high") { viewModel.sort = .amountLowToHigh }
                    Button("Merchant A-Z") { viewModel.sort = .merchantAZ }
                } label: {
                    FilterChipLabel(title: "Sort", isActive: viewModel.sort != .newest)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private func noResultsState(_ viewModel: VaultViewModel) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(viewModel.hasActiveFilters ? "No matching purchases" : "Nothing here yet")
                .font(.headline)
            if viewModel.hasActiveFilters {
                Button("Clear filters") { viewModel.clearFilters() }
                    .font(.subheadline)
            }
            Spacer()
            Spacer()
        }
    }
}

private struct FilterChipLabel: View {
    let title: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
            Image(systemName: "chevron.down")
                .font(.caption2)
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isActive ? Color.accentColor.opacity(0.15) : Color(.secondarySystemBackground))
        .foregroundStyle(isActive ? Color.accentColor : Color.primary)
        .clipShape(Capsule())
    }
}

#Preview {
    NavigationStack {
        VaultView()
    }
    .environment(AppEnvironment.preview())
    .environment(AppRouter())
}
