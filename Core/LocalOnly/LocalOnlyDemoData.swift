import Foundation
import ReceiptVaultCore

/// Populates `.localOnly()` mode with a realistic spread of purchases and
/// items the first time the app launches with an empty local store, so
/// clicking through Vault/Items/Home shows a lived-in vault instead of an
/// empty state. Only ever seeds once - checked via purchase count for the
/// fixed local workspace - so it never fights with anything the user
/// captures themselves afterward. Never runs against `.live()`; a real
/// Supabase-backed account starts empty as normal.
enum LocalOnlyDemoData {
    @MainActor
    static func seedIfNeeded(purchaseRepository: PurchaseRepository, itemRepository: ItemRepository, workspaceID: UUID) {
        guard let existing = try? purchaseRepository.count(workspaceID: workspaceID, status: nil), existing == 0 else { return }

        for purchase in makePurchases(workspaceID: workspaceID) {
            try? purchaseRepository.saveDraft(purchase)
        }
        for item in makeItems(workspaceID: workspaceID) {
            try? itemRepository.save(item)
        }
    }

    private static func d(_ year: Int, _ month: Int, _ day: Int) -> DateOnly {
        DateOnly(year: year, month: month, day: day)!
    }

    private static func foundationDate(_ date: DateOnly) -> Date {
        var comps = DateComponents()
        comps.year = date.year; comps.month = date.month; comps.day = date.day; comps.hour = 10
        return Calendar(identifier: .gregorian).date(from: comps) ?? Date()
    }

    // Fixed ids for the purchases that a seeded Item links back to as its
    // proof (spec 5.9/5.11), so an item's purchaseIDs can point at an exact
    // purchase rather than guessing by merchant name - several merchants
    // below (Bunnings, Camera House, Officeworks...) appear more than once.
    private static let sydneyToolsImpactDriverID = UUID()
    private static let sydneyToolsGeneratorID = UUID()
    private static let milwaukeeRotaryHammerID = UUID()
    private static let cameraHouseR6ID = UUID()
    private static let djiMavicID = UUID()
    private static let rodeWirelessGoID = UUID()
    private static let appleMacBookProID = UUID()
    private static let jbHiFiMonitorID = UUID()
    private static let samsungLaptopID = UUID()
    private static let harveyNormanIPadID = UUID()

    // MARK: - Purchases

    private struct PurchaseSeed {
        var id: UUID = UUID()
        let merchant: String
        let date: DateOnly
        let total: Decimal
        let gst: Decimal?
        let category: String
        let purposes: Set<PurchasePurpose>
        let receiptNumber: String?
        let notes: String?
        let status: PurchaseStatus
    }

