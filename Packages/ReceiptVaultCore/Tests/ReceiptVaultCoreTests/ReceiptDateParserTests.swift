import XCTest
@testable import ReceiptVaultCore

final class ReceiptDateParserTests: XCTestCase {
    // Same cases validated in the Python prototype (CLAUDE.md section 4).
    func testSupportedFormats() {
        let expected = DateOnly(year: 2026, month: 8, day: 13)!
        let inputs = [
            "13/08/2026", "13-08-2026", "13.08.2026", "13/08/26",
            "2026-08-13", "2026/08/13",
            "13 Aug 2026", "13-Aug-2026",
            "Aug 13, 2026", "August 13 2026",
        ]
        for input in inputs {
            XCTAssertEqual(ReceiptDateParser.parse(input), expected, "for input \(input)")
        }
    }

    func testAustralianDayFirstDisambiguation() {
        // 01/02/2026 is AU day-first: 1 February, not 2 January.
        XCTAssertEqual(ReceiptDateParser.parse("01/02/2026"), DateOnly(year: 2026, month: 2, day: 1))
        // day > 12 disambiguates unambiguously regardless of convention.
        XCTAssertEqual(ReceiptDateParser.parse("31/01/2026"), DateOnly(year: 2026, month: 1, day: 31))
    }

    func testUnparseableInputsReturnNil() {
        XCTAssertNil(ReceiptDateParser.parse("not a date"))
        XCTAssertNil(ReceiptDateParser.parse("99/99/9999"))
        XCTAssertNil(ReceiptDateParser.parse("30/02/2026")) // Feb 30 doesn't exist
        XCTAssertNil(ReceiptDateParser.parse(""))
    }
}
