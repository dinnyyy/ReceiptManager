import SwiftUI
import ReceiptVaultCore

/// Spec 5.7. The single most important screen in the app: it's the only
/// place a captured receipt turns into a trusted, searchable record.
/// Every OCR-prefilled field stays editable regardless of confidence
/// (spec 6.3), and saving never requires more than confirming what's
/// already there.
struct ReviewView: View {
    let draft: CaptureDraft
    let onFinished: () -> Void

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ReviewViewModel?
    @State private var isExpandedPreviewPresented = false
    @State private var isAddItemPromptPresented = false

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    content(viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Review purchase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onFinished() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel?.save()
                            if viewModel?.savedPurchaseID != nil {
                                if viewModel?.offerAddItemDetails == true {
                                    isAddItemPromptPresented = true
                                } else {
                                    onFinished()
                                }
                            }
                        }
                    }
                    .disabled(viewModel.map { !$0.canSave || $0.isSaving } ?? true)
                }
            }
        }
        .task {
            if viewModel == nil {
                let vm = ReviewViewModel(draft: draft, environment: environment)
                viewModel = vm
                await vm.start()
            }
        }
        .confirmationDialog(
            "Add item details now?",
            isPresented: $isAddItemPromptPresented,
            titleVisibility: .visible
        ) {
            Button("Add item details") {
                // Item creation prefilled from this purchase (spec 5.9);
                // full flow lands with the Items feature. For now this
                // still completes Review so the purchase itself is safe.
                onFinished()
            }
            Button("Not now", role: .cancel) { onFinished() }
        } message: {
            Text("You tagged this as Warranty or Asset. Add the item's serial number, model and warranty expiry so you can find it later.")
        }
        .sheet(isPresented: Binding(
            get: { viewModel?.shouldShowPaywall ?? false },
            set: { if !$0 { viewModel?.shouldShowPaywall = false } }
        )) {
            PaywallView(trigger: .freeLimitReached)
        }
    }

    @ViewBuilder
    private func content(_ viewModel: ReviewViewModel) -> some View {
        @Bindable var viewModel = viewModel
        Form {
            if let image = viewModel.thumbnailImage {
                Section {
                    Button {
                        isExpandedPreviewPresented = true
                    } label: {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Receipt preview, tap to expand")
                }
                .listRowInsets(EdgeInsets())
                .padding(8)
            }

            if viewModel.isProcessingOCR {
                Section {
                    HStack {
                        ProgressView()
                        Text("Reading receipt…")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let warning = viewModel.duplicateWarningMessage {
                Section {
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.footnote)
                }
            }

            Section("Details") {
                ConfidenceField(label: "Merchant", text: $viewModel.merchantName, confidence: viewModel.merchantConfidence)

                HStack {
                    Text("Date")
                    Spacer()
                    DatePicker("", selection: Binding(get: { viewModel.purchaseDate ?? Date() }, set: { viewModel.purchaseDate = $0 }), displayedComponents: .date)
                        .labelsHidden()
                }
                if viewModel.dateConfidence == .low {
                    LowConfidenceHint()
                }

                ConfidenceField(label: "Total", text: $viewModel.totalAmountText, confidence: viewModel.totalConfidence, keyboard: .decimalPad, prefix: "$")
                ConfidenceField(label: "GST", text: $viewModel.gstAmountText, confidence: viewModel.gstConfidence, keyboard: .decimalPad, prefix: "$")

                HStack {
                    Text("Receipt no.")
                    Spacer()
                    TextField("Optional", text: $viewModel.receiptNumber)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Why are you keeping this?") {
                PurposeChipGrid(selected: $viewModel.selectedPurposes)
            }

            Section("Category") {
                TextField("Optional, e.g. Tools", text: $viewModel.category)
            }

            Section {
                DisclosureGroup("Notes", isExpanded: $viewModel.isNotesExpanded) {
                    TextEditor(text: $viewModel.notes)
                        .frame(minHeight: 80)
                }
            }

            if let errorMessage = viewModel.saveErrorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote)
                }
            }
        }
        .sheet(isPresented: $isExpandedPreviewPresented) {
            if let image = viewModel.thumbnailImage {
                ZoomableImageView(image: image)
            }
        }
    }
}

private struct ConfidenceField: View {
    let label: String
    @Binding var text: String
    let confidence: FieldConfidence
    var keyboard: UIKeyboardType = .default
    var prefix: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                Spacer()
                if let prefix { Text(prefix).foregroundStyle(.secondary) }
                TextField("", text: $text)
                    .keyboardType(keyboard)
                    .multilineTextAlignment(.trailing)
            }
            if confidence == .low {
                LowConfidenceHint()
            }
        }
    }
}

private struct LowConfidenceHint: View {
    var body: some View {
        // Spec 16.1: "Purpose/status must not be communicated by colour
        // alone" - text label alongside the tint, not just a colored dot.
        Label("Please check this field", systemImage: "exclamationmark.circle")
            .font(.caption)
            .foregroundStyle(.orange)
    }
}

#Preview {
    ReviewView(draft: .manual(), onFinished: {})
        .environment(AppEnvironment.preview())
}
