import Foundation

/// Thin wrapper keeping money as `Decimal` end-to-end. Spec 5.7 and 7 are
/// explicit: **never use `Double` for stored amounts** - binary
/// floating-point cannot represent values like 0.10 exactly, which silently
/// corrupts totals after enough arithmetic.
public enum Money {
    /// Parses an OCR/user-entered amount string like "$1,234.56" or
    /// "1234.56" into a `Decimal`. Returns nil for anything that isn't a
    /// plausible monetary value.
    public static func parse(_ raw: String) -> Decimal? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacingOccurrences(of: "$", with: "")
        s = s.replacingOccurrences(of: ",", with: "")
        guard !s.isEmpty else { return nil }
        return Decimal(string: s, locale: Locale(identifier: "en_US_POSIX"))
    }

    /// Formats a `Decimal` as "$1,234.56" style currency text for the given
    /// ISO 4217 currency code (defaults to AUD per spec 7.2).
    public static func format(_ amount: Decimal, currency: String = "AUD") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.locale = Locale(identifier: "en_AU")
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(currency) \(amount)"
    }

    /// Rounds to 2 decimal places using banker's-rounding-free "round half
    /// up", matching how receipts display cents.
    public static func rounded(_ amount: Decimal) -> Decimal {
        var result = Decimal()
        var mutableAmount = amount
        NSDecimalRound(&result, &mutableAmount, 2, .plain)
        return result
    }
}
