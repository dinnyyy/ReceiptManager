import Foundation
import UIKit
import Observation
import ReceiptVaultCore

/// Spec 5.7: "The critical screen: confirm the minimum useful fields and
/// save quickly." Owns the whole capture -> OCR -> field extraction ->
/// user-editable state pipeline for one draft; `ReviewView` only renders
/// what's here.
@MainActor
@Observable
final class ReviewViewModel {
    let draft: CaptureDraft
    private let environment: AppEnvironment
    private let captureStartedAt = Date()

    var isProcessingOCR = true
    var merchantName = ""
    var merchantConfidence: FieldConfidence = .none
    var purchaseDate: Date?
    var dateConfidence: FieldConfidence = .none
    var totalAmountText = ""
    var totalConfidence: FieldConfidence = .none
    var gstAmountText = ""
    var gstConfidence: FieldConfidence = .none
    var receiptNumber = ""
    var category = ""
    var selectedPurposes: Set<PurchasePurpose> = []
    var notes = ""
    var isNotesExpanded = false
    var rawOCRText = ""
    var thumbnailImage: UIImage?
    var duplicateWarningMessage: String?
    var isSaving = false
    var saveErrorMessage: String?
    var savedPurchaseID: UUID?
    var offerAddItemDetails = false

    init(draft: CaptureDraft, environment: AppEnvironment) {
        self.draft = draft
        self.environment = environment
        if let firstImageURL = draft.fileURLs.first(where: { $0.pathExtension.lowercased() != "pdf" }),
           let data = try? Data(contentsOf: firstImageURL) {
            thumbnailImage = UIImage(data: data)
        }
    }

    func start() async {
        guard !draft.fileURLs.isEmpty else {
            // Manual entry: nothing to OCR (spec 5.4: "Manual -> purchase
            // editor without document").
            isProcessingOCR = false
            return
        }
        do {
            let ocrResult = try await environment.ocrService.recognizeText(imageFileURLs: draft.fileURLs)
            rawOCRText = ocrResult.rawText
            applyParsedFields(environment.fieldParser.parse(ocr: ocrResult))
            await checkForDuplicate()
        } catch {
            // Spec 5.6 acceptance: "OCR failure is non-fatal." Fields just
            // stay blank; the scanned evidence is still fully preserved.
        }
        isProcessingOCR = false
        let durationMs = Int(Date().timeIntervalSince(captureStartedAt) * 1000)
        environment.analyticsService.track(.captureCompleted(durationMs: durationMs, pageCount: draft.fileURLs.count, ocrSuccess: !rawOCRText.isEmpty))
    }

    private func applyParsedFields(_ parsed: ParsedReceiptFields) {
        if let merchant = parsed.merchantName {
            merchantName = merchant
            merchantConfidence = parsed.merchantConfidence
        }
        if let date = parsed.purchaseDate {
            purchaseDate = date.asFoundationDate
            dateConfidence = parsed.dateConfidence
        }
        if let total = parsed.totalAmount {
            totalAmountText = "\(total)"
            totalConfidence = parsed.totalConfidence
        }
        if let gst = parsed.gstAmount {
            gstAmountText = "\(gst)"
            gstConfidence = parsed.gstConfidence
        }
        receiptNumber = parsed.receiptNumber ?? ""
    }

    private func checkForDuplicate() async {
        // Spec 6.4 (P1): warn, never block. Only meaningful once we have at
        // least a merchant or a total to compare against.
        guard let workspaceID = environment.currentWorkspaceID, !merchantName.isEmpty || !totalAmountText.isEmpty else { return }
        let candidate = DuplicateCandidateFields(
            merchantName: merchantName.isEmpty ? nil : merchantName,
            purchaseDate: purchaseDate?.asDateOnly,
            totalAmount: Money.parse(totalAmountText),
            receiptNumber: receiptNumber.isEmpty ? nil : receiptNumber
        )
        guard let existing = try? environment.purchaseRepository.search(PurchaseSearchQuery(), workspaceID: workspaceID) else { return }
        let candidates = existing.map { (id: $0.id, fields: DuplicateCandidateFields(
            merchantName: $0.merchantName, purchaseDate: $0.purchaseDate, totalAmount: $0.totalAmount, receiptNumber: $0.receiptNumber
        )) }
        if let match = DuplicateDetector.closestMatch(for: candidate, among: candidates) {
            let matchedPurchase = existing.first { $0.id == match.id }
            let label = matchedPurchase?.merchantName ?? "a previous purchase"
            duplicateWarningMessage = "This may already be saved, as \(label)."
        }
    }

