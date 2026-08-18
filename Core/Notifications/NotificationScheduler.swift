import Foundation
import ReceiptVaultCore

/// Local warranty-expiry reminders (spec 13). Notification permission is
/// requested only when the user enables a reminder, never on first launch
/// (spec 13, 16.1) - the concrete implementation enforces that by only
/// calling `UNUserNotificationCenter.requestAuthorization` from
/// `scheduleReminders`, never eagerly at app launch.
public protocol NotificationScheduler {
    func requestAuthorizationIfNeeded() async -> Bool
    func scheduleReminders(itemID: UUID, itemName: String, expiryDate: DateOnly) async
    func cancelReminders(itemID: UUID) async
}
