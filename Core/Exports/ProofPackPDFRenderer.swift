import UIKit
import ReceiptVaultCore

/// Everything the renderer needs, pre-loaded (spec 5.12: "generate export
/// locally from synced/cached data"; images are fetched - local cache
/// first, signed URL fallback - by `ExportBuilderViewModel` before calling
/// into here, so rendering itself never awaits the network).
struct ExportRecordSet {
    let workspaceName: String
    let purchases: [Purchase]
    let items: [Item]
    let attachmentsByPurchase: [UUID: [Attachment]]
    let attachmentsByItem: [UUID: [Attachment]]
    let images: [UUID: UIImage] // attachment id -> loaded image
}

enum ProofPackPDFRenderer {
    // Spec 12.1: exact disclaimer text.
    static let disclaimer = "This export organises purchase evidence. It does not determine deductibility, GST treatment or tax liability."

    static func render(type: ProofPackType, records: ExportRecordSet, options: ExportOptions, generatedAt: Date = Date()) -> Data {
        let subtitle = "\(records.workspaceName) - Generated \(Self.timestamp(generatedAt))"
        let composer = PDFPageComposer(title: type.title, subtitle: subtitle)
        return composer.render { c in
            switch type {
            case .tax: renderTax(c, records, options)
            case .warranty: renderWarranty(c, records, options)
            case .insurance: renderInsurance(c, records, options)
            case .generic: renderGeneric(c, records, options)
            }
            c.addSpacing(16)
            c.drawBody(disclaimer, color: .darkGray)
        }
    }

    private static func renderTax(_ c: PDFPageComposer, _ records: ExportRecordSet, _ options: ExportOptions) {
        c.drawSectionTitle("Summary")
        let widths: [CGFloat] = [60, 130, 60, 50, 70, 90, 60]
        c.drawTableRow(["Date", "Merchant", "Total", "GST", "Category", "Purpose", "Notes"], widths: widths, bold: true)
        for purchase in records.purchases {
            c.drawTableRow([
                purchase.purchaseDate.map(DateFormatting.shortAU) ?? "-",
                purchase.merchantName ?? "-",
                purchase.totalAmount.map { Money.format($0, currency: purchase.currency) } ?? "-",
                purchase.gstAmount.map { Money.format($0, currency: purchase.currency) } ?? "-",
                purchase.category ?? "-",
                purchase.purposes.map(\.displayName).joined(separator: ", "),
                options.includeNotes ? (purchase.notes ?? "") : "",
            ], widths: widths)
        }

        c.addSpacing(16)
        for purchase in records.purchases {
            c.drawSectionTitle(purchase.merchantName ?? "Unknown merchant")
            drawPurchaseFields(c, purchase, options)
            if options.includeSourceReceipts {
                drawAttachments(c, records.attachmentsByPurchase[purchase.id] ?? [], records: records)
            }
            c.addSpacing(12)
        }
    }

    private static func renderWarranty(_ c: PDFPageComposer, _ records: ExportRecordSet, _ options: ExportOptions) {
        for item in records.items {
            c.drawSectionTitle(item.name)
            if let brand = item.brand { c.drawLabelValue("Brand", brand) }
            if let model = item.model { c.drawLabelValue("Model", model) }
            if let serial = item.serialNumber { c.drawLabelValue("Serial", serial) }

            for purchaseID in item.purchaseIDs {
                if let purchase = records.purchases.first(where: { $0.id == purchaseID }) {
                    if let date = purchase.purchaseDate { c.drawLabelValue("Purchase date", DateFormatting.shortAU(date)) }
                    if let merchant = purchase.merchantName { c.drawLabelValue("Merchant", merchant) }
                    if let total = purchase.totalAmount { c.drawLabelValue("Amount", Money.format(total, currency: purchase.currency)) }
                }
            }

            if let warranty = item.warranty {
                if let provider = warranty.provider { c.drawLabelValue("Warranty provider", provider) }
                if let start = warranty.startDate { c.drawLabelValue("Warranty start", DateFormatting.shortAU(start)) }
                if let expiry = warranty.expiryDate { c.drawLabelValue("Warranty expiry", DateFormatting.shortAU(expiry)) }
                if let details = warranty.details, !details.isEmpty { c.drawBody(details) }
            }

            if options.includeSourceReceipts {
                for purchaseID in item.purchaseIDs {
                    drawAttachments(c, records.attachmentsByPurchase[purchaseID] ?? [], records: records)
                }
            }
            if options.includeItemPhotos {
                drawAttachments(c, (records.attachmentsByItem[item.id] ?? []).filter { $0.type == .itemPhoto || $0.type == .serialLabel }, records: records)
            }
            drawAttachments(c, (records.attachmentsByItem[item.id] ?? []).filter { $0.type == .warrantyDocument }, records: records)

            c.addSpacing(12)
        }
    }

