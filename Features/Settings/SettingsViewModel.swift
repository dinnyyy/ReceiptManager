import Foundation
import UserNotifications
import Observation
import ReceiptVaultCore

@MainActor
@Observable
final class SettingsViewModel {
    private let environment: AppEnvironment

    var email: String?
    var savedPurchaseCount = 0
    var itemCount = 0
    var notificationStatus: UNAuthorizationStatus = .notDetermined
    var isDeletingAccount = false
    var deleteErrorMessage: String?
    var didDeleteAccount = false
    var didSignOut = false
    var exportAllFileURLs: [URL] = []

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func load() async {
        email = environment.authService.currentSession?.email
        if let workspaceID = environment.currentWorkspaceID {
            savedPurchaseCount = (try? environment.purchaseRepository.count(workspaceID: workspaceID, status: .saved)) ?? 0
            itemCount = (try? environment.itemRepository.search(ItemSearchQuery(), workspaceID: workspaceID).count) ?? 0
        }
        notificationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func signOut() async {
        await environment.authService.signOut()
        didSignOut = true
    }

    /// Spec 5.14: "User can export their own records even if no longer
    /// subscribed" - this is data portability, not a Proof Pack, so it is
    /// never entitlement-gated (EntitlementRules.canExportAllData is
    /// unconditionally true).
    func exportAllData() {
        guard let workspaceID = environment.currentWorkspaceID else { return }
        let purchases = (try? environment.purchaseRepository.search(PurchaseSearchQuery(), workspaceID: workspaceID)) ?? []
        let items = (try? environment.itemRepository.search(ItemSearchQuery(), workspaceID: workspaceID)) ?? []

        let purchaseRows = purchases.map { purchase in
            TaxCSVRow(
                purchaseID: purchase.id.uuidString, purchaseDate: purchase.purchaseDate, merchant: purchase.merchantName,
                totalAmount: purchase.totalAmount, gstAmount: purchase.gstAmount, currency: purchase.currency,
                receiptNumber: purchase.receiptNumber, category: purchase.category, purposes: Array(purchase.purposes),
                folder: nil, tags: [], itemNames: items.filter { $0.purchaseIDs.contains(purchase.id) }.map(\.name),
                notes: purchase.notes
            )
        }
        var urls: [URL] = []
        if let url = writeCSV(TaxCSVBuilder.build(rows: purchaseRows), name: "purchases") {
            urls.append(url)
        }

        let itemHeader = "item_id,name,brand,model,serial_number,original_value,location,notes"
        let itemLines = [itemHeader] + items.map { item in
            CSV.row([
                item.id.uuidString, item.name, item.brand, item.model, item.serialNumber,
                item.originalValue.map { "\($0)" }, item.location, item.notes,
            ])
        }
        if let url = writeCSV(itemLines.joined(separator: "\r\n"), name: "items") {
            urls.append(url)
        }

        exportAllFileURLs = urls
        environment.analyticsService.track(.exportCreated(type: "full_account_export", recordCount: purchases.count + items.count, durationMs: 0))
    }

    private func writeCSV(_ csv: String, name: String) -> URL? {
        guard let data = csv.data(using: .utf8) else { return nil }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Exports", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let url = directory.appendingPathComponent("\(name).csv")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    func deleteAccount() async {
        isDeletingAccount = true
        deleteErrorMessage = nil
        defer { isDeletingAccount = false }
        do {
            try await environment.authService.deleteAccount()
            didDeleteAccount = true
        } catch {
            deleteErrorMessage = "Couldn't delete your account right now. Please try again or contact support."
        }
    }
}
