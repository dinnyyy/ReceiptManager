import Foundation
import UIKit
import PhotosUI
import Observation
import ReceiptVaultCore

@MainActor
@Observable
final class PurchaseDetailViewModel {
    let purchaseID: UUID
    private let environment: AppEnvironment

    var purchase: Purchase?
    var attachments: [Attachment] = []
    var attachmentPreviewImages: [UUID: UIImage] = [:]
    var linkedItems: [Item] = []
    var isDeleteConfirmationPresented = false
    var didDelete = false
    var errorMessage: String?

    init(purchaseID: UUID, environment: AppEnvironment) {
        self.purchaseID = purchaseID
        self.environment = environment
    }

    func load() async {
        purchase = try? environment.purchaseRepository.fetch(id: purchaseID)
        attachments = (try? environment.attachmentRepository.attachments(purchaseID: purchaseID)) ?? []
        if let workspaceID = purchase?.workspaceID {
            linkedItems = ((try? environment.itemRepository.search(ItemSearchQuery(), workspaceID: workspaceID)) ?? [])
                .filter { $0.purchaseIDs.contains(purchaseID) }
        }
        await loadPreviewImages()
    }

    private func loadPreviewImages() async {
        for attachment in attachments where attachment.mimeType.hasPrefix("image/") {
            guard let url = try? await environment.attachmentService.fetchDisplayURL(storagePath: attachment.storagePath),
                  let data = try? Data(contentsOf: url), let image = UIImage(data: data) else { continue }
            attachmentPreviewImages[attachment.id] = image
        }
    }

    func delete() async {
        do {
            try environment.purchaseRepository.delete(id: purchaseID)
            environment.syncEngine?.drainOutbox()
            didDelete = true
        } catch {
            errorMessage = "Couldn't delete this purchase. Please try again."
        }
    }

    func addAttachment(from item: PhotosPickerItem) async {
        guard let purchase, let data = try? await item.loadTransferable(type: Data.self) else { return }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("jpg")
        do {
            try data.write(to: tempURL)
            let local = LocalAttachment(fileURL: tempURL, type: .receiptImage, mimeType: "image/jpeg", originalFilename: nil)
            let staged = try environment.attachmentService.stage(local, workspaceID: purchase.workspaceID, purchaseID: purchaseID, itemID: nil)
            let attachment = Attachment(
                id: staged.id, workspaceID: purchase.workspaceID, purchaseID: purchaseID, type: .receiptImage,
                storagePath: staged.storagePath, mimeType: staged.mimeType, bytes: staged.bytes,
                sha256: staged.sha256, syncState: .pendingUpload
            )
            try environment.attachmentRepository.save(attachment, localFilePath: staged.localFileURL.path)
            environment.syncEngine?.drainOutbox()
            await load()
        } catch {
            errorMessage = "Couldn't add that attachment. Please try again."
        }
    }

    func retrySync() {
        guard var purchase else { return }
        purchase.syncState = .pendingUpload
        try? environment.purchaseRepository.saveDraft(purchase)
        self.purchase = purchase
        environment.syncEngine?.drainOutbox()
    }
}
