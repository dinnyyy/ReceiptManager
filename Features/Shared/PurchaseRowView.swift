import SwiftUI
import ReceiptVaultCore

/// Spec 5.10: "List row: merchant, date, total, purpose icons/chips,
/// attachment thumbnail." Shared between Home's recent list and the Vault
/// tab so the two never visually drift apart.
struct PurchaseRowView: View {
    let purchase: Purchase

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(purchase.merchantName ?? "Unknown merchant")
                    .font(.body)
                    .foregroundStyle(purchase.merchantName == nil ? .secondary : .primary)
                HStack(spacing: 6) {
                    if let date = purchase.purchaseDate {
                        Text(DateFormatting.shortAU(date))
                    }
                    ForEach(Array(purchase.purposes).sorted(by: { $0.rawValue < $1.rawValue }).prefix(3), id: \.self) { purpose in
                        Text(purpose.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Capsule())
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let total = purchase.totalAmount {
                    Text(Money.format(total, currency: purchase.currency))
                        .font(.body.monospacedDigit())
                } else {
                    Text("--")
                        .foregroundStyle(.secondary)
                }
                SyncStateBadge(state: purchase.syncState)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

enum DateFormatting {
    static func shortAU(_ date: DateOnly) -> String {
        String(format: "%02d/%02d/%04d", date.day, date.month, date.year)
    }
}

#Preview {
    List {
        PurchaseRowView(purchase: Purchase(
            workspaceID: UUID(), status: .saved, merchantName: "Bunnings Warehouse",
            purchaseDate: DateOnly(year: 2026, month: 8, day: 13), totalAmount: 249.00,
            purposes: [.tax, .warranty], syncState: .synced
        ))
        PurchaseRowView(purchase: Purchase(workspaceID: UUID(), status: .needsReview, syncState: .failed))
    }
}
