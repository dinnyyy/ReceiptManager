import Foundation

/// Privacy-minimised product events (spec 15, 15.1). Every case only carries
/// the properties the spec's event table explicitly allows - there is no
/// generic `[String: Any]` payload anywhere in this type, specifically so a
/// call site *cannot* accidentally attach receipt contents, merchant names,
/// amounts, or notes to an analytics event even by mistake.
public enum AnalyticsEvent: Sendable {
    case accountCreated(authMethod: String, appVersion: String)
    case captureStarted(source: CaptureSource)
    case captureCompleted(durationMs: Int, pageCount: Int, ocrSuccess: Bool)
    case purchaseSaved(purposeCount: Int, hasItem: Bool, hasWarranty: Bool, syncState: String)
    case searchUsed(queryLength: Int, filterCount: Int, resultCount: Int)
    case exportCreated(type: String, recordCount: Int, durationMs: Int)
    case warrantyReminderSet(daysBeforeExpiry: Int)
    case paywallViewed(trigger: String, planContext: String)
    case subscriptionStarted(productID: String, offerType: String)
    case syncFailed(operation: String, genericErrorCode: String)

    public enum CaptureSource: String, Sendable {
        case camera, photo, pdf, manual
    }
}

/// Fire-and-forget by design: analytics must never block or fail user
/// actions, so this has no throwing/async surface for the call site to
/// react to.
public protocol AnalyticsService {
    func track(_ event: AnalyticsEvent)
}

/// Default no-op implementation, used until a real privacy-minimised
/// analytics backend is chosen (spec section 20: not to be invented
/// silently by the developer). Swapping this out never touches call sites.
public final class NoOpAnalyticsService: AnalyticsService {
    public init() {}
    public func track(_ event: AnalyticsEvent) {}
}