    private static func makePurchases(workspaceID: UUID) -> [Purchase] {
        let seeds: [PurchaseSeed] = [
            // Tools & equipment (tradie) - tax + asset + warranty
            .init(merchant: "Total Tools Marrickville", date: d(2025, 8, 4), total: 1249.00, gst: 113.55, category: "Tools & Equipment", purposes: [.tax, .asset, .warranty], receiptNumber: "TT-88213", notes: nil, status: .saved),
            .init(merchant: "Bunnings Warehouse", date: d(2025, 8, 4), total: 187.40, gst: 17.04, category: "Materials", purposes: [.tax], receiptNumber: "BW-556201", notes: nil, status: .saved),
            .init(id: sydneyToolsImpactDriverID, merchant: "Sydney Tools", date: d(2025, 9, 18), total: 649.00, gst: 59.00, category: "Tools & Equipment", purposes: [.tax, .asset, .warranty], receiptNumber: "ST-40312", notes: "Impact driver combo kit", status: .saved),
            .init(merchant: "Kennards Hire", date: d(2025, 10, 2), total: 214.50, gst: 19.50, category: "Equipment Hire", purposes: [.tax], receiptNumber: "KH-77410", notes: "2-day scissor lift hire", status: .saved),
            .init(merchant: "Repco", date: d(2025, 10, 22), total: 340.75, gst: 30.98, category: "Vehicle", purposes: [.tax], receiptNumber: nil, notes: "Ute service + brake pads", status: .needsReview),
            .init(merchant: "Bunnings Warehouse", date: d(2025, 11, 3), total: 92.15, gst: 8.38, category: "Materials", purposes: [.tax], receiptNumber: "BW-561944", notes: nil, status: .saved),
            .init(merchant: "Total Tools Marrickville", date: d(2025, 12, 12), total: 89.00, gst: 8.09, category: "Tools & Equipment", purposes: [.tax], receiptNumber: "TT-90177", notes: nil, status: .saved),
            .init(merchant: "Bunnings Warehouse", date: d(2026, 1, 9), total: 458.20, gst: 41.65, category: "Materials", purposes: [.tax], receiptNumber: "BW-570002", notes: "Deck timber + fixings", status: .saved),
            .init(id: sydneyToolsGeneratorID, merchant: "Sydney Tools", date: d(2026, 2, 14), total: 3199.00, gst: 290.82, category: "Tools & Equipment", purposes: [.tax, .asset, .warranty, .insurance], receiptNumber: "ST-41890", notes: "Generator for job sites without power", status: .saved),

            // Photography / creative studio - tax + asset + warranty + insurance
            .init(id: cameraHouseR6ID, merchant: "Camera House", date: d(2025, 7, 28), total: 4599.00, gst: 418.09, category: "Camera Equipment", purposes: [.tax, .asset, .warranty, .insurance], receiptNumber: "CH-22319", notes: "EOS R6 Mark II body", status: .saved),
            .init(id: djiMavicID, merchant: "DJI Store Australia", date: d(2025, 9, 3), total: 2899.00, gst: 263.55, category: "Camera Equipment", purposes: [.tax, .asset, .warranty, .insurance], receiptNumber: "DJI-100482", notes: "Mavic 3 Pro", status: .saved),
            .init(id: rodeWirelessGoID, merchant: "Rode Microphones", date: d(2025, 11, 19), total: 429.00, gst: 39.00, category: "Camera Equipment", purposes: [.tax, .asset, .warranty], receiptNumber: "RD-88291", notes: "Wireless GO II", status: .saved),
            .init(merchant: "Camera House", date: d(2026, 3, 6), total: 189.00, gst: 17.18, category: "Camera Equipment", purposes: [.tax], receiptNumber: "CH-23004", notes: "Spare batteries + SD cards", status: .saved),
            .init(merchant: "Adobe", date: d(2025, 7, 15), total: 89.99, gst: 8.18, category: "Software", purposes: [.tax], receiptNumber: "ADB-INV-33812", notes: "Creative Cloud - monthly", status: .saved),
            .init(merchant: "Adobe", date: d(2025, 8, 15), total: 89.99, gst: 8.18, category: "Software", purposes: [.tax], receiptNumber: "ADB-INV-34910", notes: "Creative Cloud - monthly", status: .saved),
            .init(merchant: "Adobe", date: d(2025, 9, 15), total: 89.99, gst: 8.18, category: "Software", purposes: [.tax], receiptNumber: "ADB-INV-36002", notes: "Creative Cloud - monthly", status: .saved),

            // IT contractor - tax + asset + warranty
            .init(id: appleMacBookProID, merchant: "Apple Store George St", date: d(2025, 8, 21), total: 3799.00, gst: 345.36, category: "Computer Equipment", purposes: [.tax, .asset, .warranty], receiptNumber: "AP-561029", notes: "MacBook Pro 14\" M4", status: .saved),
            .init(id: jbHiFiMonitorID, merchant: "JB Hi-Fi", date: d(2025, 9, 30), total: 649.00, gst: 59.00, category: "Computer Equipment", purposes: [.tax, .asset, .warranty], receiptNumber: "JB-771029", notes: "Dell UltraSharp monitor", status: .saved),
            .init(merchant: "Officeworks", date: d(2025, 10, 11), total: 64.95, gst: 5.91, category: "Office Supplies", purposes: [.tax], receiptNumber: "OW-991823", notes: nil, status: .saved),
            .init(merchant: "GoDaddy", date: d(2025, 11, 1), total: 24.99, gst: 2.27, category: "Software", purposes: [.tax], receiptNumber: "GD-4021998", notes: "Domain renewal", status: .saved),
            .init(merchant: "Microsoft 365", date: d(2025, 12, 5), total: 16.20, gst: 1.47, category: "Software", purposes: [.tax], receiptNumber: nil, notes: nil, status: .needsReview),
            .init(merchant: "Telstra Business", date: d(2026, 1, 15), total: 99.00, gst: 9.00, category: "Utilities", purposes: [.tax], receiptNumber: "TB-3390182", notes: "Mobile + business NBN", status: .saved),
            .init(id: samsungLaptopID, merchant: "Samsung Store", date: d(2026, 4, 2), total: 1499.00, gst: 136.27, category: "Computer Equipment", purposes: [.tax, .asset], receiptNumber: "SS-88213", notes: "Backup laptop for client site work", status: .saved),

            // Consumables / small purchases spread across the year
            .init(merchant: "Officeworks", date: d(2026, 2, 3), total: 38.50, gst: 3.50, category: "Office Supplies", purposes: [.tax], receiptNumber: "OW-004471", notes: nil, status: .saved),
            .init(merchant: "Australia Post", date: d(2026, 2, 20), total: 27.85, gst: 2.53, category: "Postage", purposes: [.tax], receiptNumber: nil, notes: "Client gear shipped for repair", status: .saved),
            .init(merchant: "Bunnings Warehouse", date: d(2026, 3, 15), total: 76.30, gst: 6.94, category: "Materials", purposes: [.tax], receiptNumber: "BW-582211", notes: nil, status: .saved),
            .init(merchant: "Canva", date: d(2026, 4, 10), total: 16.99, gst: 1.55, category: "Software", purposes: [.tax], receiptNumber: "CNV-77281", notes: "Pro - monthly", status: .saved),
            .init(merchant: "BP Service Station", date: d(2026, 5, 6), total: 112.40, gst: 10.22, category: "Fuel", purposes: [.tax], receiptNumber: nil, notes: nil, status: .saved),
            .init(id: milwaukeeRotaryHammerID, merchant: "Milwaukee Tool Centre", date: d(2026, 5, 28), total: 899.00, gst: 81.73, category: "Tools & Equipment", purposes: [.tax, .asset, .warranty], receiptNumber: "MW-51029", notes: "M18 rotary hammer", status: .saved),
            .init(merchant: "Officeworks", date: d(2026, 6, 12), total: 145.00, gst: 13.18, category: "Office Supplies", purposes: [.tax], receiptNumber: "OW-009982", notes: "New client invoice pads + folders", status: .saved),

            // Reimbursement / donation / personal - variety of purposes
            .init(merchant: "Bunnings Warehouse", date: d(2026, 6, 30), total: 214.60, gst: 19.51, category: "Materials", purposes: [.tax, .reimbursement], receiptNumber: "BW-591203", notes: "Materials for the Chatswood job - client reimburses", status: .saved),
            .init(merchant: "Salvos Stores", date: d(2026, 7, 5), total: 50.00, gst: nil, category: "Donation", purposes: [.donation], receiptNumber: "SV-2201", notes: nil, status: .saved),
            .init(merchant: "Mecca Coffee", date: d(2026, 7, 9), total: 5.80, gst: nil, category: "Personal", purposes: [.personal], receiptNumber: nil, notes: nil, status: .saved),
            .init(merchant: "Dan Murphy's", date: d(2026, 7, 18), total: 68.00, gst: nil, category: "Personal", purposes: [.personal], receiptNumber: nil, notes: nil, status: .saved),

            // Recent - this financial year, includes a couple still needing review
            .init(merchant: "Total Tools Marrickville", date: d(2026, 8, 2), total: 129.00, gst: 11.73, category: "Tools & Equipment", purposes: [.tax], receiptNumber: "TT-93310", notes: nil, status: .saved),
            .init(merchant: "Squarespace", date: d(2026, 8, 5), total: 32.00, gst: 2.91, category: "Software", purposes: [.tax], receiptNumber: nil, notes: nil, status: .needsReview),
            .init(merchant: "Bunnings Warehouse", date: d(2026, 8, 20), total: 61.75, gst: 5.61, category: "Materials", purposes: [.tax], receiptNumber: "BW-598812", notes: nil, status: .saved),
            .init(merchant: "Camera House", date: d(2026, 9, 1), total: 79.00, gst: 7.18, category: "Camera Equipment", purposes: [.tax], receiptNumber: "CH-23611", notes: "Lens cleaning kit", status: .saved),
            .init(id: harveyNormanIPadID, merchant: "Harvey Norman", date: d(2026, 9, 6), total: 1799.00, gst: 163.55, category: "Computer Equipment", purposes: [.tax, .asset, .warranty], receiptNumber: nil, notes: "iPad Pro for on-site quotes and sign-off", status: .needsReview),
        ]

        return seeds.map { seed in
            let created = foundationDate(seed.date)
            return Purchase(
                id: seed.id,
                workspaceID: workspaceID,
                status: seed.status,
                merchantName: seed.merchant,
                purchaseDate: seed.date,
                totalAmount: seed.total,
                gstAmount: seed.gst,
                receiptNumber: seed.receiptNumber,
                category: seed.category,
                purposes: seed.purposes,
                notes: seed.notes,
                createdAt: created,
                updatedAt: created,
                syncState: .localOnly
            )
        }
    }