    private static func renderInsurance(_ c: PDFPageComposer, _ records: ExportRecordSet, _ options: ExportOptions) {
        for item in records.items {
            c.drawSectionTitle(item.name)
            if let brand = item.brand { c.drawLabelValue("Make", brand) }
            if let model = item.model { c.drawLabelValue("Model", model) }
            if let serial = item.serialNumber { c.drawLabelValue("Serial", serial) }
            if let location = item.location { c.drawLabelValue("Location", location) }
            if let value = item.originalValue { c.drawLabelValue("Original value", Money.format(value)) }

            for purchaseID in item.purchaseIDs {
                if let purchase = records.purchases.first(where: { $0.id == purchaseID }) {
                    if let date = purchase.purchaseDate { c.drawLabelValue("Purchase date", DateFormatting.shortAU(date)) }
                    if let merchant = purchase.merchantName { c.drawLabelValue("Merchant", merchant) }
                    if options.includeSourceReceipts {
                        drawAttachments(c, records.attachmentsByPurchase[purchaseID] ?? [], records: records)
                    }
                }
            }
            if options.includeItemPhotos {
                drawAttachments(c, (records.attachmentsByItem[item.id] ?? []).filter { $0.type == .itemPhoto }, records: records)
            }
            drawAttachments(c, (records.attachmentsByItem[item.id] ?? []).filter { $0.type == .valuation }, records: records)
            if options.includeNotes, let notes = item.notes, !notes.isEmpty {
                c.drawBody(notes)
            }
            c.addSpacing(12)
        }
    }

    private static func renderGeneric(_ c: PDFPageComposer, _ records: ExportRecordSet, _ options: ExportOptions) {
        for purchase in records.purchases {
            c.drawSectionTitle(purchase.merchantName ?? "Unknown merchant")
            drawPurchaseFields(c, purchase, options)
            if options.includeSourceReceipts {
                drawAttachments(c, records.attachmentsByPurchase[purchase.id] ?? [], records: records)
            }
            c.addSpacing(12)
        }
    }

    private static func drawPurchaseFields(_ c: PDFPageComposer, _ purchase: Purchase, _ options: ExportOptions) {
        if let date = purchase.purchaseDate { c.drawLabelValue("Date", DateFormatting.shortAU(date)) }
        if let total = purchase.totalAmount { c.drawLabelValue("Total", Money.format(total, currency: purchase.currency)) }
        if let gst = purchase.gstAmount { c.drawLabelValue("GST", Money.format(gst, currency: purchase.currency)) }
        if let receiptNumber = purchase.receiptNumber { c.drawLabelValue("Receipt no.", receiptNumber) }
        if let category = purchase.category { c.drawLabelValue("Category", category) }
        if !purchase.purposes.isEmpty { c.drawLabelValue("Purpose", purchase.purposes.map(\.displayName).joined(separator: ", ")) }
        if options.includeNotes, let notes = purchase.notes, !notes.isEmpty { c.drawBody(notes) }
    }

    private static func drawAttachments(_ c: PDFPageComposer, _ attachments: [Attachment], records: ExportRecordSet) {
        for attachment in attachments {
            let caption = attachment.originalFilename ?? attachment.type.rawValue
            if attachment.mimeType.hasPrefix("image/") {
                c.drawImage(records.images[attachment.id], caption: caption)
            } else {
                // Non-image evidence (e.g. an invoice PDF page) is listed
                // by name rather than rendered inline; spec 12.5 still
                // requires it to be identified, not silently dropped.
                c.drawBody("Attached: \(caption)", color: .darkGray)
            }
        }
    }

    private static func timestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy, h:mm a"
        formatter.locale = Locale(identifier: "en_AU")
        return formatter.string(from: date)
    }
}
