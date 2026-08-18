import SwiftUI
import ReceiptVaultCore

/// Spec 5.7, 5.13: multi-select purpose chips, shared by Review and the
/// Purchase edit form so both stay visually identical.
struct PurposeChipGrid: View {
    @Binding var selected: Set<PurchasePurpose>

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(PurchasePurpose.allCases, id: \.self) { purpose in
                let isSelected = selected.contains(purpose)
                Button {
                    if isSelected { selected.remove(purpose) } else { selected.insert(purpose) }
                } label: {
                    Text(purpose.displayName)
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().strokeBorder(isSelected ? Color.clear : Color(.separator), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(.vertical, 4)
    }
}
