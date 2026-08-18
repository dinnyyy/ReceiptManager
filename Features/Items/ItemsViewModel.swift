import Foundation
import Observation
import ReceiptVaultCore

@MainActor
@Observable
final class ItemsViewModel {
    private let environment: AppEnvironment

    var searchText = "" { didSet { runSearch() } }
    var warrantyEndingSoonOnly = false { didSet { runSearch() } }
    var results: [Item] = []

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func load() {
        runSearch()
    }

    private func runSearch() {
        guard let workspaceID = environment.currentWorkspaceID else { return }
        let query = ItemSearchQuery(text: searchText.isEmpty ? nil : searchText, warrantyEndingSoonOnly: warrantyEndingSoonOnly, sort: .recentlyAdded)
        results = (try? environment.itemRepository.search(query, workspaceID: workspaceID)) ?? []
    }
}
