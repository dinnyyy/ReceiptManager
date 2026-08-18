import XCTest
import SwiftData
@testable import ReceiptVault
import ReceiptVaultCore

/// Integration-style tests against a real in-memory SwiftData container
/// (not a mock) - the closest thing to spec 17.2's "offline save ->
/// reconnect -> upload/upsert -> synced" test without a live Supabase
/// project. Run via Xcode/`xcodebuild test`; unverified by compilation in
/// this dev environment (see CLAUDE.md section 4).
final class SwiftDataPurchaseRepositoryTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var repository: SwiftDataPurchaseRepository!
    private let workspaceID = UUID()

    override func setUpWithError() throws {
        container = try ModelContainer(for: Schema(PersistenceSchema.models), configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        context = ModelContext(container)
        repository = SwiftDataPurchaseRepository(modelContext: context)
    }

    func testSaveDraftThenFetchRoundTrips() throws {
        let purchase = Purchase(
            workspaceID: workspaceID, status: .saved, merchantName: "Bunnings Warehouse",
            purchaseDate: DateOnly(year: 2026, month: 8, day: 13), totalAmount: Decimal(string: "249.00"),
            purposes: [.tax, .warranty]
        )
        try repository.saveDraft(purchase)

        let fetched = try repository.fetch(id: purchase.id)
        XCTAssertEqual(fetched?.merchantName, "Bunnings Warehouse")
        XCTAssertEqual(fetched?.purposes, [.tax, .warranty])
        XCTAssertEqual(fetched?.totalAmount, Decimal(string: "249.00"))
    }

    func testSaveDraftIsIdempotentByID() throws {
        var purchase = Purchase(workspaceID: workspaceID, merchantName: "Original")
        try repository.saveDraft(purchase)
        purchase.merchantName = "Updated"
        try repository.saveDraft(purchase)

        let all = try repository.search(PurchaseSearchQuery(status: nil), workspaceID: workspaceID)
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.merchantName, "Updated")
    }

    func testSearchFiltersByWorkspace() throws {
        let otherWorkspaceID = UUID()
        try repository.saveDraft(Purchase(workspaceID: workspaceID, status: .saved, merchantName: "Mine"))
        try repository.saveDraft(Purchase(workspaceID: otherWorkspaceID, status: .saved, merchantName: "Not mine"))

        let results = try repository.search(PurchaseSearchQuery(), workspaceID: workspaceID)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.merchantName, "Mine")
    }

    func testSearchByPurposeAndTextCombine() throws {
        try repository.saveDraft(Purchase(workspaceID: workspaceID, status: .saved, merchantName: "Bunnings", purposes: [.tax]))
        try repository.saveDraft(Purchase(workspaceID: workspaceID, status: .saved, merchantName: "Officeworks", purposes: [.personal]))

        let taxOnly = try repository.search(PurchaseSearchQuery(purposes: [.tax]), workspaceID: workspaceID)
        XCTAssertEqual(taxOnly.map(\.merchantName), ["Bunnings"])

        let textMatch = try repository.search(PurchaseSearchQuery(text: "office"), workspaceID: workspaceID)
        XCTAssertEqual(textMatch.map(\.merchantName), ["Officeworks"])
    }

    func testDefaultSearchExcludesDrafts() throws {
        try repository.saveDraft(Purchase(workspaceID: workspaceID, status: .draft, merchantName: "Unfinished"))
        try repository.saveDraft(Purchase(workspaceID: workspaceID, status: .saved, merchantName: "Finished"))

        let results = try repository.search(PurchaseSearchQuery(status: nil), workspaceID: workspaceID)
        XCTAssertEqual(results.map(\.merchantName), ["Finished"])
    }

    func testDeleteRemovesRecord() throws {
        let purchase = Purchase(workspaceID: workspaceID, status: .saved)
        try repository.saveDraft(purchase)
        try repository.delete(id: purchase.id)
        XCTAssertNil(try repository.fetch(id: purchase.id))
    }

    func testSortByAmountHighToLow() throws {
        try repository.saveDraft(Purchase(workspaceID: workspaceID, status: .saved, merchantName: "Cheap", totalAmount: 10))
        try repository.saveDraft(Purchase(workspaceID: workspaceID, status: .saved, merchantName: "Expensive", totalAmount: 500))

        let results = try repository.search(PurchaseSearchQuery(sort: .amountHighToLow), workspaceID: workspaceID)
        XCTAssertEqual(results.map(\.merchantName), ["Expensive", "Cheap"])
    }
}
