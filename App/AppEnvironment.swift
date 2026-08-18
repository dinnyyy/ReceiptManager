import Foundation
import SwiftData
import Observation
import ReceiptVaultCore

/// The app's single dependency container. Screens read services from this
/// via `@Environment(AppEnvironment.self)` rather than each owning its own
/// singleton - keeps every service swappable for previews/tests (spec 9.3:
/// "service/repository boundaries... without unnecessary enterprise
/// architecture").
@Observable
@MainActor
final class AppEnvironment {
    let modelContainer: ModelContainer

    let authService: AuthService
    let purchaseRepository: PurchaseRepository
    let itemRepository: ItemRepository
    let attachmentService: AttachmentService
    let ocrService: OCRService
    let fieldParser: ReceiptFieldParsing
    let subscriptionService: SubscriptionService
    let notificationScheduler: NotificationScheduler
    let analyticsService: AnalyticsService

    /// V1 has exactly one personal workspace per account (spec 7.1); this
    /// is populated right after `create_initial_workspace` succeeds during
    /// sign-in and read by every screen that needs to scope a query.
    var currentWorkspaceID: UUID?

    init(
        modelContainer: ModelContainer,
        authService: AuthService,
        purchaseRepository: PurchaseRepository,
        itemRepository: ItemRepository,
        attachmentService: AttachmentService,
        ocrService: OCRService,
        fieldParser: ReceiptFieldParsing,
        subscriptionService: SubscriptionService,
        notificationScheduler: NotificationScheduler,
        analyticsService: AnalyticsService
    ) {
        self.modelContainer = modelContainer
        self.authService = authService
        self.purchaseRepository = purchaseRepository
        self.itemRepository = itemRepository
        self.attachmentService = attachmentService
        self.ocrService = ocrService
        self.fieldParser = fieldParser
        self.subscriptionService = subscriptionService
        self.notificationScheduler = notificationScheduler
        self.analyticsService = analyticsService
    }

    static func live() -> AppEnvironment {
        let container = PersistenceSchema.makeContainer()
        let context = ModelContext(container)
        let backend = SupabaseBackend.shared

        return AppEnvironment(
            modelContainer: container,
            authService: SupabaseAuthService(backend: backend),
            purchaseRepository: SwiftDataPurchaseRepository(modelContext: context),
            itemRepository: SwiftDataItemRepository(modelContext: context),
            attachmentService: SupabaseAttachmentService(backend: backend, modelContext: context),
            ocrService: VisionOCRService(),
            fieldParser: DefaultReceiptFieldParser(),
            subscriptionService: StoreKitSubscriptionService(),
            notificationScheduler: LocalNotificationScheduler(),
            analyticsService: NoOpAnalyticsService()
        )
    }

    /// In-memory container + mock services for SwiftUI previews and UI
    /// tests, so neither hits the network or requires a signed-in session.
    static func preview() -> AppEnvironment {
        let container = PersistenceSchema.makeContainer(inMemory: true)
        let context = ModelContext(container)

        return AppEnvironment(
            modelContainer: container,
            authService: PreviewAuthService(),
            purchaseRepository: SwiftDataPurchaseRepository(modelContext: context),
            itemRepository: SwiftDataItemRepository(modelContext: context),
            attachmentService: PreviewAttachmentService(),
            ocrService: PreviewOCRService(),
            fieldParser: DefaultReceiptFieldParser(),
            subscriptionService: PreviewSubscriptionService(),
            notificationScheduler: PreviewNotificationScheduler(),
            analyticsService: NoOpAnalyticsService()
        )
    }
}

/// Thin protocol wrapper around `ReceiptVaultCore.ReceiptFieldScorer` (spec
/// 9.3 names this `ReceiptFieldParser`) so OCR/Review code depends on a
/// protocol, not a concrete static enum, and can be swapped in tests.
public protocol ReceiptFieldParsing {
    func parse(ocr: OCRResult) -> ParsedReceiptFields
}

public struct DefaultReceiptFieldParser: ReceiptFieldParsing {
    public init() {}
    public func parse(ocr: OCRResult) -> ParsedReceiptFields {
        ReceiptFieldScorer.parse(lines: ocr.lines)
    }
}
