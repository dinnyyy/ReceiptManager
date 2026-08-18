import Foundation

/// A calendar date with no time-of-day or time zone component. Purchase and
/// warranty dates are date-only per spec section 7: storing them as a
/// `Date` (an instant) plus a time zone invites off-by-one-day bugs at
/// financial-year and warranty-expiry boundaries. `DateOnly` makes that
/// class of bug impossible to represent.
public struct DateOnly: Codable, Hashable, Comparable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    /// Fails if the year/month/day combination is not a real calendar date
    /// (e.g. day 30 in February, month 13).
    public init?(year: Int, month: Int, day: Int) {
        guard (1...12).contains(month) else { return nil }
        guard day >= 1, day <= DateOnly.daysInMonth(year: year, month: month) else { return nil }
        self.year = year
        self.month = month
        self.day = day
    }

    /// Parses a strict "yyyy-MM-dd" string (the wire format used for
    /// Postgres `date` columns and this package's own `isoString`).
    public init?(isoString: String) {
        let parts = isoString.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else { return nil }
        self.init(year: y, month: m, day: d)
    }

    public var isoString: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public static func < (lhs: DateOnly, rhs: DateOnly) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    /// Today's date in the given time zone (defaults to the device's
    /// current time zone), used for "is this warranty expired" checks.
    public static func today(in timeZone: TimeZone = .current) -> DateOnly {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let comps = calendar.dateComponents([.year, .month, .day], from: Date())
        return DateOnly(year: comps.year!, month: comps.month!, day: comps.day!)!
    }

    static func daysInMonth(year: Int, month: Int) -> Int {
        switch month {
        case 1, 3, 5, 7, 8, 10, 12: return 31
        case 4, 6, 9, 11: return 30
        case 2: return isLeapYear(year) ? 29 : 28
        default: return 0
        }
    }

    static func isLeapYear(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }

    /// Days between two dates using the proleptic Gregorian calendar's day
    /// count, so callers can compute "days until expiry" without pulling in
    /// `Calendar`/`TimeZone` for pure date-only arithmetic.
    public func daysSince1970() -> Int {
        // Howard Hinnant's days_from_civil algorithm.
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let mp = (month + 9) % 12
        let doy = (153 * mp + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146097 + doe - 719468
    }

    public func days(until other: DateOnly) -> Int {
        other.daysSince1970() - daysSince1970()
    }

    /// Inverse of `daysSince1970()` (Howard Hinnant's civil_from_days).
    public static func fromDaysSince1970(_ days: Int) -> DateOnly? {
        let z = days + 719468
        let era = (z >= 0 ? z : z - 146096) / 146097
        let doe = z - era * 146097
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
        let y = yoe + era * 400
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        return DateOnly(year: m <= 2 ? y + 1 : y, month: m, day: d)
    }
}
