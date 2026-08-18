import SwiftUI
import PhotosUI
import ReceiptVaultCore

/// Spec 5.8: "Provide the canonical record and all evidence attached to a
/// purchase."
struct PurchaseDetailView: View {
    let purchaseID: UUID

    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: PurchaseDetailViewModel?
    @State private var isEditPresented = false
    @State private var isExportPresented = false
    @State private var expandedAttachmentID: UUID?

    var body: some View {
        Group {
            if let viewModel, let purchase = viewModel.purchase {
                detail(viewModel, purchase)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Purchase")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil {
                viewModel = PurchaseDetailViewModel(purchaseID: purchaseID, environment: environment)
            }
            await viewModel?.load()
        }
        .onChange(of: viewModel?.didDelete) { _, didDelete in
            if didDelete == true { dismiss() }
        }
    }

    @ViewBuilder
    private func detail(_ viewModel: PurchaseDetailViewModel, _ purchase: Purchase) -> some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(purchase.merchantName ?? "Unknown merchant")
                            .font(.title3.bold())
                        Spacer()
                        SyncStateBadge(state: purchase.syncState)
                    }
                    HStack {
                        if let date = purchase.purchaseDate {
                            Text(DateFormatting.shortAU(date))
                        }
                        Spacer()
                        if let total = purchase.totalAmount {
                            Text(Money.format(total, currency: purchase.currency))
                                .font(.headline.monospacedDigit())
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                if purchase.syncState == .failed {
                    Button("Backup failed - tap to retry") { viewModel.retrySync() }
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
                PurposeChipsReadOnly(purposes: purchase.purposes)
            }

            if !viewModel.attachments.isEmpty {
                Section("Evidence") {
                    ScrollView(.horizontal) {
                        HStack(spacing: 12) {
                            ForEach(viewModel.attachments) { attachment in
                                AttachmentThumbnail(
                                    attachment: attachment,
                                    image: viewModel.attachmentPreviewImages[attachment.id]
                                )
                                .onTapGesture {
                                    if viewModel.attachmentPreviewImages[attachment.id] != nil {
                                        expandedAttachmentID = attachment.id
                                    }
                                }
                                .accessibilityAddTraits(.isButton)
                                .accessibilityLabel("\(attachment.type == .invoicePdf ? "Invoice" : "Receipt photo") \(attachment.originalFilename ?? "")")
                                .accessibilityHint("Double tap to view full screen")
                            }
                        }
                    }
                }
            }

            Section("Details") {
                if let gst = purchase.gstAmount {
                    LabeledContent("GST", value: Money.format(gst, currency: purchase.currency))
                }
                if let receiptNumber = purchase.receiptNumber {
                    LabeledContent("Receipt no.", value: receiptNumber)
                }
                if let category = purchase.category {
                    LabeledContent("Category", value: category)
                }
            }

            if let notes = purchase.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                }
            }

            if !viewModel.linkedItems.isEmpty {
                Section("Linked items") {
                    ForEach(viewModel.linkedItems) { item in
                        Button {
                            router.navigate(to: .itemDetail(item.id))
                        } label: {
                            HStack {
                                Text(item.name)
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                Section {
                    Button {
                        router.navigate(to: .itemEdit(nil, prefillFromPurchase: purchase.id))
                    } label: {
                        Label("Add or link an item", systemImage: "shippingbox")
                    }
                }
            }

            Section {
                PhotosPicker(selection: Binding(
                    get: { nil },
                    set: { (item: PhotosPickerItem?) in
                        guard let item else { return }
                        Task { await viewModel.addAttachment(from: item) }
                    }
                ), matching: .images) {
                    Label("Add attachment", systemImage: "paperclip")
                }
                Button { isExportPresented = true } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                Button(role: .destructive) {
                    viewModel.isDeleteConfirmationPresented = true
                } label: {
                    Label("Delete purchase", systemImage: "trash")
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { isEditPresented = true }
            }
        }
        .sheet(isPresented: $isEditPresented) {
            PurchaseEditView(purchaseID: purchaseID) {
                Task { await viewModel.load() }
            }
        }
        .sheet(isPresented: $isExportPresented) {
            ExportBuilderView(preselectedPurchaseIDs: [purchaseID])
        }
        .sheet(isPresented: Binding(
            get: { expandedAttachmentID != nil },
            set: { if !$0 { expandedAttachmentID = nil } }
        )) {
            if let id = expandedAttachmentID, let image = viewModel.attachmentPreviewImages[id] {
                ZoomableImageView(image: image)
            }
        }
        // Spec 5.7 copy: "Delete this purchase and its attached proof?
        // This can't be undone."
        .confirmationDialog(
            "Delete this purchase and its attached proof? This can't be undone.",
            isPresented: Binding(get: { viewModel.isDeleteConfirmationPresented }, set: { viewModel.isDeleteConfirmationPresented = $0 }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { Task { await viewModel.delete() } }
            Button("Cancel", role: .cancel) {}
        }
    }
}

private struct PurposeChipsReadOnly: View {
    let purposes: Set<PurchasePurpose>

    var body: some View {
        if !purposes.isEmpty {
            HStack {
                ForEach(Array(purposes).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { purpose in
                    Text(purpose.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Capsule())
                }
            }
        }
    }
}

private struct AttachmentThumbnail: View {
    let attachment: Attachment
    let image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    Color(.tertiarySystemFill)
                    Image(systemName: attachment.type == .invoicePdf ? "doc.fill" : "photo")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 90, height: 90)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    NavigationStack {
        PurchaseDetailView(purchaseID: UUID())
    }
    .environment(AppEnvironment.preview())
    .environment(AppRouter())
}
