//
//  ExportView.swift
//  FilmStock
//
//  Export all film data as JSON or CSV, or import an inventory file.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - URL Identifiable

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

// MARK: - Main View

struct ExportView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dataManager: FilmStockDataManager

    enum Tab: String, CaseIterable, Identifiable {
        case export = "export.tab.export"
        case importTab = "export.tab.import"
        var id: String { rawValue }
    }

    @State private var activeTab: Tab = .export
    @State private var exportURL: URL?
    @State private var isWorking = false
    @State private var errorMessage: String?

    // Export
    enum ExportFormat: String, CaseIterable, Identifiable {
        case json = "JSON"; case csv = "CSV"
        var id: String { rawValue }
        var descriptionKey: String {
            self == .json ? "export.format.json.description" : "export.format.csv.description"
        }
        var icon: String { self == .json ? "curlybraces" : "tablecells" }
    }
    @State private var selectedFormat: ExportFormat = .json

    // Import
    @State private var showingFilePicker = false
    @State private var importPreview: ImportPreview?

    struct ImportPreview: Identifiable {
        let id = UUID()
        let rows: [FilmStock]
        let warnings: [String]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Beta notice
            Text(LocalizedStringKey("export.beta.notice"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 4)

            Picker("", selection: $activeTab) {
                ForEach(Tab.allCases) { tab in
                    Text(LocalizedStringKey(tab.rawValue)).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            if activeTab == .export {
                exportContent
            } else {
                importContent
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("export.title")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $exportURL) { url in
            ShareSheet(url: url).ignoresSafeArea()
        }
        .sheet(item: $importPreview) { preview in
            ImportPreviewSheet(preview: preview) { confirmed in
                if confirmed { commitImport(preview.rows) }
            }
            .environmentObject(dataManager)
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.json, UTType(filenameExtension: "csv") ?? .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleFilePick(result)
        }
    }

    // MARK: - Export tab

    private var exportContent: some View {
        List {
            Section("export.format") {
                ForEach(ExportFormat.allCases) { format in
                    Button {
                        selectedFormat = format
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: format.icon)
                                .font(.title3)
                                .foregroundColor(.accentColor)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(format.rawValue)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                Text(LocalizedStringKey(format.descriptionKey))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if selectedFormat == format {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("export.includes") {
                    Label("export.includes.inventory", systemImage: "film")
                }

            errorSection
        }
        .safeAreaInset(edge: .bottom) { actionButton("export.action", icon: "square.and.arrow.up") { runExport() } }
    }

    // MARK: - Import tab

    private var importContent: some View {
        List {
            Section {
                Label("import.supports.json", systemImage: "curlybraces")
                Label("import.supports.csv",  systemImage: "tablecells")
            } header: {
                Text("import.supported.formats")
            } footer: {
                Text("import.footer")
            }

            Section {
                Label("import.scope.inventory", systemImage: "film")
            } header: {
                Text("import.scope.header")
            } footer: {
                Text("import.scope.footer")
            }

            errorSection
        }
        .safeAreaInset(edge: .bottom) { actionButton("import.action", icon: "square.and.arrow.down") { showingFilePicker = true } }
    }

    @ViewBuilder
    private var errorSection: some View {
        if let error = errorMessage {
            Section {
                Text(error).foregroundColor(.red).font(.caption)
            }
        }
    }

    @ViewBuilder
    private func actionButton(_ titleKey: String, icon: String, action: @escaping () -> Void) -> some View {
        Button { action() } label: {
            Group {
                if isWorking {
                    ProgressView().progressViewStyle(.circular).tint(.white)
                } else {
                    Label(LocalizedStringKey(titleKey), systemImage: icon).fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(isWorking)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .background(Color(.systemGroupedBackground).ignoresSafeArea(edges: .bottom))
    }

    // MARK: - Actions

    private func runExport() {
        isWorking = true; errorMessage = nil
        Task {
            do {
                let url: URL = selectedFormat == .json
                    ? try ExportManager.shared.exportJSON(context: modelContext)
                    : try ExportManager.shared.exportCSV(context: modelContext)
                exportURL = url
            } catch { errorMessage = error.localizedDescription }
            isWorking = false
        }
    }

    private func handleFilePick(_ result: Result<[URL], Error>) {
        errorMessage = nil
        switch result {
        case .failure(let err): errorMessage = err.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            isWorking = true
            Task {
                do {
                    // Security-scoped resource access required for file importer
                    _ = url.startAccessingSecurityScopedResource()
                    defer { url.stopAccessingSecurityScopedResource() }
                    let (rows, warnings) = try ExportManager.shared.importInventory(from: url)
                    importPreview = ImportPreview(rows: rows, warnings: warnings)
                } catch {
                    errorMessage = error.localizedDescription
                }
                isWorking = false
            }
        }
    }

    private func commitImport(_ rows: [FilmStock]) {
        for row in rows {
            _ = dataManager.addFilmStock(row)
        }
    }
}

// MARK: - Import preview sheet

struct ImportPreviewSheet: View {
    let preview: ExportView.ImportPreview
    let onDismiss: (Bool) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("import.preview.count")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(preview.rows.count)")
                            .fontWeight(.semibold)
                    }
                } header: {
                    Text("import.preview.summary")
                }

                if !preview.warnings.isEmpty {
                    Section("import.preview.warnings") {
                        ForEach(preview.warnings, id: \.self) { w in
                            Text(w).font(.caption).foregroundColor(.orange)
                        }
                    }
                }

                Section("import.preview.films") {
                    ForEach(preview.rows) { row in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(row.manufacturer) \(row.name)")
                                .fontWeight(.medium)
                            Text("\(row.quantity)× \(row.format.displayName) · ISO \(row.filmSpeed) · \(row.type.displayName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("import.preview.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("action.cancel") { onDismiss(false); dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("import.preview.confirm") {
                        onDismiss(true); dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(preview.rows.isEmpty)
                }
            }
        }
    }
}

// MARK: - UIActivityViewController bridge

private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}
