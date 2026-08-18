import SwiftData
import Foundation
import ReceiptVaultCore

@Model
final class WarrantyEntity {
    @Attribute(.unique) var id: UUID
    var workspaceID: UUID
    var itemID: UUID
    var provider: String?
    var startDateISO: String?
    var expiryDateISO: String?
    var details: String?
    var reminderEnabled: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        workspaceID: UUID,
        itemID: UUID,
        provider: String? = nil,
        startDateISO: String? = nil,
        expiryDateISO: String? = nil,
        details: String? = nil,
        reminderEnabled: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.workspaceID = workspaceID
        self.itemID = itemID
        self.provider = provider
        self.startDateISO = startDateISO
        self.expiryDateISO = expiryDateISO
        self.details = details
        self.reminderEnabled = reminderEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension WarrantyEntity {
    var startDate: DateOnly? {
        get { startDateISO.flatMap(DateOnly.init(isoString:)) }
        set { startDateISO = newValue?.isoString }
    }

    var expiryDate: DateOnly? {
        get { expiryDateISO.flatMap(DateOnly.init(isoString:)) }
        set { expiryDateISO = newValue?.isoString }
    }

    func toDomain() -> Warranty {
        Warranty(
            id: id, workspaceID: workspaceID, itemID: itemID, provider: provider, startDate: startDate,
            expiryDate: expiryDate, details: details, reminderEnabled: reminderEnabled,
            createdAt: createdAt, updatedAt: updatedAt
        )
    }

    func update(from warranty: Warranty) {
        provider = warranty.provider
        startDate = warranty.startDate
        expiryDate = warranty.expiryDate
        details = warranty.details
        reminderEnabled = warranty.reminderEnabled
        updatedAt = warranty.updatedAt
    }

    convenience init(domain warranty: Warranty) {
        self.init(
            id: warranty.id, workspaceID: warranty.workspaceID, itemID: warranty.itemID,
            provider: warranty.provider, startDateISO: warranty.startDate?.isoString,
            expiryDateISO: warranty.expiryDate?.isoString, details: warranty.details,
            reminderEnabled: warranty.reminderEnabled, createdAt: warranty.createdAt, updatedAt: warranty.updatedAt
        )
    }
}
