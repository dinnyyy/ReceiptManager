import XCTest
@testable import ReceiptVaultCore

final class AustralianFinancialYearTests: XCTestCase {
    // Same boundary cases validated in the Python prototype (CLAUDE.md section 4).
    func testBoundaryCases() {
        let cases: [(DateOnly, Int, String)] = [
            (DateOnly(year: 2026, month: 6, day: 30)!, 2025, "FY2025-26"),
            (DateOnly(year: 2026, month: 7, day: 1)!, 2026, "FY2026-27"),
            (DateOnly(year: 2026, month: 12, day: 31)!, 2026, "FY2026-27"),
            (DateOnly(year: 2027, month: 1, day: 1)!, 2026, "FY2026-27"),
            (DateOnly(year: 2027, month: 6, day: 30)!, 2026, "FY2026-27"),
            (DateOnly(year: 2027, month: 7, day: 1)!, 2027, "FY2027-28"),
            (DateOnly(year: 2099, month: 6, day: 30)!, 2098, "FY2098-99"),
        ]
        for (date, expectedStart, expectedLabel) in cases {
            let fy = AustralianFinancialYear(containing: date)
            XCTAssertEqual(fy.startYear, expectedStart, "for \(date.isoString)")
            XCTAssertEqual(fy.label, expectedLabel, "for \(date.isoString)")
        }
    }

    func testContainsBoundaries() {
        let fy = AustralianFinancialYear(startYear: 2026)
        XCTAssertTrue(fy.contains(DateOnly(year: 2026, month: 7, day: 1)!))
        XCTAssertTrue(fy.contains(DateOnly(year: 2027, month: 6, day: 30)!))
        XCTAssertFalse(fy.contains(DateOnly(year: 2026, month: 6, day: 30)!))
        XCTAssertFalse(fy.contains(DateOnly(year: 2027, month: 7, day: 1)!))
    }
}
