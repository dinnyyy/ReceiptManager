import XCTest
@testable import ReceiptVaultCore

final class CSVBuilderTests: XCTestCase {
    // Same cases validated in the Python prototype (CLAUDE.md section 4).
    func testEscaping() {
        XCTAssertEqual(CSV.escape("Bunnings"), "Bunnings")
        XCTAssertEqual(CSV.escape("Bunnings, Warehouse"), "\"Bunnings, Warehouse\"")
        XCTAssertEqual(CSV.escape("He said \"hi\""), "\"He said \"\"hi\"\"\"")
        XCTAssertEqual(CSV.escape("Line1\nLine2"), "\"Line1\nLine2\"")
        XCTAssertEqual(CSV.escape(""), "")
        XCTAssertEqual(CSV.escape(nil), "")
    }

    func testRow() {
        let row = CSV.row(["Bunnings, Warehouse", "249.00", "He said \"hi\"", "plain"])
        XCTAssertEqual(row, "\"Bunnings, Warehouse\",249.00,\"He said \"\"hi\"\"\",plain")
    }

    func testTaxCSVBuilderHeaderAndColumnOrder() {
        // Column order is fixed by spec section 12.2 - accountants import
        // this by position, so changing the order silently breaks them.
        XCTAssertEqual(
            TaxCSVBuilder.header,
            "purchase_id,purchase_date,merchant,total_amount,gst_amount,currency,receipt_number,category,purposes,folder,tags,item_names,notes"
        )
    }

    func testTaxCSVBuilderRowContent() {
        let row = TaxCSVRow(
            purchaseID: "abc-123",
            purchaseDate: DateOnly(year: 2026, month: 8, day: 13),
            merchant: "Bunnings Warehouse",
            totalAmount: Decimal(string: "249.00"),
            gstAmount: Decimal(string: "22.64"),
            currency: "AUD",
            receiptNumber: "R-1",
            category: "Tools",
            purposes: [.tax],
            folder: nil,
            tags: ["Work Van"],
            itemNames: ["Impact Driver"],
            notes: nil
        )
        let csv = TaxCSVBuilder.build(rows: [row])
        let lines = csv.components(separatedBy: "\r\n")
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(
            lines[1],
            "abc-123,2026-08-13,Bunnings Warehouse,249.00,22.64,AUD,R-1,Tools,Tax,,Work Van,Impact Driver,"
        )
    }

    func testTaxCSVBuilderEscapesItemNameWithComma() {
        let row = TaxCSVRow(
            purchaseID: "abc-123", purchaseDate: nil, merchant: nil, totalAmount: nil, gstAmount: nil,
            currency: "AUD", receiptNumber: nil, category: nil, purposes: [], folder: nil, tags: [],
            itemNames: ["Drill, 18V"], notes: nil
        )
        let csv = TaxCSVBuilder.build(rows: [row])
        XCTAssertTrue(csv.contains("\"Drill, 18V\""))
    }
}
