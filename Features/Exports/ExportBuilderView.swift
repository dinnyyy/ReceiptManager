import SwiftUI
import ReceiptVaultCore

/// Spec 5.12: "Turn stored records into a useful next-step document."
struct ExportBuilderView: View {
    var preselectedPurchaseIDs: Set<UUID> = []
    var preselectedItemIDs: Set<UUID> = []

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ExportBuilderViewModel?
    @State private var isPaywallPresented = false

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    content(viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
        .task {
            if viewModel == nil {
                viewModel = ExportBuilderViewModel(
                    environment: environment, preselectedPurchaseIDs: preselectedPurchaseIDs, preselectedItemIDs: preselectedItemIDs
                )
            }
        }
        .sheet(isPresented: $isPaywallPresented) {
            PaywallView(trigger: .proOnlyExport)
        }
    }

    @ViewBuilder
    private func content(_ viewModel: ExportBuilderViewModel) -> some View {
        @Bindable var viewModel = viewModel
        Form {
            Section("Pack type") {
                Picker("Type", selection: $viewModel.packType) {
                    ForEach(ProofPackType.allCases) { type in
                        Text(type.title).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Records") {
                Text(viewModel.recordCountSummary)
                    .foregroundStyle(.secondary)
            }

            Section("Include") {
                Toggle("Source receipts", isOn: $viewModel.options.includeSourceReceipts)
                Toggle("Item photos", isOn: $viewModel.options.includeItemPhotos)
                Toggle("Notes", isOn: $viewModel.options.includeNotes)
            }

            if viewModel.packType.includesCSV {
                Section {
                    Label("Also generates a CSV for your accountant", systemImage: "tablecells")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                if viewModel.generatedFileURLs.isEmpty {
                    Button {
                        Task {
                            if viewModel.canGenerate {
                                await viewModel.generate()
                            } else {
                                isPaywallPresented = true
                            }
                        }
                    } label: {
                        if viewModel.isGenerating {
                            ProgressView()
                        } else {
                            Text("Generate")
                        }
                    }
                    .disabled(viewModel.isGenerating)
                } else {
                    ShareLink(items: viewModel.generatedFileURLs) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red).font(.footnote) }
            }
        }
    }
}

#Preview {
    ExportBuilderView()
        .environment(AppEnvironment.preview())
}
