import Foundation
import UIKit
import Observation
import ReceiptVaultCore

@MainActor
@Observable
final class ItemDetailViewModel {
    let itemID: UUID
    private let environment: AppEnvironment

    var item: Item?
    var linkedPurchases: [Purchase] = []
    var photos: [UIImage] = []
    var isDeleteConfirmationPresented = false
    var didDelete = false

    init(itemID: UUID, environment: AppEnvironment) {
        self.itemID = itemID
        self.environment = environment
    }

    func load() async {
        item = try? environment.itemRepository.fetch(id: itemID)
        guard let item else { return }
        linkedPurchases = item.purchaseIDs.compactMap { try? environment.purchaseRepository.fetch(id: $0) }
        await loadPhotos()
    }

    private func loadPhotos() async {
        guard let attachments = try? environment.attachmentRepository.attachments(itemID: itemID) else { return }
        var loaded: [UIImage] = []
        for attachment in attachments where attachment.mimeType.hasPrefix("image/") {
            guard let url = try? await environment.attachmentService.fetchDisplayURL(storagePath: attachment.storagePath),
                  let data = try? Data(contentsOf: url), let image = UIImage(data: data) else { continue }
            loaded.append(image)
        }
        photos = loaded
    }

    func delete() async {
        try? environment.itemRepository.delete(id: itemID)
        await environment.notificationScheduler.cancelReminders(itemID: itemID)
        environment.syncEngine?.drainOutbox()
        didDelete = true
    }
}
