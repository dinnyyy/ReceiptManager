import Foundation
import ReceiptVaultCore

/// Persists an already-staged attachment (see `AttachmentService.stage`)
/// into SwiftData and links it to its parent purchase/item, then enqueues
/// the upload. Kept separate from `AttachmentService` because that
/// protocol is filesystem+network only and has no SwiftData/ModelContext
/// dependency - this is the seam between the two.
@MainActor
public protocol AttachmentRepository {
    func save(_ attachment: Attachment, localFilePath: String?) throws
    func delete(id: UUID) throws
    func attachments(purchaseID: UUID) throws -> [Attachment]
    func attachments(itemID: UUID) throws -> [Attachment]
}
