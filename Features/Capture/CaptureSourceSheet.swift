import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Spec 5.4: "Let users add proof from the place it already exists."
/// Cancelling any of the four paths below never creates a server or local
/// draft record (spec 5.4 acceptance) - `CaptureDraft` only exists in
/// memory here, and Review is the first point anything touches disk as a
/// tracked purchase.
struct CaptureSourceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var environment

    @State private var isScannerPresented = false
    @State private var isPhotoPickerPresented = false
    @State private var isFileImporterPresented = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var pendingDraft: CaptureDraft?
    @State private var importErrorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Button {
                    environment.analyticsService.track(.captureStarted(source: .camera))
                    isScannerPresented = true
                } label: {
                    CaptureOptionRow(systemImage: "camera.viewfinder", title: "Scan with camera", subtitle: "Best for a paper receipt in hand")
                }

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    CaptureOptionRow(systemImage: "photo.on.rectangle", title: "Choose photo or screenshot", subtitle: "Import something already saved on your phone")
                }
                .onChange(of: selectedPhotoItem) { _, newItem in
                    Task { await handlePickedPhoto(newItem) }
                }

                Button {
                    isFileImporterPresented = true
                } label: {
                    CaptureOptionRow(systemImage: "doc.badge.plus", title: "Import file or PDF", subtitle: "Emailed or downloaded invoices")
                }

                Button {
                    environment.analyticsService.track(.captureStarted(source: .manual))
                    pendingDraft = .manual()
                } label: {
                    CaptureOptionRow(systemImage: "square.and.pencil", title: "Enter manually", subtitle: "No receipt to scan or import")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Add a purchase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Couldn't import that file", isPresented: .constant(importErrorMessage != nil), actions: {
                Button("OK") { importErrorMessage = nil }
            }, message: {
                Text(importErrorMessage ?? "")
            })
        }
        .fullScreenCover(isPresented: $isScannerPresented) {
            DocumentScannerView(
                onComplete: { urls in
                    isScannerPresented = false
                    environment.analyticsService.track(.captureStarted(source: .camera))
                    pendingDraft = CaptureDraft(fileURLs: urls, source: .camera)
                },
                onCancel: { isScannerPresented = false }
            )
            .ignoresSafeArea()
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.pdf, .jpeg, .png, .heic],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .fullScreenCover(item: $pendingDraft) { draft in
            ReviewView(draft: draft, onFinished: { dismiss() })
        }
    }

    private func handlePickedPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        environment.analyticsService.track(.captureStarted(source: .photo))
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            importErrorMessage = "That photo couldn't be loaded. Try again or choose a different one."
            return
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("jpg")
        do {
            try data.write(to: url)
            pendingDraft = CaptureDraft(fileURLs: [url], source: .photo)
        } catch {
            importErrorMessage = "That photo couldn't be saved. Try again."
        }
        selectedPhotoItem = nil
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        environment.analyticsService.track(.captureStarted(source: .pdf))
        switch result {
        case .success(let urls):
            guard let sourceURL = urls.first else { return }
            guard sourceURL.startAccessingSecurityScopedResource() else {
                importErrorMessage = "That file couldn't be accessed. Try again."
                return
            }
            defer { sourceURL.stopAccessingSecurityScopedResource() }
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(sourceURL.pathExtension)
            do {
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.copyItem(at: sourceURL, to: destination)
                pendingDraft = CaptureDraft(fileURLs: [destination], source: .pdf)
            } catch {
                // Spec 6.5 edge case: "PDF encrypted/corrupt - show
                // unsupported/cannot-read message and do not create a
                // broken record." Copy failures land here too since we
                // never got a readable local file to build a draft from.
                importErrorMessage = "That file couldn't be read. It may be corrupted or password protected."
            }
        case .failure:
            importErrorMessage = "That file couldn't be imported."
        }
    }
}

private struct CaptureOptionRow: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.tint)
                .frame(width: 28)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    CaptureSourceSheet()
        .environment(AppEnvironment.preview())
}
