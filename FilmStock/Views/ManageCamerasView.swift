//
//  ManageCamerasView.swift
//  FilmStock
//
//  Manage cameras for loading films
//

import SwiftUI

// MARK: - Manage Cameras

struct ManageCamerasView: View {
    @EnvironmentObject var dataManager: FilmStockDataManager
    @Environment(\.dismiss) var dismiss

    @State private var showingAddCamera = false
    @State private var showDeleteError = false
    @State private var deleteErrorMessage = ""

    var allCameras: [Camera] {
        dataManager.getAllCameras()
    }

    var body: some View {
        NavigationStack {
            List {
                if allCameras.isEmpty {
                    Section {
                        Text("cameras.empty")
                            .foregroundColor(.secondary)
                    }
                } else {
                    Section {
                        ForEach(allCameras, id: \.name) { camera in
                            NavigationLink {
                                EditCameraView(camera: camera)
                                    .environmentObject(dataManager)
                            } label: {
                                CameraRowLabel(camera: camera)
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let camera = allCameras[index]
                                if !dataManager.deleteCamera(camera) {
                                    showDeleteError = true
                                    deleteErrorMessage = String(
                                        format: NSLocalizedString("camera.deleteErrorMessage", comment: ""),
                                        camera.name
                                    )
                                }
                            }
                        }
                    } footer: {
                        Text("cameras.swipeToDelete")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("cameras.manage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("action.done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddCamera = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddCamera) {
                AddCameraSheet(onAdd: { _ in })
                    .environmentObject(dataManager)
            }
            .alert("camera.deleteError", isPresented: $showDeleteError) {
                Button("action.ok", role: .cancel) { }
            } message: {
                Text(deleteErrorMessage)
            }
        }
    }
}

// MARK: - Camera Row Label

private struct CameraRowLabel: View {
    let camera: Camera

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(camera.name)
                .foregroundColor(.primary)
            if !camera.formatDisplayName.isEmpty {
                Text(camera.formatDisplayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Edit Camera View

struct EditCameraView: View {
    let camera: Camera
    @EnvironmentObject var dataManager: FilmStockDataManager
    @Environment(\.dismiss) var dismiss

    @State private var name: String
    @State private var selectedFormat: String
    @State private var selectedCustomFormatName: String?
    @State private var hasLoaded = false

    init(camera: Camera) {
        self.camera = camera
        _name = State(initialValue: camera.name)
        _selectedFormat = State(initialValue: camera.format)
        _selectedCustomFormatName = State(initialValue: camera.customFormatName)
    }

    private var formatLabel: String {
        CameraFormatPickerView.displayName(
            format: selectedFormat,
            customFormatName: selectedCustomFormatName
        )
    }

    var body: some View {
        Form {
            Section("camera.name") {
                TextField("camera.name", text: $name)
                    .autocorrectionDisabled()
            }

            Section("camera.format") {
                NavigationLink {
                    CameraFormatPickerView(
                        selectedFormat: $selectedFormat,
                        selectedCustomFormatName: $selectedCustomFormatName
                    )
                    .environmentObject(dataManager)
                } label: {
                    HStack {
                        Text("camera.format")
                        Spacer()
                        Text(formatLabel.isEmpty
                             ? NSLocalizedString("camera.format.none", comment: "")
                             : formatLabel)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("camera.edit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("action.save") {
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    dataManager.updateCamera(
                        camera,
                        name: trimmed,
                        format: selectedFormat,
                        customFormatName: selectedCustomFormatName
                    )
                    dismiss()
                }
                .fontWeight(.semibold)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear {
            guard !hasLoaded else { return }
            hasLoaded = true
            name = camera.name
            selectedFormat = camera.format
            selectedCustomFormatName = camera.customFormatName
        }
    }
}

// MARK: - Add Camera Sheet

struct AddCameraSheet: View {
    @EnvironmentObject var dataManager: FilmStockDataManager
    @Environment(\.dismiss) var dismiss

    var onAdd: (Camera) -> Void

    @State private var name = ""
    @State private var selectedFormat = ""
    @State private var selectedCustomFormatName: String? = nil
    @State private var showDuplicateError = false

    private var isDuplicate: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return dataManager.getAllCameras().contains {
            $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame
        }
    }

    private var formatLabel: String {
        CameraFormatPickerView.displayName(
            format: selectedFormat,
            customFormatName: selectedCustomFormatName
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("camera.name") {
                    TextField("camera.name", text: $name)
                        .autocorrectionDisabled()
                    if isDuplicate && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("camera.duplicateError")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                Section("camera.format") {
                    NavigationLink {
                        CameraFormatPickerView(
                            selectedFormat: $selectedFormat,
                            selectedCustomFormatName: $selectedCustomFormatName
                        )
                        .environmentObject(dataManager)
                    } label: {
                        HStack {
                            Text("camera.format")
                            Spacer()
                            Text(formatLabel.isEmpty
                                 ? NSLocalizedString("camera.format.none", comment: "")
                                 : formatLabel)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("camera.add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("action.add") {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty, !isDuplicate else { return }
                        let camera = dataManager.addCamera(
                            name: trimmed,
                            format: selectedFormat,
                            customFormatName: selectedCustomFormatName
                        )
                        onAdd(camera)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(
                        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isDuplicate
                    )
                }
            }
        }
    }
}

// MARK: - Camera Format Picker View

struct CameraFormatPickerView: View {
    @EnvironmentObject var dataManager: FilmStockDataManager
    @Binding var selectedFormat: String
    @Binding var selectedCustomFormatName: String?

    private struct FormatOption: Identifiable {
        let id: String
        let label: String
        let format: String
        let customName: String?
    }

    private var options: [FormatOption] {
        var result: [FormatOption] = [
            FormatOption(id: "__none__", label: NSLocalizedString("camera.format.none", comment: ""),
                         format: "", customName: nil)
        ]
        for f in FilmStock.FilmFormat.allCases {
            result.append(FormatOption(id: f.rawValue, label: f.displayName, format: f.rawValue, customName: nil))
        }
        for customName in dataManager.getCustomFormatNames() {
            result.append(FormatOption(id: "Other_\(customName)", label: customName,
                                       format: FilmStock.FilmFormat.other.rawValue, customName: customName))
        }
        return result
    }

    private var currentId: String {
        if selectedFormat.isEmpty { return "__none__" }
        if selectedFormat == FilmStock.FilmFormat.other.rawValue,
           let name = selectedCustomFormatName {
            return "Other_\(name)"
        }
        return selectedFormat
    }

    var body: some View {
        List {
            ForEach(options) { option in
                Button {
                    selectedFormat = option.format
                    selectedCustomFormatName = option.customName
                } label: {
                    HStack {
                        Text(option.label)
                            .foregroundColor(.primary)
                        Spacer()
                        if currentId == option.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
        }
        .navigationTitle("camera.format")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Shared helper used by both AddCameraSheet and EditCameraView.
    static func displayName(format: String, customFormatName: String?) -> String {
        if format.isEmpty { return "" }
        if format == FilmStock.FilmFormat.other.rawValue,
           let name = customFormatName, !name.isEmpty { return name }
        return FilmStock.FilmFormat(rawValue: format)?.displayName ?? format
    }
}
