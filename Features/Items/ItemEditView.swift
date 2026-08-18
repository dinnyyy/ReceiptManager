import SwiftUI
import PhotosUI
import ReceiptVaultCore

/// Spec 5.9: "Capture the extra evidence that makes the app more useful
/// than a receipt folder." Item name is the only required field - serial
/// number and warranty are both optional (spec 5.9 acceptance: "Item can
/// exist without serial/warranty").
struct ItemEditView: View {
    let itemID: UUID?
    let prefillFromPurchaseID: UUID?
    let onSaved: () -> Void

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var brand = ""
    @State private var model = ""
    @State private var serialNumber = ""
    @State private var originalValueText = ""
    @State private var location = ""
    @State private var notes = ""

    @State private var hasWarranty = false
    @State private var warrantyProvider = ""
    @State private var warrantyExpiry = Date()
    @State private var warrantyDetails = ""
    @State private var reminderEnabled = false

    @State private var linkedPurchaseIDs: Set<UUID> = []
    @State private var availablePurchases: [Purchase] = []
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var existing: Item?
    @State private var errorMessage: String?

    private var isNew: Bool { itemID == nil }

    var body: some View {
        Form {
            Section("Item") {
                TextField("Name (required)", text: $name)
                TextField("Brand", text: $brand)
                TextField("Model", text: $model)
                TextField("Serial number", text: $serialNumber)
                LabeledContent("Value") { TextField("Optional", text: $originalValueText).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                TextField("Location, e.g. Work Van", text: $location)
            }

            Section("Photos") {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Add item or serial-label photo", systemImage: "camera")
                }
            }

            Section {
                Toggle("Has a warranty", isOn: $hasWarranty)
                if hasWarranty {
                    TextField("Provider", text: $warrantyProvider)
                    DatePicker("Expires", selection: $warrantyExpiry, displayedComponents: .date)
                    TextField("Details", text: $warrantyDetails, axis: .vertical)
                    Toggle("Remind me before this warranty ends", isOn: $reminderEnabled)
                }
            } header: {
                Text("Warranty")
            }

            if !availablePurchases.isEmpty {
                Section("Linked purchases") {
                    ForEach(availablePurchases) { purchase in
                        Toggle(isOn: Binding(
                            get: { linkedPurchaseIDs.contains(purchase.id) },
                            set: { isOn in
                                if isOn { linkedPurchaseIDs.insert(purchase.id) } else { linkedPurchaseIDs.remove(purchase.id) }
                            }
                        )) {
                            PurchaseRowView(purchase: purchase)
                        }
                    }
                }
            }

            Section("Notes") {
                TextEditor(text: $notes).frame(minHeight: 60)
            }

            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red).font(.footnote) }
            }
        }
        .navigationTitle(isNew ? "Add item" : "Edit item")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { Task { await save() } }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .task { await load() }
    }

    private func load() async {
        guard let workspaceID = environment.currentWorkspaceID else { return }
        availablePurchases = (try? environment.purchaseRepository.search(PurchaseSearchQuery(), workspaceID: workspaceID)) ?? []

        if let itemID, let item = try? environment.itemRepository.fetch(id: itemID) {
            existing = item
            name = item.name
            brand = item.brand ?? ""
            model = item.model ?? ""
            serialNumber = item.serialNumber ?? ""
            originalValueText = item.originalValue.map { "\($0)" } ?? ""
            location = item.location ?? ""
            notes = item.notes ?? ""
            linkedPurchaseIDs = item.purchaseIDs
            if let warranty = item.warranty {
                hasWarranty = true
                warrantyProvider = warranty.provider ?? ""
                warrantyDetails = warranty.details ?? ""
                reminderEnabled = warranty.reminderEnabled
                if let expiry = warranty.expiryDate?.asFoundationDate { warrantyExpiry = expiry }
            }
        } else if let prefillFromPurchaseID {
            linkedPurchaseIDs = [prefillFromPurchaseID]
            // Spec 5.9: "prefill original value from purchase total only as
            // a suggestion, not forced" - the user can freely change or
            // clear it.
            if let purchase = availablePurchases.first(where: { $0.id == prefillFromPurchaseID }), let total = purchase.totalAmount {
                originalValueText = "\(total)"
            }
        }
    }

    private func save() async {
        guard let workspaceID = environment.currentWorkspaceID else { return }
        let id = itemID ?? UUID()
        var item = Item(
            id: id, workspaceID: workspaceID, name: name.trimmingCharacters(in: .whitespaces),
            brand: brand.isEmpty ? nil : brand, model: model.isEmpty ? nil : model,
            serialNumber: serialNumber.isEmpty ? nil : serialNumber, originalValue: Money.parse(originalValueText),
            location: location.isEmpty ? nil : location, notes: notes.isEmpty ? nil : notes,
            purchaseIDs: linkedPurchaseIDs, syncState: existing?.syncState ?? .localOnly
        )

        if hasWarranty {
            let comps = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: warrantyExpiry)
            let expiry = comps.year.flatMap { y in comps.month.flatMap { m in comps.day.flatMap { d in DateOnly(year: y, month: m, day: d) } } }
            item.warranty = Warranty(
                id: existing?.warranty?.id ?? UUID(), workspaceID: workspaceID, itemID: id,
                provider: warrantyProvider.isEmpty ? nil : warrantyProvider, expiryDate: expiry,
                details: warrantyDetails.isEmpty ? nil : warrantyDetails, reminderEnabled: reminderEnabled
            )
        }

        do {
            try environment.itemRepository.save(item)

            if let photoItem = selectedPhotoItem, let data = try? await photoItem.loadTransferable(type: Data.self) {
                await attachPhoto(data: data, itemID: id, workspaceID: workspaceID)
            }

            if hasWarranty, let expiry = item.warranty?.expiryDate {
                if reminderEnabled {
                    await environment.notificationScheduler.scheduleReminders(itemID: id, itemName: item.name, expiryDate: expiry)
                    environment.analyticsService.track(.warrantyReminderSet(daysBeforeExpiry: WarrantyReminderSchedule.defaultDaysBeforeExpiry.first ?? 30))
                } else {
                    await environment.notificationScheduler.cancelReminders(itemID: id)
                }
            } else {
                await environment.notificationScheduler.cancelReminders(itemID: id)
            }

            environment.syncEngine?.drainOutbox()
            onSaved()
            dismiss()
        } catch {
            errorMessage = "Couldn't save this item. Please try again."
        }
    }

    private func attachPhoto(data: Data, itemID: UUID, workspaceID: UUID) async {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("jpg")
        do {
            try data.write(to: tempURL)
            let local = LocalAttachment(fileURL: tempURL, type: .itemPhoto, mimeType: "image/jpeg", originalFilename: nil)
            let staged = try environment.attachmentService.stage(local, workspaceID: workspaceID, purchaseID: nil, itemID: itemID)
            let attachment = Attachment(
                id: staged.id, workspaceID: workspaceID, itemID: itemID, type: .itemPhoto,
                storagePath: staged.storagePath, mimeType: staged.mimeType, bytes: staged.bytes,
                sha256: staged.sha256, syncState: .pendingUpload
            )
            try environment.attachmentRepository.save(attachment, localFilePath: staged.localFileURL.path)
        } catch {
            // Non-fatal: the item itself already saved successfully.
        }
    }
}

private extension DateOnly {
    var asFoundationDate: Date? {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        return Calendar(identifier: .gregorian).date(from: comps)
    }
}

#Preview {
    NavigationStack {
        ItemEditView(itemID: nil, prefillFromPurchaseID: nil, onSaved: {})
    }
    .environment(AppEnvironment.preview())
}
