import Foundation

/// Mirrors the `purchases.status` check constraint in
/// supabase/migrations/20260817000003_purchases.sql.
public enum PurchaseStatus: String, Codable, CaseIterable, Sendable {
    case draft
    case needsReview = "needs_review"
    case saved
    case archived
}

/// Mirrors `purchase_purposes.purpose`. A purchase can carry more than one
/// (spec 2.1, 5.7): "one purchase to serve multiple purposes without
/// duplicate copies" is the core product thesis.
public enum PurchasePurpose: String, Codable, CaseIterable, Sendable {
    case tax
    case warranty
    case insurance
    case asset
    case reimbursement
    case donation
    case personal
    case other

    public var displayName: String {
        switch self {
        case .tax: return "Tax"
        case .warranty: return "Warranty"
        case .insurance: return "Insurance"
        case .asset: return "Asset"
        case .reimbursement: return "Reimbursement"
        case .donation: return "Donation"
        case .personal: return "Personal"
        case .other: return "Other"
        }
    }
}

/// Mirrors `attachments.type`.
public enum AttachmentType: String, Codable, CaseIterable, Sendable {
    case receiptImage = "receipt_image"
    case invoicePdf = "invoice_pdf"
    case itemPhoto = "item_photo"
    case serialLabel = "serial_label"
    case warrantyDocument = "warranty_document"
    case valuation
    case manual
    case other
}

/// Mirrors `workspaces.type`. V1 only ever creates `.personal` workspaces
/// (spec 7.1): team workspaces are schema-ready but hidden from the UI.
public enum WorkspaceType: String, Codable, CaseIterable, Sendable {
    case personal
    case business
}

/// Local-only: never persisted to Postgres. Tracks where a record is in the
/// local-first sync pipeline (spec 9.4) so the UI can always show whether a
/// capture is safely backed up.
public enum SyncState: String, Codable, CaseIterable, Sendable {
    case localOnly
    case pendingUpload
    case syncing
    case synced
    case failed
}

/// Mirrors `subscription_state.plan`.
public enum SubscriptionPlan: String, Codable, CaseIterable, Sendable {
    case free
    case soloProMonthly = "solo_pro_monthly"
    case soloProAnnual = "solo_pro_annual"

    public var isPaid: Bool { self != .free }
}

/// Derived, not stored: computed from a warranty's expiry date against
/// "today" (spec 5.11: "warranty status derived from expiry date and
/// current date").
public enum WarrantyStatus: String, Sendable {
    case none
    case active
    case expiringSoon
    case expired
}
