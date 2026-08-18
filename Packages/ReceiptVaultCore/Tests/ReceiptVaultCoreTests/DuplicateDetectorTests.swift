import XCTest
@testable import ReceiptVaultCore

final class DuplicateDetectorTests: XCTestCase {
    // Same cases validated in the Python prototype (CLAUDE.md section 4).
    func testExactMatchScoresMaximum() {
        let a = DuplicateCandidateFields(
            merchantName: "Bunnings Warehouse", purchaseDate: DateOnly(year: 2026, month: 8, day: 13),
            totalAmount: Decimal(string: "249.00"), receiptNumber: "R123"
        )
        let b = DuplicateCandidateFields(
            merchantName: "BUNNINGS WAREHOUSE", purchaseDate: DateOnly(year: 2026, month: 8, day: 13),
            totalAmount: Decimal(string: "249.00"), receiptNumber: "R123"
        )
        XCTAssertEqual(DuplicateDetector.score(a, against: b), 100)
        XCTAssertTrue(DuplicateDetector.isLikelyDuplicate(a, against: b))
    }

    func testCompletelyDifferentScoresZero() {
        let a = DuplicateCandidateFields(
            merchantName: "Bunnings Warehouse", purchaseDate: DateOnly(year: 2026, month: 8, day: 13),
            totalAmount: Decimal(string: "249.00"), receiptNumber: "R123"
        )
        let b = DuplicateCandidateFields(
            merchantName: "Officeworks", purchaseDate: DateOnly(year: 2026, month: 7, day: 2),
            totalAmount: Decimal(string: "89.95"), receiptNumber: "R999"
        )
        XCTAssertEqual(DuplicateDetector.score(a, against: b), 0)
        XCTAssertFalse(DuplicateDetector.isLikelyDuplicate(a, against: b))
    }

    func testMerchantAndDateMatchButDifferentAmountStaysBelowThreshold() {
        let a = DuplicateCandidateFields(
            merchantName: "Bunnings Warehouse", purchaseDate: DateOnly(year: 2026, month: 8, day: 13),
            totalAmount: Decimal(string: "249.00"), receiptNumber: nil
        )
        let b = DuplicateCandidateFields(
            merchantName: "Bunnings Warehouse", purchaseDate: DateOnly(year: 2026, month: 8, day: 13),
            totalAmount: Decimal(string: "12.50"), receiptNumber: nil
        )
        XCTAssertEqual(DuplicateDetector.score(a, against: b), 60)
        XCTAssertTrue(DuplicateDetector.isLikelyDuplicate(a, against: b)) // >= 60 threshold
    }

    func testFileHashMatchAloneCrossesThreshold() {
        let a = DuplicateCandidateFields(merchantName: nil, purchaseDate: nil, totalAmount: nil, receiptNumber: nil)
        let b = DuplicateCandidateFields(
            merchantName: nil, purchaseDate: nil, totalAmount: nil, receiptNumber: nil, fileHashMatches: true
        )
        XCTAssertEqual(DuplicateDetector.score(a, against: b), 50)
        XCTAssertFalse(DuplicateDetector.isLikelyDuplicate(a, against: b)) // 50 < 60 threshold alone
    }

    func testClosestMatchReturnsHighestScoringCandidate() {
        let candidate = DuplicateCandidateFields(
            merchantName: "Bunnings Warehouse", purchaseDate: DateOnly(year: 2026, month: 8, day: 13),
            totalAmount: Decimal(string: "249.00"), receiptNumber: nil
        )
        let existing: [(id: String, fields: DuplicateCandidateFields)] = [
            ("unrelated", DuplicateCandidateFields(merchantName: "Officeworks", purchaseDate: nil, totalAmount: nil, receiptNumber: nil)),
            ("close", DuplicateCandidateFields(
                merchantName: "Bunnings Warehouse", purchaseDate: DateOnly(year: 2026, month: 8, day: 13),
                totalAmount: Decimal(string: "249.00"), receiptNumber: nil
            )),
        ]
        let match = DuplicateDetector.closestMatch(for: candidate, among: existing)
        XCTAssertEqual(match?.id, "close")
    }

    func testClosestMatchReturnsNilBelowThreshold() {
        let candidate = DuplicateCandidateFields(merchantName: "Bunnings", purchaseDate: nil, totalAmount: nil, receiptNumber: nil)
        let existing: [(id: String, fields: DuplicateCandidateFields)] = [
            ("unrelated", DuplicateCandidateFields(merchantName: "Officeworks", purchaseDate: nil, totalAmount: nil, receiptNumber: nil)),
        ]
        XCTAssertNil(DuplicateDetector.closestMatch(for: candidate, among: existing))
    }
}
