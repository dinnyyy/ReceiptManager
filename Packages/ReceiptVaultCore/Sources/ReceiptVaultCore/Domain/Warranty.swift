import Foundation

/// A separate table/type from `Item` (not columns on it) so a future
/// extended/replacement warranty can be recorded without losing the
/// original one (spec 7.1 entity notes).
public struct Warranty: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let workspaceID: UUID
    public let itemID: UUID
    public var provider: String?
    public var startDate: DateOnly?
    public var expiryDate: DateOnly?
    public var details: String?
    public var reminderEnabled: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        workspaceID: UUID,
        itemID: UUID,
        provider: String? = nil,
        startDate: DateOnly? = nil,
        expiryDate: DateOnly? = nil,
        details: String? = nil,
        reminderEnabled: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.workspaceID = workspaceID
        self.itemID = itemID
        self.provider = provider
        self.startDate = startDate
        self.expiryDate = expiryDate
        self.details = details
        self.reminderEnabled = reminderEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Spec 5.11: "Warranty status derived from expiry date and current
    /// date." "Expiring soon" matches the reminder window (spec 13: 30
    /// days before expiry is the first reminder), so the in-app badge and
    /// the notification schedule agree with each other.
    public func status(asOf today: DateOnly = .today(), expiringSoonWindowDays: Int = 30) -> WarrantyStatus {
        guard let expiry = expiryDate else { return .none }
        let daysUntilExpiry = today.days(until: expiry)
        if daysUntilExpiry < 0 { return .expired }
        if daysUntilExpiry <= expiringSoonWindowDays { return .expiringSoon }
        return .active
    }
}

/// Spec 13: "Default MVP proposal: 30 days before and 7 days before,
/// user-configurable later." Kept here (not in the Notifications layer) so
/// the reminder schedule and the "expiring soon" badge share one source of
/// truth and can't silently drift apart.
public enum WarrantyReminderSchedule {
    public static let defaultDaysBeforeExpiry = [30, 7]

    /// Returns only the reminder dates that are still in the future
    /// relative to `today` - already-past reminder points are never
    /// scheduled (spec 13: reschedule on expiry-date change; this also
    /// covers "warranty added after one of the reminder points already
    /// passed").
    public static func reminderDates(
        expiryDate: DateOnly, daysBefore: [Int] = defaultDaysBeforeExpiry, today: DateOnly = .today()
    ) -> [DateOnly] {
        daysBefore.compactMap { offset -> DateOnly? in
            let totalDays = expiryDate.daysSince1970() - offset
            guard let date = DateOnly.fromDaysSince1970(totalDays) else { return nil }
            return date >= today ? date : nil
        }
    }
}
