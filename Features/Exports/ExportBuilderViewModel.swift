import Foundation
import UIKit
import Observation
import ReceiptVaultCore

@MainActor
@Observable
final class ExportBuilderViewModel {
    private let environment: AppEnvironment
    private let preselectedPurchaseIDs: Set<UUID>
    private let preselectedItemIDs: Set<UUID>

    var packType: ProofPackType = .tax
    var options = ExportOptions()
    var isGenerating = false
    var generatedFileURLs: [URL] = []
    var errorMessage: String?
    var recordCountSummary = ""

    init(environment: AppEnvironment, preselectedPurchaseIDs: Set<UUID>, preselectedItemIDs: Set<UUID>) {
        self.environment = environment
        self.preselectedPurchaseIDs = preselectedPurchaseIDs
        self.preselectedItemIDs = preselectedItemIDs
        // A Warranty/Insurance Pack is naturally item-first; default the
        // type sensibly if the caller only gave us items.
        if preselectedItemIDs.isEmpty == false && preselectedPurchaseIDs.isEmpty {
            packType = .warranty
        }
        updateSummary()
    }

    func updateSummary() {
        recordCountSummary = "\(preselectedPurchaseIDs.count) purchase(s), \(preselectedItemIDs.count) item(s)"
    }

    var canGenerate: Bool {
        EntitlementRules.canGenerateProofPack(plan: environment.subscriptionService.entitlement.plan)
    }

    func generate() async {
        guard canGenerate else {
            environment.analyticsService.track(.paywallViewed(trigger: "proOnlyExport", planContext: environment.subscriptionService.entitlement.plan.rawValue))
            return
        }
        guard let workspaceID = environment.currentWorkspaceID else { return }
        isGenerating = true
        defer { isGenerating = false }
        let startedAt = Date()

        let purchases = preselectedPurchaseIDs.compactMap { try? environment.purchaseRepository.fetch(id: $0) }
        var items = preselectedItemIDs.compactMap { try? environment.itemRepository.fetch(id: $0) }
        // Warranty/Insurance packs built from a purchase selection should
        // also pull in any items already linked to those purchases.
        if packType == .warranty || packType == .insurance {
            for purchase in purchases {
                let linked = (try? environment.itemRepository.search(ItemSearchQuery(), workspaceID: workspaceID))?
                    .filter { $0.purchaseIDs.contains(purchase.id) } ?? []
                for item in linked where !items.contains(where: { $0.id == item.id }) {
                    items.append(item)
                }
            }
        }

        var attachmentsByPurchase: [UUID: [Attachment]] = [:]
        var attachmentsByItem: [UUID: [Attachment]] = [:]
        var images: [UUID: UIImage] = [:]

        for purchase in purchases {
            let attachments = (try? environment.attachmentRepository.attachments(purchaseID: purchase.id)) ?? []
            attachmentsByPurchase[purchase.id] = attachments
            await loadImages(attachments, into: &images)
        }
        for item in items {
            let attachments = (try? environment.attachmentRepository.attachments(itemID: item.id)) ?? []
            attachmentsByItem[item.id] = attachments
            await loadImages(attachments, into: &images)
        }

        let records = ExportRecordSet(
            workspaceName: "My Workspace", purchases: purchases, items: items,
            attachmentsByPurchase: attachmentsByPurchase, attachmentsByItem: attachmentsByItem, images: images
        )

        let pdfData = ProofPackPDFRenderer.render(type: packType, records: records, options: options)
        var urls: [URL] = []
        if let pdfURL = ExportFileWriter.writePDF(pdfData, packType: packType) {
            urls.append(pdfURL)
        }

        if packType.includesCSV {
            let rows = purchases.map { purchase in
                TaxCSVRow(
                    purchaseID: purchase.id.uuidString, purchaseDate: purchase.purchaseDate,
                    merchant: purchase.merchantName, totalAmount: purchase.totalAmount, gstAmount: purchase.gstAmount,
                    currency: purchase.currency, receiptNumber: purchase.receiptNumber, category: purchase.category,
                    purposes: Array(purchase.purposes), folder: nil, tags: [],
                    itemNames: items.filter { $0.purchaseIDs.contains(purchase.id) }.map(\.name),
                    notes: options.includeNotes ? purchase.notes : nil
                )
            }
            let csv = TaxCSVBuilder.build(rows: rows)
            if let csvURL = ExportFileWriter.writeCSV(csv, packType: packType) {
                urls.append(csvURL)
            }
        }

        generatedFileURLs = urls
        let durationMs = Int(Date().timeIntervalSince(startedAt) * 1000)
        environment.analyticsService.track(.exportCreated(type: packType.rawValue, recordCount: purchases.count, durationMs: durationMs))
    }

    private func loadImages(_ attachments: [Attachment], into images: inout [UUID: UIImage]) async {
        for attachment in attachments where attachment.mimeType.hasPrefix("image/") {
            guard images[attachment.id] == nil,
                  let url = try? await environment.attachmentService.fetchDisplayURL(storagePath: attachment.storagePath),
                  let data = try? Data(contentsOf: url), let image = UIImage(data: data) else { continue }
            images[attachment.id] = image
        }
    }
}
