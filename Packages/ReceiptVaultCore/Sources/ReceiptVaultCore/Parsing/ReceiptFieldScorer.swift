import Foundation

/// Confidence tier for a single extracted field (spec 6.3: "Confidence is
/// field-specific, not one global AI confidence"). High: prefill normally.
/// Medium: prefill with a subtle "check this" indicator. Low: leave blank
/// or visibly flag.
public enum FieldConfidence: Sendable {
    case high
    case medium
    case low
    case none
}

public struct ParsedReceiptFields: Sendable {
    public var merchantName: String?
    public var merchantConfidence: FieldConfidence
    public var purchaseDate: DateOnly?
    public var dateConfidence: FieldConfidence
    public var totalAmount: Decimal?
    public var totalConfidence: FieldConfidence
    public var gstAmount: Decimal?
    public var gstConfidence: FieldConfidence
    public var receiptNumber: String?

    public init(
        merchantName: String? = nil, merchantConfidence: FieldConfidence = .none,
        purchaseDate: DateOnly? = nil, dateConfidence: FieldConfidence = .none,
        totalAmount: Decimal? = nil, totalConfidence: FieldConfidence = .none,
        gstAmount: Decimal? = nil, gstConfidence: FieldConfidence = .none,
        receiptNumber: String? = nil
    ) {
        self.merchantName = merchantName
        self.merchantConfidence = merchantConfidence
        self.purchaseDate = purchaseDate
        self.dateConfidence = dateConfidence
        self.totalAmount = totalAmount
        self.totalConfidence = totalConfidence
        self.gstAmount = gstAmount
        self.gstConfidence = gstConfidence
        self.receiptNumber = receiptNumber
    }
}

/// Deterministic field extraction from OCR text lines (spec 6.3, 6.5 field
/// table). Intentionally simple and explainable rather than "AI-powered":
/// the product's own positioning explicitly avoids claiming AI
/// sophistication here (spec 22.1), and every field stays user-editable on
/// the Review screen regardless of confidence (spec 6.3: "Never
/// automatically save a financial value from OCR without presenting it on
/// the Review screen").
///
/// Scoring logic ported and edge-case-matched from a Python prototype (see
/// CLAUDE.md section 4) since this dev environment has no Swift toolchain -
/// re-verify with `swift test` before trusting new keyword additions.
public enum ReceiptFieldScorer {
    private struct AmountCandidate {
        let amount: Decimal
        let score: Int
        let lineIndex: Int
    }

    private static let amountPattern = #"\$?\s?(\d{1,3}(?:,\d{3})*\.\d{2}|\d+\.\d{2})"#

    private static let boostKeywords: [(pattern: String, delta: Int)] = [
        ("grand\\s*total", 100),
        ("total\\s*due", 90),
        ("amount\\s*due", 90),
        ("balance\\s*due", 85),
        ("\\btotal\\b", 80),
    ]

    /// `exclude: true` removes the line from contention entirely (e.g.
    /// subtotal should never be mistaken for the total); other penalties
    /// just lower the score so a real total elsewhere can still win.
    private static let penaltyKeywords: [(pattern: String, delta: Int, exclude: Bool)] = [
        ("sub\\s*-?\\s*total", -1000, true),
        ("\\bchange\\b", -60, false),
        ("\\btender(ed)?\\b", -60, false),
        ("\\bcash\\b", -40, false),
        ("\\beftpos\\b", -40, false),
        ("\\bvisa\\b|\\bmastercard\\b|\\bcard\\b", -40, false),
    ]

    public static func parse(lines: [String]) -> ParsedReceiptFields {
        var result = ParsedReceiptFields()

        if let merchant = extractMerchant(lines: lines) {
            result.merchantName = merchant
            result.merchantConfidence = .medium
        }

        if let total = pickTotal(lines: lines) {
            result.totalAmount = total
            result.totalConfidence = .medium
        }

        if let gst = pickGST(lines: lines) {
            result.gstAmount = gst
            result.gstConfidence = .medium
        }

        if let receiptNumber = extractReceiptNumber(lines: lines) {
            result.receiptNumber = receiptNumber
        }

        for line in lines {
            if let date = ReceiptDateParser.parse(line.trimmingCharacters(in: .whitespaces)) {
                result.purchaseDate = date
                result.dateConfidence = .medium
                break
            }
            if let date = firstDateSubstring(in: line) {
                result.purchaseDate = date
                result.dateConfidence = .low
                break
            }
        }

        return result
    }

