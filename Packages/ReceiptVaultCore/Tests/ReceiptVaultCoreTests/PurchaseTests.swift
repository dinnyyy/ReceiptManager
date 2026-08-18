import XCTest
@testable import ReceiptVaultCore

final class PurchaseTests: XCTestCase {
    func testFinancialYearDerivedFromPurchaseDate() {
        var purchase = Purchase(workspaceID: UUID())
        purchase.purchaseDate = DateOnly(year: 2026, month: 8, day: 13)
        XCTAssertEqual(purchase.financialYear?.label, "FY2026-27")
    }

    func testFinancialYearNilWithoutDate() {
        let purchase = Purchase(workspaceID: UUID())
        XCTAssertNil(purchase.financialYear)
    }

    func testUnreadableReceiptCanStillBeSavedWithJustAPurpose() {
        // Spec 7.2: purchase_date may be null for unreadable/unknown
        // receipts, and every field besides evidence itself is optional.
        var purchase = Purchase(workspaceID: UUID())
        purchase.purposes = [.tax]
        XCTAssertTrue(purchase.hasMinimumDataToSave)
    }

    func testCompletelyEmptyDraftIsNotSaveReady() {
        let purchase = Purchase(workspaceID: UUID())
        XCTAssertFalse(purchase.hasMinimumDataToSave)
    }

    func testMultiplePurposesOnOnePurchaseNoDuplication() {
        // The core product thesis (CLAUDE.md section 1): one purchase, many
        // purposes, no duplicate records.
        var purchase = Purchase(workspaceID: UUID())
        purchase.purposes = [.tax, .warranty, .insurance, .asset]
        XCTAssertEqual(purchase.purposes.count, 4)
    }
}
