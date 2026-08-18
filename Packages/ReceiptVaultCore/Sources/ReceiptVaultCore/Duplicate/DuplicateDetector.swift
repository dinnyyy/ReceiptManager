import Foundation

/// A lightweight snapshot of the fields duplicate-detection compares. Kept
/// separate from `Purchase` so the scorer can be unit tested without a full
/// domain model and so it's easy to feed in a `fileHashMatches` signal
/// computed elsewhere (e.g. perceptual/file hash comparison against
/// existing attachments), without this package needing an image library.
public struct DuplicateCandidateFields: Sendable {
    public let merchantName: String?
    public let purchaseDate: DateOnly?
    public let totalAmount: Decimal?
    public let receiptNumber: String?
    public let fileHashMatches: Bool

    public init(
        merchantName: String?, purchaseDate: DateOnly?, totalAmount: Decimal?,
        receiptNumber: String?, fileHashMatches: Bool = false
    ) {
        self.merchantName = merchantName
        self.purchaseDate = purchaseDate
        self.totalAmount = totalAmount
        self.receiptNumber = receiptNumber
        self.fileHashMatches = fileHashMatches
    }
}

/// P1 feature (spec 6.4, 19.1: can slip to a post-launch release without
/// blocking the MVP, but ships now since the algorithm is cheap and
/// self-contained). Never blocks saving - only warns "this may already be
/// saved" above a threshold.
public enum DuplicateDetector {
    public static let warnThreshold = 60

    public static func score(_ a: DuplicateCandidateFields, against b: DuplicateCandidateFields) -> Int {
        var score = 0

        if let am = a.merchantName, let bm = b.merchantName, normalize(am) == normalize(bm) {
            score += 30
        }
        if let ad = a.purchaseDate, let bd = b.purchaseDate, ad == bd {
            score += 30
        }
        if let at = a.totalAmount, let bt = b.totalAmount, abs(at - bt) < Decimal(string: "0.01")! {
            score += 25
        }
        if let arn = a.receiptNumber, let brn = b.receiptNumber, !arn.isEmpty, arn == brn {
            score += 15
        }
        if a.fileHashMatches {
            score += 50
        }
        return score
    }

    public static func isLikelyDuplicate(_ a: DuplicateCandidateFields, against b: DuplicateCandidateFields) -> Bool {
        score(a, against: b) >= warnThreshold
    }

    /// Given a new capture and the existing candidates it could match
    /// against, returns the closest match if any crosses the warn
    /// threshold (spec 6.4: "show the closest record").
    public static func closestMatch<ID>(
        for candidate: DuplicateCandidateFields,
        among existing: [(id: ID, fields: DuplicateCandidateFields)]
    ) -> (id: ID, score: Int)? {
        let scored = existing.map { (id: $0.id, score: score(candidate, against: $0.fields)) }
        guard let best = scored.max(by: { $0.score < $1.score }), best.score >= warnThreshold else {
            return nil
        }
        return best
    }

    /// Strips everything except letters/digits, preserving order, so
    /// "Bunnings Warehouse" and "BUNNINGS   WAREHOUSE!" compare equal.
    private static func normalize(_ name: String) -> String {
        String(name.lowercased().filter { $0.isLetter || $0.isNumber })
    }
}
