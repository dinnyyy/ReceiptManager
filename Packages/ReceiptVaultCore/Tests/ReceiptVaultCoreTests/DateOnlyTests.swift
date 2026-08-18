import XCTest
@testable import ReceiptVaultCore

final class DateOnlyTests: XCTestCase {
    func testInvalidDatesRejected() {
        XCTAssertNil(DateOnly(year: 2026, month: 2, day: 30))
        XCTAssertNil(DateOnly(year: 2026, month: 13, day: 1))
        XCTAssertNil(DateOnly(year: 2026, month: 0, day: 1))
        XCTAssertNil(DateOnly(year: 2026, month: 4, day: 31))
    }

    func testLeapYearFebruary() {
        XCTAssertNotNil(DateOnly(year: 2028, month: 2, day: 29)) // 2028 is a leap year
        XCTAssertNil(DateOnly(year: 2026, month: 2, day: 29)) // 2026 is not
        XCTAssertNotNil(DateOnly(year: 2000, month: 2, day: 29)) // divisible by 400
        XCTAssertNil(DateOnly(year: 1900, month: 2, day: 29)) // divisible by 100, not 400
    }

    func testISOStringRoundTrip() {
        let date = DateOnly(year: 2026, month: 8, day: 13)!
        XCTAssertEqual(date.isoString, "2026-08-13")
        XCTAssertEqual(DateOnly(isoString: "2026-08-13"), date)
    }

    func testComparable() {
        let a = DateOnly(year: 2026, month: 8, day: 13)!
        let b = DateOnly(year: 2026, month: 8, day: 14)!
        let c = DateOnly(year: 2027, month: 1, day: 1)!
        XCTAssertLessThan(a, b)
        XCTAssertLessThan(b, c)
    }

    func testDaysSince1970RoundTrip() {
        let cases = [
            DateOnly(year: 1970, month: 1, day: 1)!,
            DateOnly(year: 2026, month: 8, day: 13)!,
            DateOnly(year: 2000, month: 2, day: 29)!,
            DateOnly(year: 1969, month: 12, day: 31)!,
            DateOnly(year: 1900, month: 1, day: 1)!,
            DateOnly(year: 2099, month: 12, day: 31)!,
        ]
        for date in cases {
            let days = date.daysSince1970()
            XCTAssertEqual(DateOnly.fromDaysSince1970(days), date, "round-trip failed for \(date.isoString)")
        }
    }

    func testDaysUntilExpiry() {
        let start = DateOnly(year: 2026, month: 8, day: 13)!
        let expiry = DateOnly(year: 2029, month: 8, day: 13)!
        // 2028 is a leap year within this range, so this is not a plain 365*3.
        XCTAssertEqual(start.days(until: expiry), 1096)
    }
}
