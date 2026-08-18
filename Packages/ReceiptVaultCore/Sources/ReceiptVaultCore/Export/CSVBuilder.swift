import Foundation

/// RFC 4180-style CSV construction (spec 12.5: "CSV escapes
/// commas/quotes/newlines correctly, uses UTF-8 and decimal period").
/// Escaping logic ported and edge-case-matched from a Python prototype (see
/// CLAUDE.md section 4).
public enum CSV {
    public static func escape(_ field: String?) -> String {
        guard let field, !field.isEmpty else { return "" }
        let needsQuoting = field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r")
        guard needsQuoting else { return field }
        let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    public static func row(_ fields: [String?]) -> String {
        fields.map(escape).joined(separator: ",")
    }
}

/// One row of the Tax Pack CSV (spec 12.2 column order):
/// purchase_id,purchase_date,merchant,total_amount,gst_amount,currency,
/// receipt_number,category,purposes,folder,tags,item_names,notes
public struct TaxCSVRow: Sendable {
    public let purchaseID: String
    public let purchaseDate: DateOnly?
    public let merchant: String?
    public let totalAmount: Decimal?
    public let gstAmount: Decimal?
    public let currency: String
    public let receiptNumber: String?
    public let category: String?
    public let purposes: [PurchasePurpose]
    public let folder: String?
    public let tags: [String]
    public let itemNames: [String]
    public let notes: String?

    public init(
        purchaseID: String, purchaseDate: DateOnly?, merchant: String?, totalAmount: Decimal?,
        gstAmount: Decimal?, currency: String, receiptNumber: String?, category: String?,
        purposes: [PurchasePurpose], folder: String?, tags: [String], itemNames: [String], notes: String?
    ) {
        self.purchaseID = purchaseID
        self.purchaseDate = purchaseDate
        self.merchant = merchant
        self.totalAmount = totalAmount
        self.gstAmount = gstAmount
        self.currency = currency
        self.receiptNumber = receiptNumber
        self.category = category
        self.purposes = purposes
        self.folder = folder
        self.tags = tags
        self.itemNames = itemNames
        self.notes = notes
    }
}

public enum TaxCSVBuilder {
    public static let header = "purchase_id,purchase_date,merchant,total_amount,gst_amount,currency,receipt_number,category,purposes,folder,tags,item_names,notes"

    /// Multi-value cells (purposes/tags/item_names) join with "; " inside
    /// the cell; CSV.escape still quotes the whole cell if any item name
    /// happens to contain a comma.
    public static func build(rows: [TaxCSVRow]) -> String {
        var lines = [header]
        for row in rows {
            let fields: [String?] = [
                row.purchaseID,
                row.purchaseDate?.isoString,
                row.merchant,
                row.totalAmount.map { "\($0)" },
                row.gstAmount.map { "\($0)" },
                row.currency,
                row.receiptNumber,
                row.category,
                row.purposes.map(\.displayName).joined(separator: "; "),
                row.folder,
                row.tags.joined(separator: "; "),
                row.itemNames.joined(separator: "; "),
                row.notes,
            ]
            lines.append(CSV.row(fields))
        }
        // CRLF line endings are the RFC 4180 default and open cleanly in
        // Excel/Numbers on both platforms accountants actually use.
        return lines.joined(separator: "\r\n")
    }
}
