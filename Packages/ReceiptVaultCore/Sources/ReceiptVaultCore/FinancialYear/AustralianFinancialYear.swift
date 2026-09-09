import Foundation

/// Derives the Australian financial year (1 July - 30 June) from a purchase
/// date, rather than storing a mutable label (spec 5.10: "Financial year
/// helper derives Australian FY from purchase_date... rather than storing a
/// mutable label"). Verified against the July/June boundary in
/// AustralianFinancialYearTests, mirroring the edge cases already exercised
/// in the Python prototype referenced in CLAUDE.md.
public struct AustralianFinancialYear: Equatable, Hashable, Sendable {
    /// The calendar year the financial year starts in, e.g. 2026 for
    /// "FY2026-27" (1 July 2026 - 30 June 2027).
    public let startYear: Int

    public init(startYear: Int) {
        self.startYear = startYear
    }

    public init(containing date: DateOnly) {
        self.startYear = date.month >= 7 ? date.year : date.year - 1
    }

    /// "FY2026-27" style label.
    public var label: String {
        String(format: "FY%d-%02d", startYear, (startYear + 1) % 100)
    }

    public var start: DateOnly { DateOnly(year: startYear, month: 7, day: 1)! }
    public var end: DateOnly { DateOnly(year: startYear + 1, month: 6, day: 30)! }

    public func contains(_ date: DateOnly) -> Bool {
        date >= start && date <= end
    }
}
