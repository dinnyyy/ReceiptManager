import XCTest
@testable import ReceiptVaultCore

final class WarrantyTests: XCTestCase {
    func testStatusNoneWithoutExpiryDate() {
        let warranty = Warranty(workspaceID: UUID(), itemID: UUID())
        XCTAssertEqual(warranty.status(), .none)
    }

    func testStatusActiveFarFromExpiry() {
        let today = DateOnly(year: 2026, month: 1, day: 1)!
        let warranty = Warranty(workspaceID: UUID(), itemID: UUID(), expiryDate: DateOnly(year: 2027, month: 1, day: 1)!)
        XCTAssertEqual(warranty.status(asOf: today), .active)
    }

    func testStatusExpiringSoonWithinWindow() {
        let today = DateOnly(year: 2026, month: 8, day: 1)!
        let warranty = Warranty(workspaceID: UUID(), itemID: UUID(), expiryDate: DateOnly(year: 2026, month: 8, day: 20)!)
        XCTAssertEqual(warranty.status(asOf: today), .expiringSoon) // 19 days out, within default 30-day window
    }

    func testStatusExpired() {
        let today = DateOnly(year: 2026, month: 9, day: 1)!
        let warranty = Warranty(workspaceID: UUID(), itemID: UUID(), expiryDate: DateOnly(year: 2026, month: 8, day: 1)!)
        XCTAssertEqual(warranty.status(asOf: today), .expired)
    }

    func testStatusExpiresTodayIsNotExpired() {
        let today = DateOnly(year: 2026, month: 8, day: 1)!
        let warranty = Warranty(workspaceID: UUID(), itemID: UUID(), expiryDate: today)
        XCTAssertEqual(warranty.status(asOf: today), .expiringSoon)
    }

    func testReminderScheduleDefaultOffsets() {
        let expiry = DateOnly(year: 2029, month: 8, day: 13)!
        let today = DateOnly(year: 2026, month: 8, day: 13)!
        let reminders = WarrantyReminderSchedule.reminderDates(expiryDate: expiry, today: today)
        XCTAssertEqual(reminders.count, 2)
        // 30 days before 2029-08-13 and 7 days before, in that order.
        XCTAssertEqual(reminders[0], DateOnly.fromDaysSince1970(expiry.daysSince1970() - 30))
        XCTAssertEqual(reminders[1], DateOnly.fromDaysSince1970(expiry.daysSince1970() - 7))
    }

    func testReminderScheduleDropsPastDates() {
        // Warranty expires in 10 days: the 30-day-before reminder point is
        // already in the past and must not be scheduled.
        let today = DateOnly(year: 2026, month: 8, day: 1)!
        let expiry = DateOnly.fromDaysSince1970(today.daysSince1970() + 10)!
        let reminders = WarrantyReminderSchedule.reminderDates(expiryDate: expiry, today: today)
        XCTAssertEqual(reminders.count, 1) // only the 7-day-before point remains in the future
    }
}
