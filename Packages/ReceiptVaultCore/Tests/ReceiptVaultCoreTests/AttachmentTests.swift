import XCTest
@testable import ReceiptVaultCore

final class AttachmentTests: XCTestCase {
    func testStoragePathForPurchase() {
        let workspaceID = UUID()
        let purchaseID = UUID()
        let attachmentID = UUID()
        let path = Attachment.storagePath(
            workspaceID: workspaceID, purchaseID: purchaseID, itemID: nil,
            attachmentID: attachmentID, fileExtension: "jpg"
        )
        XCTAssertEqual(path, "\(workspaceID)/purchases/\(purchaseID)/\(attachmentID).jpg")
    }

    func testStoragePathForItem() {
        let workspaceID = UUID()
        let itemID = UUID()
        let attachmentID = UUID()
        let path = Attachment.storagePath(
            workspaceID: workspaceID, purchaseID: nil, itemID: itemID,
            attachmentID: attachmentID, fileExtension: ".png"
        )
        XCTAssertEqual(path, "\(workspaceID)/items/\(itemID)/\(attachmentID).png")
    }

    func testStoragePathNilWithoutPurchaseOrItem() {
        XCTAssertNil(Attachment.storagePath(
            workspaceID: UUID(), purchaseID: nil, itemID: nil, attachmentID: UUID(), fileExtension: "jpg"
        ))
    }

    func testIsValidRequiresPurchaseOrItem() {
        let workspaceID = UUID()
        let orphan = Attachment(workspaceID: workspaceID, type: .receiptImage, storagePath: "x", mimeType: "image/jpeg")
        XCTAssertFalse(orphan.isValid)

        let linked = Attachment(
            workspaceID: workspaceID, purchaseID: UUID(), type: .receiptImage, storagePath: "x", mimeType: "image/jpeg"
        )
        XCTAssertTrue(linked.isValid)
    }
}
