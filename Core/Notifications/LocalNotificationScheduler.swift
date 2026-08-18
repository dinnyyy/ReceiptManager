import Foundation
import UserNotifications
import ReceiptVaultCore

/// Spec 13. Permission is requested lazily, only when the user actually
/// turns on a reminder - never at first launch (spec 13, 16.1). Reminder
/// dates come from `WarrantyReminderSchedule` (ReceiptVaultCore) so the
/// in-app "expiring soon" badge and the notification schedule can never
/// silently drift apart.
final class LocalNotificationScheduler: NotificationScheduler {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        @unknown default:
            return false
        }
    }

    func scheduleReminders(itemID: UUID, itemName: String, expiryDate: DateOnly) async {
        await cancelReminders(itemID: itemID)

        guard await requestAuthorizationIfNeeded() else { return }

        for daysBefore in WarrantyReminderSchedule.defaultDaysBeforeExpiry {
            let reminderDates = WarrantyReminderSchedule.reminderDates(expiryDate: expiryDate, daysBefore: [daysBefore])
            guard let reminderDate = reminderDates.first, let fireDate = reminderDate.asFoundationDateComponents else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Warranty ending soon"
            // Spec 13: "avoid sensitive purchase amount on lock screen" -
            // item name and day count only, never price/merchant/notes.
            content.body = "\(itemName)'s warranty ends in \(daysBefore) day\(daysBefore == 1 ? "" : "s")."
            content.sound = .default

            var triggerDate = fireDate
            triggerDate.hour = 9 // a reasonable local morning time, not literally midnight
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
            let request = UNNotificationRequest(
                identifier: Self.identifier(itemID: itemID, daysBefore: daysBefore), content: content, trigger: trigger
            )
            try? await center.add(request)
        }
    }

    func cancelReminders(itemID: UUID) async {
        let identifiers = WarrantyReminderSchedule.defaultDaysBeforeExpiry.map { Self.identifier(itemID: itemID, daysBefore: $0) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private static func identifier(itemID: UUID, daysBefore: Int) -> String {
        "warranty-reminder-\(itemID.uuidString)-\(daysBefore)"
    }
}

private extension DateOnly {
    var asFoundationDateComponents: DateComponents? {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        return comps
    }
}