    // MARK: - Items

    private struct ItemSeed {
        let name: String
        let brand: String?
        let model: String?
        let serialNumber: String?
        let originalValue: Decimal?
        let location: String?
        let notes: String?
        let linkedPurchaseID: UUID?
        let warrantyProvider: String?
        let warrantyStart: DateOnly?
        let warrantyExpiry: DateOnly?
        let reminderEnabled: Bool
    }

    private static func makeItems(workspaceID: UUID) -> [Item] {
        let seeds: [ItemSeed] = [
            .init(name: "Impact driver combo kit", brand: "DeWalt", model: "DCK281D2", serialNumber: "DW20250918441", originalValue: 649.00, location: "Work Van", notes: nil, linkedPurchaseID: sydneyToolsImpactDriverID, warrantyProvider: "DeWalt Australia", warrantyStart: d(2025, 9, 18), warrantyExpiry: d(2028, 9, 18), reminderEnabled: true),
            .init(name: "Petrol generator", brand: "Honda", model: "EU22i", serialNumber: "HN20260214092", originalValue: 3199.00, location: "Work Van", notes: "Insured under business equipment policy", linkedPurchaseID: sydneyToolsGeneratorID, warrantyProvider: "Honda Australia", warrantyStart: d(2026, 2, 14), warrantyExpiry: d(2027, 2, 14), reminderEnabled: true),
            // Expiring within 30 days of "today" - exercises Home's warranty-ending-soon card.
            .init(name: "Rotary hammer drill", brand: "Milwaukee", model: "M18 CHPX", serialNumber: "MW20260528771", originalValue: 899.00, location: "Work Van", notes: nil, linkedPurchaseID: milwaukeeRotaryHammerID, warrantyProvider: "Milwaukee Tool", warrantyStart: d(2026, 5, 28), warrantyExpiry: d(2026, 9, 28), reminderEnabled: true),
            .init(name: "EOS R6 Mark II", brand: "Canon", model: "R6 Mark II", serialNumber: "CN0384719205", originalValue: 4599.00, location: "Studio - Camera Bag A", notes: "Primary body for shoots", linkedPurchaseID: cameraHouseR6ID, warrantyProvider: "Canon Australia", warrantyStart: d(2025, 7, 28), warrantyExpiry: d(2027, 7, 28), reminderEnabled: true),
            // Also expiring soon.
            .init(name: "Mavic 3 Pro drone", brand: "DJI", model: "Mavic 3 Pro", serialNumber: "DJI9928471055", originalValue: 2899.00, location: "Studio - Case", notes: "CASA registration on file separately", linkedPurchaseID: djiMavicID, warrantyProvider: "DJI Care", warrantyStart: d(2025, 9, 3), warrantyExpiry: d(2026, 9, 29), reminderEnabled: true),
            .init(name: "Wireless GO II mic kit", brand: "Rode", model: "Wireless GO II", serialNumber: "RD20251119887", originalValue: 429.00, location: "Studio - Camera Bag B", notes: nil, linkedPurchaseID: rodeWirelessGoID, warrantyProvider: "Rode", warrantyStart: d(2025, 11, 19), warrantyExpiry: d(2027, 11, 19), reminderEnabled: false),
            .init(name: "MacBook Pro 14\" M4", brand: "Apple", model: "MacBook Pro 14 (2025)", serialNumber: "C02XG1YQ0J9F", originalValue: 3799.00, location: "Home Office", notes: "Main dev machine", linkedPurchaseID: appleMacBookProID, warrantyProvider: "AppleCare+", warrantyStart: d(2025, 8, 21), warrantyExpiry: d(2026, 8, 21), reminderEnabled: true),
            // Already expired.
            .init(name: "UltraSharp 27\" monitor", brand: "Dell", model: "U2723QE", serialNumber: "DL20250930112", originalValue: 649.00, location: "Home Office", notes: nil, linkedPurchaseID: jbHiFiMonitorID, warrantyProvider: "Dell Australia", warrantyStart: d(2025, 9, 30), warrantyExpiry: d(2026, 8, 30), reminderEnabled: false),
            .init(name: "Backup laptop", brand: "Samsung", model: "Galaxy Book4 Pro", serialNumber: "SM20260402556", originalValue: 1499.00, location: "Home Office", notes: "Loaned to client sites when needed", linkedPurchaseID: samsungLaptopID, warrantyProvider: nil, warrantyStart: nil, warrantyExpiry: nil, reminderEnabled: false),
            .init(name: "iPad Pro 11\"", brand: "Apple", model: "iPad Pro (M4)", serialNumber: "F2LXG2Q1PL0M", originalValue: 1799.00, location: "Work Van", notes: "On-site quotes and sign-off", linkedPurchaseID: harveyNormanIPadID, warrantyProvider: "AppleCare", warrantyStart: d(2026, 9, 6), warrantyExpiry: d(2027, 9, 6), reminderEnabled: true),
            // No linked purchase - added manually, exercises "No purchase proof linked" (spec 5.11).
            .init(name: "Site safety harness", brand: "3M", model: "Protecta AB113A", serialNumber: nil, originalValue: 180.00, location: "Work Van", notes: "Bought secondhand, no receipt kept", linkedPurchaseID: nil, warrantyProvider: nil, warrantyStart: nil, warrantyExpiry: nil, reminderEnabled: false),
            .init(name: "Spare tripod", brand: "Manfrotto", model: "MT055XPRO3", serialNumber: nil, originalValue: 320.00, location: "Studio - Storage", notes: nil, linkedPurchaseID: nil, warrantyProvider: nil, warrantyStart: nil, warrantyExpiry: nil, reminderEnabled: false),
        ]

        return seeds.map { seed in
            let purchaseIDs: Set<UUID> = seed.linkedPurchaseID.map { [$0] } ?? []
            guard let expiry = seed.warrantyExpiry else {
                return Item(
                    workspaceID: workspaceID, name: seed.name, brand: seed.brand, model: seed.model,
                    serialNumber: seed.serialNumber, originalValue: seed.originalValue, location: seed.location,
                    notes: seed.notes, purchaseIDs: purchaseIDs, syncState: .localOnly
                )
            }
            let itemID = UUID()
            let warranty = Warranty(
                workspaceID: workspaceID, itemID: itemID, provider: seed.warrantyProvider,
                startDate: seed.warrantyStart, expiryDate: expiry, reminderEnabled: seed.reminderEnabled
            )
            return Item(
                id: itemID, workspaceID: workspaceID, name: seed.name, brand: seed.brand, model: seed.model,
                serialNumber: seed.serialNumber, originalValue: seed.originalValue, location: seed.location,
                notes: seed.notes, purchaseIDs: purchaseIDs, warranty: warranty,
                createdAt: foundationDate(seed.warrantyStart ?? expiry), updatedAt: Date(), syncState: .localOnly
            )
        }
    }
}
