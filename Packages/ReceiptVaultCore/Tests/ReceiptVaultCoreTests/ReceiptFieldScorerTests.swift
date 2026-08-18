import XCTest
@testable import ReceiptVaultCore

final class ReceiptFieldScorerTests: XCTestCase {
    // Same synthetic receipts validated in the Python prototype (CLAUDE.md section 4).
    func testBunningsStyleReceiptPicksTotalNotSubtotal() {
        let lines = [
            "BUNNINGS WAREHOUSE",
            "123 Main St",
            "ABN 12 345 678 901",
            "Impact Driver          $249.00",
            "SUBTOTAL               $226.36",
            "GST                     $22.64",
            "TOTAL                  $249.00",
            "EFTPOS                 $249.00",
            "CHANGE                   $0.00",
        ]
        let result = ReceiptFieldScorer.parse(lines: lines)
        XCTAssertEqual(result.totalAmount, Decimal(string: "249.00"))
        XCTAssertEqual(result.gstAmount, Decimal(string: "22.64"))
        XCTAssertEqual(result.merchantName, "BUNNINGS WAREHOUSE")
    }

    func testGSTIncludedLeftBlankNotComputed() {
        let lines = [
            "COLES SUPERMARKET",
            "Milk                     $4.50",
            "Bread                    $3.20",
            "SUBTOTAL                 $7.70",
            "GST INCLUDED",
            "GRAND TOTAL               $7.70",
            "TENDERED  CASH          $10.00",
            "CHANGE                   $2.30",
        ]
        let result = ReceiptFieldScorer.parse(lines: lines)
        XCTAssertEqual(result.totalAmount, Decimal(string: "7.70"))
        // Spec 6.3: never compute GST automatically - "GST included" with
        // no explicit amount must stay blank, not silently derived.
        XCTAssertNil(result.gstAmount)
    }

    func testNoKeywordsStillFindsOnlyPlausibleAmount() {
        let lines = ["SOME SHOP", "Item                    $19.99", "$19.99"]
        let result = ReceiptFieldScorer.parse(lines: lines)
        XCTAssertEqual(result.totalAmount, Decimal(string: "19.99"))
    }

    func testReceiptNumberExtraction() {
        let lines = ["SHOP", "RECEIPT #: A-12345", "TOTAL $10.00"]
        let result = ReceiptFieldScorer.parse(lines: lines)
        XCTAssertEqual(result.receiptNumber, "A-12345")
    }

    func testEmptyInputProducesNoFields() {
        let result = ReceiptFieldScorer.parse(lines: [])
        XCTAssertNil(result.totalAmount)
        XCTAssertNil(result.gstAmount)
        XCTAssertNil(result.merchantName)
        XCTAssertNil(result.purchaseDate)
    }
}
