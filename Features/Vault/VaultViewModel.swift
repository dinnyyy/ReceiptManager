import Foundation
import Observation
import ReceiptVaultCore

/// Spec 5.10: "Retrieve old evidence faster than browsing folders." Text
/// search is debounced (spec: "Debounce remote search; search local cache
/// immediately where possible") even though there's no remote leg here -
/// the debounce still avoids re-querying on every keystroke for a large
/// local vault.
@MainActor
@Observable
final class VaultViewModel {
    private let environment: AppEnvironment
    private var searchTask: Task<Void, Never>?

    var searchText = "" {
        didSet { scheduleSearch() }
    }
    var selectedPurposes: Set<PurchasePurpose> = [] {
        didSet { runSearch() }
    }
    var selectedFinancialYear: AustralianFinancialYear? {
        didSet { runSearch() }
    }
    var statusFilter: PurchaseStatus? {
        didSet { runSearch() }
    }
    var sort: PurchaseSort = .newest {
        didSet { runSearch() }
    }

    var results: [Purchase] = []
    var availableFinancialYears: [AustralianFinancialYear] = []

    var isMultiSelectMode = false
    var selectedPurchaseIDs: Set<UUID> = []
    var isExportPresented = false

    var hasActiveFilters: Bool {
        !searchText.isEmpty || !selectedPurposes.isEmpty || selectedFinancialYear != nil || statusFilter != nil
    }

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func onAppear(initialStatusFilter: PurchaseStatus? = nil) {
        if let initialStatusFilter {
            statusFilter = initialStatusFilter
        }
        runSearch()
        computeAvailableFinancialYears()
    }

    func clearFilters() {
        searchText = ""
        selectedPurposes = []
        selectedFinancialYear = nil
        statusFilter = nil
    }

    func toggleMultiSelect() {
        isMultiSelectMode.toggle()
        if !isMultiSelectMode { selectedPurchaseIDs = [] }
    }

    func toggleSelection(_ id: UUID) {
        if selectedPurchaseIDs.contains(id) {
            selectedPurchaseIDs.remove(id)
        } else {
            selectedPurchaseIDs.insert(id)
        }
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            self?.runSearch()
        }
    }

    private func runSearch() {
        guard let workspaceID = environment.currentWorkspaceID else { return }
        let query = PurchaseSearchQuery(
            text: searchText.isEmpty ? nil : searchText,
            purposes: selectedPurposes.isEmpty ? nil : selectedPurposes,
            dateFrom: selectedFinancialYear?.start,
            dateTo: selectedFinancialYear?.end,
            status: statusFilter,
            sort: sort
        )
        results = (try? environment.purchaseRepository.search(query, workspaceID: workspaceID)) ?? []
    }

    private func computeAvailableFinancialYears() {
        guard let workspaceID = environment.currentWorkspaceID else { return }
        let all = (try? environment.purchaseRepository.search(PurchaseSearchQuery(), workspaceID: workspaceID)) ?? []
        let years = Set(all.compactMap { $0.purchaseDate.map(AustralianFinancialYear.init(containing:)) })
        availableFinancialYears = years.sorted { $0.startYear > $1.startYear }
    }
}
