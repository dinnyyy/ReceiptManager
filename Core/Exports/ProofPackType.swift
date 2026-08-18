import Foundation

/// Spec 5.12, 12: one shared PDF renderer with different fields per type
/// (spec 19.1: "Generic/Insurance/Warranty export can initially share one
/// PDF renderer... rather than three separate visual systems") rather than
/// three bespoke visual systems.
enum ProofPackType: String, CaseIterable, Identifiable, Equatable, Hashable {
    case tax, warranty, insurance, generic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tax: return "Tax Proof Pack"
        case .warranty: return "Warranty Pack"
        case .insurance: return "Insurance Pack"
        case .generic: return "Purchase Pack"
        }
    }

    /// Spec 12.2: Tax Pack alone also produces a CSV.
    var includesCSV: Bool { self == .tax }
}

struct ExportOptions {
    var includeSourceReceipts = true
    var includeItemPhotos = true
    var includeNotes = true
}
