import Foundation
import ReceiptVaultCore

// Mock services backing SwiftUI previews and `AppEnvironment.preview()`.
// Never wired into `.live()` - kept in their own file so it's obvious at a
// glance which services are real.

@MainActor
final class PreviewAuthService: AuthService {
    var currentSession: AuthSession? = AuthSession(userID: UUID(), email: "preview@example.com")
    func restoreSession() async -> AuthSession? { currentSession }
    func signInWithApple() async throws -> AuthSession { currentSession! }
    func requestEmailOTP(email: String) async throws {}
    func verifyEmailOTP(email: String, code: String) async throws -> AuthSession { currentSession! }
    func signOut() async { currentSession = nil }
}

final class PreviewAttachmentService: AttachmentService {
    func stage(_ file: LocalAttachment, workspaceID: UUID, purchaseID: UUID?, itemID: UUID?) throws -> StagedAttachment {
        StagedAttachment(id: UUID(), localFileURL: file.fileURL, storagePath: "preview/path", mimeType: file.mimeType, bytes: 0, sha256: "")
    }
    func upload(_ attachment: StagedAttachment) async throws {}
    func fetchDisplayURL(storagePath: String) async throws -> URL { URL(fileURLWithPath: "/dev/null") }
    func delete(storagePath: String) async throws {}
}

struct PreviewOCRService: OCRService {
    func recognizeText(imageFileURLs: [URL]) async throws -> OCRResult {
        OCRResult(lines: ["PREVIEW STORE", "13/08/2026", "TOTAL $19.99"])
    }
}

@MainActor
final class PreviewSubscriptionService: SubscriptionService {
    var entitlement: EntitlementState = .free
    func loadProducts() async throws -> [SubscriptionProduct] {
        [
            SubscriptionProduct(id: "solo_pro_monthly", plan: .soloProMonthly, displayName: "Solo Pro Monthly", displayPrice: "$8.99"),
            SubscriptionProduct(id: "solo_pro_annual", plan: .soloProAnnual, displayName: "Solo Pro Annual", displayPrice: "$79.00"),
        ]
    }
    func purchase(_ product: SubscriptionProduct) async throws {
        entitlement = EntitlementState(plan: product.plan, isActive: true, expiresAt: nil)
    }
    func restorePurchases() async throws {}
}

struct PreviewNotificationScheduler: NotificationScheduler {
    func requestAuthorizationIfNeeded() async -> Bool { true }
    func scheduleReminders(itemID: UUID, itemName: String, expiryDate: DateOnly) async {}
    func cancelReminders(itemID: UUID) async {}
}
