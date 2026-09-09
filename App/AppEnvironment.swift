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
    let attachmentRepository: AttachmentRepository
    let ocrService: OCRService
    let fieldParser: ReceiptFieldParsing
    let subscriptionService: SubscriptionService
    let notificationScheduler: NotificationScheduler
    let analyticsService: AnalyticsService
    let syncEngine: SyncEngine?
    let isLocalOnly: Bool

    /// V1 has exactly one personal workspace per account (spec 7.1); this
    /// is populated right after `create_initial_workspace` succeeds during
    /// sign-in and read by every screen that needs to scope a query.
    var currentWorkspaceID: UUID?

    /// Fixed workspace id used by `.localOnly()` so a relaunch of the app
    /// keeps seeing the same local data instead of minting a new empty
    /// workspace every time.
    static let localOnlyWorkspaceID = UUID(uuidString: "00000000-0000-0000-0000-0000000000BB")!

    init(
        modelContainer: ModelContainer,
        authService: AuthService,
        purchaseRepository: PurchaseRepository,
        itemRepository: ItemRepository,
        attachmentService: AttachmentService,
        attachmentRepository: AttachmentRepository,
        ocrService: OCRService,
        fieldParser: ReceiptFieldParsing,
        subscriptionService: SubscriptionService,
        notificationScheduler: NotificationScheduler,
        analyticsService: AnalyticsService,
        syncEngine: SyncEngine?,
        isLocalOnly: Bool = false
    ) {
        self.modelContainer = modelContainer
        self.authService = authService
        self.purchaseRepository = purchaseRepository
        self.itemRepository = itemRepository
        self.attachmentService = attachmentService
        self.attachmentRepository = attachmentRepository
        self.ocrService = ocrService
        self.fieldParser = fieldParser
        self.subscriptionService = subscriptionService
        self.notificationScheduler = notificationScheduler
        self.analyticsService = analyticsService
        self.syncEngine = syncEngine
        self.isLocalOnly = isLocalOnly
    }

    static func live() -> AppEnvironment {
        let container = PersistenceSchema.makeContainer()
        let context = ModelContext(container)
        let backend = SupabaseBackend.shared
        let attachmentService = SupabaseAttachmentService(backend: backend, modelContext: context)

        return AppEnvironment(
            modelContainer: container,
            authService: SupabaseAuthService(backend: backend),
            purchaseRepository: SwiftDataPurchaseRepository(modelContext: context),
            itemRepository: SwiftDataItemRepository(modelContext: context),
            attachmentService: attachmentService,
            attachmentRepository: SwiftDataAttachmentRepository(modelContext: context),
            ocrService: VisionOCRService(),
            fieldParser: DefaultReceiptFieldParser(),
            subscriptionService: StoreKitSubscriptionService(),
            notificationScheduler: LocalNotificationScheduler(),
            analyticsService: NoOpAnalyticsService(),
            syncEngine: SyncEngine(modelContext: context, backend: backend, attachmentService: attachmentService)
        )
    }

    /// Temporary: run the app entirely on-device with no Supabase project
    /// configured at all - no sign-in screen, no network calls anywhere.
    /// Capture/OCR/Review/Vault/Items/Export/Notifications all work for
    /// real against a real on-disk SwiftData store; only the parts that
    /// inherently need a backend (actually backing up to the cloud,
    /// account deletion, real StoreKit purchases) are stubbed out. Data
    /// persists across relaunches under a fixed local workspace id.
    ///
    /// Switch `ReceiptVaultApp` back to `.live()` once
    /// `Config/Secrets.xcconfig` is filled in with a real Supabase project
    /// - see `Config/Secrets.xcconfig.template` and `SETUP.md`.
    static func localOnly() -> AppEnvironment {
        let container = PersistenceSchema.makeContainer()
        let context = ModelContext(container)

        let environment = AppEnvironment(
            modelContainer: container,
            authService: LocalOnlyAuthService(),
            purchaseRepository: SwiftDataPurchaseRepository(modelContext: context),
            itemRepository: SwiftDataItemRepository(modelContext: context),
            attachmentService: LocalOnlyAttachmentService(),
            attachmentRepository: SwiftDataAttachmentRepository(modelContext: context),
            ocrService: VisionOCRService(),
            fieldParser: DefaultReceiptFieldParser(),
            subscriptionService: PreviewSubscriptionService(),
            notificationScheduler: LocalNotificationScheduler(),
            analyticsService: NoOpAnalyticsService(),
            syncEngine: nil,
            isLocalOnly: true
        )
        environment.currentWorkspaceID = Self.localOnlyWorkspaceID
        LocalOnlyDemoData.seedIfNeeded(
            purchaseRepository: environment.purchaseRepository,
            itemRepository: environment.itemRepository,
            workspaceID: Self.localOnlyWorkspaceID
        )
        return environment
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
            attachmentRepository: SwiftDataAttachmentRepository(modelContext: context),
            ocrService: PreviewOCRService(),
            fieldParser: DefaultReceiptFieldParser(),
            subscriptionService: PreviewSubscriptionService(),
            notificationScheduler: PreviewNotificationScheduler(),
            analyticsService: NoOpAnalyticsService(),
            syncEngine: nil
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