    /// First non-empty line that doesn't look like an address/ABN/phone
    /// header is treated as the merchant name candidate (spec field table:
    /// "score top text lines; ignore address/ABN/phone/common headers").
    private static func extractMerchant(lines: [String]) -> String? {
        let noisePatterns = [
            "\\bABN\\b", "\\d{2}\\s?\\d{3}\\s?\\d{3}\\s?\\d{3}", // ABN number
            "\\bTAX INVOICE\\b", "\\bRECEIPT\\b",
            "\\bPh:?\\s*\\d", "\\bPhone\\b",
            "^\\d+\\s+\\w+\\s+(St|Street|Rd|Road|Ave|Avenue)\\b",
        ]
        for line in lines.prefix(5) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let isNoise = noisePatterns.contains { pattern in
                trimmed.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
            }
            if !isNoise {
                return trimmed
            }
        }
        return nil
    }

    private static func extractReceiptNumber(lines: [String]) -> String? {
        let pattern = #"(?:RECEIPT|INVOICE|ORDER|TRANSACTION)\s*#?\s*:?\s*([A-Za-z0-9\-]{3,})"#
        for line in lines {
            if let match = firstCaptureGroup(in: line, pattern: pattern, caseInsensitive: true) {
                return match
            }
        }
        return nil
    }

    private static func pickTotal(lines: [String]) -> Decimal? {
        let candidates = scoreAmountCandidates(lines: lines)
        guard let maxScore = candidates.map(\.score).max() else { return nil }
        let top = candidates.filter { $0.score == maxScore }
        // Tie-break: larger amount, then the later line (closer to the
        // bottom of the receipt, where the real total usually sits).
        let best = top.max { a, b in
            (a.amount, a.lineIndex) < (b.amount, b.lineIndex)
        }
        return best?.amount
    }

    private static func pickGST(lines: [String]) -> Decimal? {
        for line in lines {
            let lower = line.lowercased()
            guard lower.range(of: "\\bgst\\b", options: .regularExpression) != nil else { continue }
            guard !lower.contains("included") else { continue }
            if let amount = firstAmount(in: line) {
                return amount
            }
        }
        return nil
    }

    private static func scoreAmountCandidates(lines: [String]) -> [AmountCandidate] {
        var candidates: [AmountCandidate] = []
        for (index, line) in lines.enumerated() {
            guard let amount = firstAmount(in: line) else { continue }
            var score = 5 // baseline: any bare amount is a weak candidate
            var excluded = false
            for (pattern, delta, exclude) in penaltyKeywords {
                if line.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                    if exclude { excluded = true }
                    score += delta
                }
            }
            if excluded { continue }
            for (pattern, delta) in boostKeywords {
                if line.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                    score += delta
                }
            }
            candidates.append(AmountCandidate(amount: amount, score: score, lineIndex: index))
        }
        return candidates
    }

    private static func firstAmount(in line: String) -> Decimal? {
        guard let raw = firstCaptureGroup(in: line, pattern: amountPattern, caseInsensitive: false) else { return nil }
        return Money.parse(raw)
    }

    private static func firstDateSubstring(in line: String) -> DateOnly? {
        let pattern = #"\d{1,4}[./-]\d{1,2}[./-]\d{1,4}"#
        guard let raw = firstMatch(in: line, pattern: pattern) else { return nil }
        return ReceiptDateParser.parse(raw)
    }

    private static func firstCaptureGroup(in s: String, pattern: String, caseInsensitive: Bool) -> String? {
        let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        let range = NSRange(s.startIndex..<s.endIndex, in: s)
        guard let result = regex.firstMatch(in: s, range: range), result.numberOfRanges > 1,
              let r = Range(result.range(at: 1), in: s) else { return nil }
        return String(s[r])
    }

    private static func firstMatch(in s: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(s.startIndex..<s.endIndex, in: s)
        guard let result = regex.firstMatch(in: s, range: range), let r = Range(result.range, in: s) else { return nil }
        return String(s[r])
    }
}