    var canSave: Bool {
        !merchantName.isEmpty || purchaseDate != nil || !totalAmountText.isEmpty || !selectedPurposes.isEmpty || !draft.fileURLs.isEmpty
    }

    func save() async {
        guard let workspaceID = environment.currentWorkspaceID else {
            saveErrorMessage = "No workspace yet - please sign in again."
            return
        }
        isSaving = true
        defer { isSaving = false }

        var purposes = selectedPurposes
        if purposes.isEmpty {
            purposes = [.other]
        }

        var purchase = Purchase(
            id: draft.id,
            workspaceID: workspaceID,
            status: .saved,
            merchantName: merchantName.isEmpty ? nil : merchantName,
            purchaseDate: purchaseDate?.asDateOnly,
            totalAmount: Money.parse(totalAmountText),
            gstAmount: Money.parse(gstAmountText),
            receiptNumber: receiptNumber.isEmpty ? nil : receiptNumber,
            category: category.isEmpty ? nil : category,
            purposes: purposes,
            notes: notes.isEmpty ? nil : notes,
            rawOCRText: rawOCRText.isEmpty ? nil : rawOCRText,
            syncState: .localOnly
        )

        do {
            try environment.purchaseRepository.saveDraft(purchase)
            try await stageAndSaveAttachments(purchaseID: purchase.id, workspaceID: workspaceID)
            purchase.syncState = .pendingUpload
            try environment.purchaseRepository.saveDraft(purchase)

            environment.analyticsService.track(.purchaseSaved(
                purposeCount: purposes.count, hasItem: false, hasWarranty: false, syncState: purchase.syncState.rawValue
            ))
            environment.syncEngine?.drainOutbox()

            offerAddItemDetails = purposes.contains(.warranty) || purposes.contains(.asset)
            savedPurchaseID = purchase.id
        } catch {
            saveErrorMessage = "Couldn't save this purchase. Your scanned evidence is safe on this iPhone - please try again."
        }
    }

    private func stageAndSaveAttachments(purchaseID: UUID, workspaceID: UUID) async throws {
        for fileURL in draft.fileURLs {
            let type: AttachmentType = fileURL.pathExtension.lowercased() == "pdf" ? .invoicePdf : .receiptImage
            let mimeType = fileURL.pathExtension.lowercased() == "pdf" ? "application/pdf" : "image/jpeg"
            let local = LocalAttachment(fileURL: fileURL, type: type, mimeType: mimeType, originalFilename: fileURL.lastPathComponent)
            let staged = try environment.attachmentService.stage(local, workspaceID: workspaceID, purchaseID: purchaseID, itemID: nil)
            let attachment = Attachment(
                id: staged.id, workspaceID: workspaceID, purchaseID: purchaseID, type: type,
                storagePath: staged.storagePath, originalFilename: local.originalFilename, mimeType: staged.mimeType,
                bytes: staged.bytes, sha256: staged.sha256, syncState: .pendingUpload
            )
            try environment.attachmentRepository.save(attachment, localFilePath: staged.localFileURL.path)
        }
    }
}

private extension Date {
    var asDateOnly: DateOnly? {
        let comps = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: self)
        guard let y = comps.year, let m = comps.month, let d = comps.day else { return nil }
        return DateOnly(year: y, month: m, day: d)
    }
}

private extension DateOnly {
    var asFoundationDate: Date? {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        return Calendar(identifier: .gregorian).date(from: comps)
    }
}
