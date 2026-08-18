import XCTest
@testable import ReceiptVaultCore

final class MoneyTests: XCTestCase {
    func testParseVariousFormats() {
        XCTAssertEqual(Money.parse("$1,234.56"), Decimal(string: "1234.56"))
        XCTAssertEqual(Money.parse("1234.56"), Decimal(string: "1234.56"))
        XCTAssertEqual(Money.parse("$0.10"), Decimal(string: "0.10"))
        XCTAssertEqual(Money.parse("  $249.00  "), Decimal(string: "249.00"))
    }

    func testParseRejectsGarbage() {
        XCTAssertNil(Money.parse(""))
        XCTAssertNil(Money.parse("free"))
    }

    func testDecimalPreservesExactValueDoubleWouldCorrupt() {
        // The canonical Double failure case: 0.1 + 0.2 != 0.3 in binary
        // floating point. Decimal must not have this problem.
        let a = Decimal(string: "0.10")!
        let b = Decimal(string: "0.20")!
        XCTAssertEqual(a + b, Decimal(string: "0.30")!)
    }

    func testRounding() {
        XCTAssertEqual(Money.rounded(Decimal(string: "10.005")!), Decimal(string: "10.01")!)
        XCTAssertEqual(Money.rounded(Decimal(string: "10.004")!), Decimal(string: "10.00")!)
    }
}
