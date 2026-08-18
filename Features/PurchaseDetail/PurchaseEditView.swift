import SwiftUI
import ReceiptVaultCore

/// Spec 5.8: "Edit maintains original attachment and updates structured
/// fields." No OCR re-run here - this is a plain edit form for a record
/// that already exists, unlike Review which is building one from scratch.
struct PurchaseEditView: View {
    let purchaseID: UUID
    let onSaved: () -> Void

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var merchantName = ""
    @State private var purchaseDate = Date()
    @State private var totalAmountText = ""
    @State private var gstAmountText = ""
    @State private var receiptNumber = ""
    @State private var category = ""
    @State private var notes = ""
    @State private var selectedPurposes: Set<PurchasePurpose> = []
    @State private var original: Purchase?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    LabeledContent("Merchant") { TextField("", text: $merchantName).multilineTextAlignment(.trailing) }
                    DatePicker("Date", selection: $purchaseDate, displayedComponents: .date)
                    LabeledContent("Total") { TextField("", text: $totalAmountText).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    LabeledContent("GST") { TextField("", text: $gstAmountText).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    LabeledContent("Receipt no.") { TextField("Optional", text: $receiptNumber).multilineTextAlignment(.trailing) }
                }
                Section("Why are you keeping this?") {
                    PurposeChipGrid(selected: $selectedPurposes)
                }
                Section("Category") {
                    TextField("Optional", text: $category)
                }
                Section("Notes") {
                    TextEditor(text: $notes).frame(minHeight: 80)
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red).font(.footnote) }
                }
            }
            .navigationTitle("Edit purchase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
            .task { load() }
        }
    }

    private func load() {
        guard let purchase = try? environment.purchaseRepository.fetch(id: purchaseID) else { return }
        original = purchase
        merchantName = purchase.merchantName ?? ""
        if let date = purchase.purchaseDate, let foundationDate = Calendar(identifier: .gregorian).date(from: DateComponents(year: date.year, month: date.month, day: date.day)) {
            purchaseDate = foundationDate
        }
        totalAmountText = purchase.totalAmount.map { "\($0)" } ?? ""
        gstAmountText = purchase.gstAmount.map { "\($0)" } ?? ""
        receiptNumber = purchase.receiptNumber ?? ""
        category = purchase.category ?? ""
        notes = purchase.notes ?? ""
        selectedPurposes = purchase.purposes
    }

    private func save() {
        guard var purchase = original else { return }
        let comps = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: purchaseDate)
        purchase.merchantName = merchantName.isEmpty ? nil : merchantName
        purchase.purchaseDate = comps.year.flatMap { y in comps.month.flatMap { m in comps.day.flatMap { d in DateOnly(year: y, month: m, day: d) } } }
        purchase.totalAmount = Money.parse(totalAmountText)
        purchase.gstAmount = Money.parse(gstAmountText)
        purchase.receiptNumber = receiptNumber.isEmpty ? nil : receiptNumber
        purchase.category = category.isEmpty ? nil : category
        purchase.notes = notes.isEmpty ? nil : notes
        purchase.purposes = selectedPurposes.isEmpty ? [.other] : selectedPurposes
        purchase.syncState = purchase.syncState == .localOnly ? .localOnly : .pendingUpload
        purchase.updatedAt = Date()

        do {
            try environment.purchaseRepository.saveDraft(purchase)
            environment.syncEngine?.drainOutbox()
            onSaved()
            dismiss()
        } catch {
            errorMessage = "Couldn't save your changes. Please try again."
        }
    }
}

#Preview {
    PurchaseEditView(purchaseID: UUID(), onSaved: {})
        .environment(AppEnvironment.preview())
}
