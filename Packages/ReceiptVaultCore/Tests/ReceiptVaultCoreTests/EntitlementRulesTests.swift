import XCTest
@testable import ReceiptVaultCore

final class EntitlementRulesTests: XCTestCase {
    func testFreeUserBelowLimitCanSave() {
        XCTAssertTrue(EntitlementRules.canSaveNewPurchase(currentSavedCount: 39, plan: .free, freeLimit: 40))
        XCTAssertFalse(EntitlementRules.shouldShowPaywall(currentSavedCount: 39, plan: .free, freeLimit: 40))
    }

    func testFreeUserAtLimitCannotSave() {
        XCTAssertFalse(EntitlementRules.canSaveNewPurchase(currentSavedCount: 40, plan: .free, freeLimit: 40))
        XCTAssertTrue(EntitlementRules.shouldShowPaywall(currentSavedCount: 40, plan: .free, freeLimit: 40))
    }

    func testPaidUserNeverLimited() {
        XCTAssertTrue(EntitlementRules.canSaveNewPurchase(currentSavedCount: 10_000, plan: .soloProMonthly, freeLimit: 40))
        XCTAssertTrue(EntitlementRules.canSaveNewPurchase(currentSavedCount: 10_000, plan: .soloProAnnual, freeLimit: 40))
        XCTAssertFalse(EntitlementRules.shouldShowPaywall(currentSavedCount: 10_000, plan: .soloProMonthly, freeLimit: 40))
    }

    func testProofPacksGatedBehindPaidPlan() {
        XCTAssertFalse(EntitlementRules.canGenerateProofPack(plan: .free))
        XCTAssertTrue(EntitlementRules.canGenerateProofPack(plan: .soloProMonthly))
        XCTAssertTrue(EntitlementRules.canGenerateProofPack(plan: .soloProAnnual))
    }

    func testDataPortabilityNeverGated() {
        // Spec 11.1: full-account export must work regardless of plan.
        for plan in SubscriptionPlan.allCases {
            XCTAssertTrue(EntitlementRules.canExportAllData(plan: plan))
            XCTAssertTrue(EntitlementRules.canViewExistingRecords(plan: plan))
        }
    }
}
