import Foundation

/// Parses the assortment of date formats found on real Australian receipts
/// (spec 17.1: "dd/MM/yyyy, dd-MM-yy, yyyy-MM-dd and common receipt
/// variants"). Logic ported and edge-case-matched from a Python prototype
/// (see CLAUDE.md section 4) since this dev environment has no Swift
/// toolchain to run `ReceiptDateParserTests` directly - re-verify with
/// `swift test` before trusting new format additions.
public enum ReceiptDateParser {
    private static let monthNames: [String: Int] = [
        "jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6,
        "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12,
    ]

    /// Tries each supported format in priority order and returns the first
    /// one that produces a real calendar date. Returns nil rather than
    /// guessing when the string doesn't match anything recognized -
    /// callers (the Review screen) leave the field blank and flagged for
    /// the user rather than silently trusting a bad guess (spec 6.3).
    public static func parse(_ raw: String) -> DateOnly? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }

        if let date = parseISO(s) { return date }
        if let date = parseDayMonthName(s) { return date }
        if let date = parseMonthNameDay(s) { return date }
        if let date = parseNumericDayFirst(s) { return date }
        return nil
    }

    /// yyyy-MM-dd or yyyy/MM/dd.
    private static func parseISO(_ s: String) -> DateOnly? {
        guard let match = firstMatch(in: s, pattern: #"^(\d{4})[-/](\d{1,2})[-/](\d{1,2})$"#) else { return nil }
        guard let y = Int(match[1]), let m = Int(match[2]), let d = Int(match[3]) else { return nil }
        return DateOnly(year: y, month: m, day: d)
    }

    /// "13 Aug 2026", "13-Aug-2026", "13/Aug/2026".
    private static func parseDayMonthName(_ s: String) -> DateOnly? {
        guard let match = firstMatch(
            in: s, pattern: #"^(\d{1,2})[\s\-/]+([A-Za-z]{3,9})[\s\-/,]+(\d{2,4})$"#
        ) else { return nil }
        guard let d = Int(match[1]), let month = monthNames[String(match[2].prefix(3)).lowercased()],
              let y = Int(match[3]) else { return nil }
        return DateOnly(year: normalizeYear(y), month: month, day: d)
    }

    /// "Aug 13, 2026", "August 13 2026".
    private static func parseMonthNameDay(_ s: String) -> DateOnly? {
        guard let match = firstMatch(
            in: s, pattern: #"^([A-Za-z]{3,9})[\s\-]+(\d{1,2}),?\s+(\d{2,4})$"#
        ) else { return nil }
        guard let month = monthNames[String(match[1].prefix(3)).lowercased()],
              let d = Int(match[2]), let y = Int(match[3]) else { return nil }
        return DateOnly(year: normalizeYear(y), month: month, day: d)
    }

    /// dd/MM/yyyy, dd-MM-yyyy, dd.MM.yyyy, dd/MM/yy - Australian day-first
    /// convention, with a defensive swap if the first component can't
    /// possibly be a day (e.g. a stray US-formatted digital receipt).
    private static func parseNumericDayFirst(_ s: String) -> DateOnly? {
        guard let match = firstMatch(in: s, pattern: #"^(\d{1,2})[./-](\d{1,2})[./-](\d{2,4})$"#) else { return nil }
        guard let a = Int(match[1]), let b = Int(match[2]), let y = Int(match[3]) else { return nil }
        let year = normalizeYear(y)

        if a <= 31, b <= 12, let date = DateOnly(year: year, month: b, day: a) {
            return date
        }
        if b <= 31, a <= 12, let date = DateOnly(year: year, month: a, day: b) {
            return date
        }
        return nil
    }

    private static func normalizeYear(_ y: Int) -> Int {
        y < 100 ? y + 2000 : y
    }

    /// Returns the whole-match plus capture groups, or nil if the pattern
    /// doesn't match the entire string.
    private static func firstMatch(in s: String, pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(s.startIndex..<s.endIndex, in: s)
        guard let result = regex.firstMatch(in: s, range: range) else { return nil }
        var groups: [String] = []
        for i in 0..<result.numberOfRanges {
            guard let r = Range(result.range(at: i), in: s) else { return nil }
            groups.append(String(s[r]))
        }
        return groups
    }
}
