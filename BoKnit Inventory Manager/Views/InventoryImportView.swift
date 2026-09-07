import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct InventoryImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var existingItems: [InventoryItem]

    @State private var isShowingFileImporter = true
    @State private var preview: InventoryImportPreview?
    @State private var removeMissing = false
    @State private var errorMessage: String?
    @State private var isApplying = false
    @State private var sourceFileName: String?

    private let parser: InventoryFileParsing = NumbersImportService()

    private static let numbersContentType: UTType =
        UTType(filenameExtension: "numbers") ?? .data

    var body: some View {
        NavigationStack {
            content
                .background(BKColor.chassis)
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(BKColor.chassis, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                            .tint(BKColor.ink2)
                    }
                }
        }
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [Self.numbersContentType],
            onCompletion: handleFileSelection
        )
    }

    @ViewBuilder
    private var content: some View {
        if let errorMessage {
            VStack(spacing: 16) {
                ContentUnavailableView(
                    "Import Failed",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
                Button("Try Again") {
                    self.errorMessage = nil
                    isShowingFileImporter = true
                }
                .buttonStyle(.bordered)
                .tint(BKColor.orange)
            }
        } else if let preview {
            previewList(preview)
        } else {
            ProgressView("Reading file…")
        }
    }

    private func previewList(_ preview: InventoryImportPreview) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                BKScreenTitleRow(title: "Import") { EmptyView() }
                    .padding(.bottom, 4)

                VStack(alignment: .leading, spacing: 7) {
                    BKSectionLabel(index: 1, title: "source")
                    HStack(spacing: 13) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: 0x1E5C46))
                            .frame(width: 34, height: 34)
                            .overlay(
                                Image(systemName: "doc.text")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.white)
                            )
                        VStack(alignment: .leading, spacing: 4) {
                            Text(sourceFileName ?? "Numbers file")
                                .bkRowTitle(size: 14)
                                .foregroundStyle(BKColor.ink)
                                .lineLimit(1)
                            Text("sheet “Inventário” · \(preview.rows.count) rows")
                                .bkMonoLabel(size: 9)
                                .foregroundStyle(BKColor.ink2)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 62)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 3).fill(BKColor.panel)
                            RoundedRectangle(cornerRadius: 3).strokeBorder(BKColor.line, lineWidth: 1)
                        }
                    )
                }
                .padding(.top, 18)

                VStack(alignment: .leading, spacing: 7) {
                    BKSectionLabel(index: 2, title: "preview")
                    HStack(spacing: 7) {
                        BKStatTile(label: "new", value: "\(preview.newCount)", valueColor: BKColor.orange)
                        BKStatTile(label: "updated", value: "\(preview.updatedCount)")
                        BKStatTile(label: "same", value: "\(preview.unchangedCount)", valueColor: Color(hex: 0x9A9AA0))
                    }
                }
                .padding(.top, 22)

                VStack(alignment: .leading, spacing: 7) {
                    BKSectionLabel(index: 3, title: "options")
                    HStack {
                        Text("Remove items missing from file")
                            .bkRowTitle(size: 13)
                            .foregroundStyle(BKColor.ink)
                        Spacer()
                        BKSwitch(isOn: $removeMissing)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 56)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 3).fill(BKColor.panel)
                            RoundedRectangle(cornerRadius: 3).strokeBorder(BKColor.line, lineWidth: 1)
                        }
                    )
                    if preview.removableCount > 0 {
                        HStack(alignment: .top, spacing: 9) {
                            Rectangle().fill(BKColor.line).frame(width: 3)
                            Text("\(preview.removableCount) existing item(s) are missing from this file.")
                                .font(.system(size: 12))
                                .foregroundStyle(BKColor.ink2)
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(.top, 22)

                Spacer(minLength: 40)

                BKPrimaryButton(
                    title: isApplying ? "Applying…" : "Apply Import",
                    systemImage: "tray.and.arrow.down",
                    isDisabled: isApplying
                ) {
                    apply(preview)
                }
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 20)
        }
    }

    private func handleFileSelection(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let url):
            sourceFileName = url.lastPathComponent
            parseFile(at: url)
        }
    }

    private func parseFile(at url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        do {
            let rows = try parser.parseInventory(from: url)
            preview = InventoryImportService.preview(rows: rows, existingItems: existingItems)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func apply(_ preview: InventoryImportPreview) {
        isApplying = true
        do {
            try InventoryImportService.apply(
                rows: preview.rows,
                removeMissing: removeMissing,
                context: modelContext
            )
            dismiss()
        } catch {
            isApplying = false
            errorMessage = error.localizedDescription
        }
    }
}
