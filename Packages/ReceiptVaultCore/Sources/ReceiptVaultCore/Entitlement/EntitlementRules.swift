import Foundation

/// Gating rules for the Free tier vs Solo Pro (spec 2.3, 11, 11.1). Kept as
/// pure functions over explicit inputs (not a singleton reading live state)
/// so paywall-trigger logic is trivially unit testable.
public enum EntitlementRules {
    /// Spec 20: the exact number is a founder decision left as a
    /// server-configurable default; 40 is the spec's own initial test
    /// assumption (section 20, "Free limit").
    public static let defaultFreeSavedPurchaseLimit = 40

    public static func canSaveNewPurchase(
        currentSavedCount: Int, plan: SubscriptionPlan, freeLimit: Int = defaultFreeSavedPurchaseLimit
    ) -> Bool {
        plan.isPaid || currentSavedCount < freeLimit
    }

    /// Spec 11.1: "Trigger when trying to exceed free purchase limit, use a
    /// Pro-only export, or use a gated item/warranty capability."
    public static func shouldShowPaywall(
        currentSavedCount: Int, plan: SubscriptionPlan, freeLimit: Int = defaultFreeSavedPurchaseLimit
    ) -> Bool {
        !canSaveNewPurchase(currentSavedCount: currentSavedCount, plan: plan, freeLimit: freeLimit)
    }

    /// Spec 11.1: Proof Packs are a paid-tier capability; free stays
    /// "no or limited Proof Packs" per the pricing table (spec, plan
    /// comparison table).
    public static func canGenerateProofPack(plan: SubscriptionPlan) -> Bool {
        plan.isPaid
    }

    /// Spec 11.1: "Allow at least a basic full-account export regardless of
    /// current subscription status" - this is data portability, not a
    /// Proof Pack, and must never be paywalled.
    public static func canExportAllData(plan: SubscriptionPlan) -> Bool {
        true
    }

    /// Spec 11.1: "Existing records remain visible after subscription
    /// expiry. Never hold historical evidence hostage or delete it because
    /// billing lapses." Always true regardless of plan; kept as a named
    /// function so call sites read as intent, not a tautology to optimize away.
    public static func canViewExistingRecords(plan: SubscriptionPlan) -> Bool {
        true
    }
}
