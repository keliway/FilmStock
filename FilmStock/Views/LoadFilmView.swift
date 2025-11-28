//
//  LoadFilmView.swift
//  FilmStock
//
//  View for loading a film into a camera
//

import SwiftUI

struct LoadFilmView: View {
    let groupedFilm: GroupedFilm
    @EnvironmentObject var dataManager: FilmStockDataManager
    @Environment(\.dismiss) var dismiss
    var onLoadComplete: (() -> Void)?
    
    @State private var selectedFormat: FilmStock.FilmFormat?
    @State private var selectedCamera: String = ""
    @State private var errorMessage: String?
    @State private var sheetQuantity: Int = 1
    
    var availableFormats: [FilmStock.FilmFormat] {
        let formatsWithQuantity = groupedFilm.formats.filter { formatInfo in
            formatInfo.quantity > 0
        }
        return formatsWithQuantity.map { formatInfo in
            formatInfo.format
        }
    }
    
    var availableCameras: [Camera] {
        dataManager.getAllCameras()
    }
    
    var body: some View {
        NavigationStack {
            Form {
                formatSelectionSection
                cameraSelectionSection
                quantitySelectionSection
                errorSection
            }
            .navigationTitle("load.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("action.cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("action.load") {
                        loadFilm()
                    }
                    .disabled(selectedFormat == nil || selectedCamera.isEmpty)
                }
            }
        }
        .onAppear {
            if availableFormats.count == 1 {
                selectedFormat = availableFormats.first
            }
            
            // Auto-select camera if only one is available
            let cameras = availableCameras
            if cameras.count == 1, selectedCamera.isEmpty {
                selectedCamera = cameras.first?.name ?? ""
            }
            
            // Reset sheet quantity when format changes
            sheetQuantity = 1
        }
        .onChange(of: selectedFormat) { oldValue, newValue in
            // Reset sheet quantity when format changes
            sheetQuantity = 1
        }
    }
    
    private var formatSelectionSection: some View {
        Section("load.selectFormat") {
            if availableFormats.isEmpty {
                Text("load.noFormatsAvailable")
                    .foregroundColor(.secondary)
            } else {
                ForEach(availableFormats, id: \.self) { format in
                    formatRow(format: format)
                }
            }
        }
    }
    
    private func formatRow(format: FilmStock.FilmFormat) -> some View {
        let formatInfo = groupedFilm.formats.first { $0.format == format }
        let quantity = formatInfo?.quantity ?? 0
        let quantityUnit = format.quantityUnit
        let isSelected = selectedFormat == format
        // Use custom format name if available
        let displayName = formatInfo?.formatDisplayName ?? format.displayName
        
        return HStack {
            Text(displayName)
            Spacer()
            Text("\(quantity) \(quantityUnit)")
                .foregroundColor(.secondary)
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.accentColor)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedFormat = format
        }
    }
    
    private var cameraSelectionSection: some View {
        Section("load.selectCamera") {
            NavigationLink {
                CameraPickerView(selectedCamera: $selectedCamera)
                    .environmentObject(dataManager)
            } label: {
                HStack {
                    Text("camera.name")
                    Spacer()
                    if selectedCamera.isEmpty {
                        Text("load.selectCamera")
                            .foregroundColor(.secondary)
                    } else {
                        Text(selectedCamera)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
    }
    
    private var quantitySelectionSection: some View {
        Group {
            if let format = selectedFormat, isSheetFormat(format) {
                Section("load.quantityToLoad") {
                    Stepper(String(format: NSLocalizedString("Sheets: %d", comment: ""), sheetQuantity), value: $sheetQuantity, in: 1...maxSheetQuantity)
                }
            }
        }
    }
    
    private func isSheetFormat(_ format: FilmStock.FilmFormat) -> Bool {
        format == .fourByFive || format == .fiveBySeven || format == .eightByTen
    }
    
    private var maxSheetQuantity: Int {
        guard let format = selectedFormat,
              let formatInfo = groupedFilm.formats.first(where: { $0.format == format }) else {
            return 1
        }
        return formatInfo.quantity
    }
    
    private var errorSection: some View {
        Group {
            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                }
            }
        }
    }
                
    
    private func loadFilm() {
        guard let format = selectedFormat,
              !selectedCamera.isEmpty else {
            return
        }
        
        // Find the format info for the selected format
        guard let formatInfo = groupedFilm.formats.first(where: { $0.format == format }),
              formatInfo.quantity > 0 else {
            errorMessage = NSLocalizedString("load.error.noRolls", comment: "")
            return
        }
        
        // Determine quantity to load (1 for rolls, sheetQuantity for sheets)
        let quantityToLoad = isSheetFormat(format) ? sheetQuantity : 1
        
        // Load the film - use the filmId from formatInfo which is the MyFilm.id
        if dataManager.loadFilm(filmStockId: formatInfo.filmId, format: format, cameraName: selectedCamera, quantity: quantityToLoad) {
            dismiss()
            onLoadComplete?()
        } else {
            let unit = isSheetFormat(format) ? "sheets" : "rolls"
            errorMessage = String(format: NSLocalizedString("load.error.failed", comment: ""), quantityToLoad, unit)
        }
    }
}

struct CameraPickerView: View {
    @Binding var selectedCamera: String
    @EnvironmentObject var dataManager: FilmStockDataManager
    @Environment(\.dismiss) var dismiss
    @State private var searchText: String = ""
    @State private var showingAddCamera = false
    @State private var newCameraNameInput = ""
    @State private var showDeleteError = false
    @State private var showDuplicateError = false
    @State private var showingCameraInfo = false
    
    var allCameras: [Camera] {
        dataManager.getAllCameras()
    }
    
    var filteredCameras: [Camera] {
        if searchText.isEmpty {
            return allCameras
        }
        return allCameras.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var isDuplicate: Bool {
        let trimmedName = newCameraNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        return allCameras.contains(where: { $0.name.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame })
    }
    
    var hasNoCameras: Bool {
        allCameras.isEmpty
    }
    
    var searchTextTrimmed: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var canAddFromSearch: Bool {
        !searchTextTrimmed.isEmpty && 
        !allCameras.contains(where: { $0.name.localizedCaseInsensitiveCompare(searchTextTrimmed) == .orderedSame })
    }
    
    var body: some View {
        List {
            // Show empty state with add button if no cameras
            if hasNoCameras && searchText.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "camera")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("cameras.empty")
                            .foregroundColor(.secondary)
                        Button {
                            newCameraNameInput = ""
                            showingAddCamera = true
                        } label: {
                            Label("camera.addFirst", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            }
            
            // Show "Add camera" option when search doesn't match any existing camera
            if canAddFromSearch {
                Section {
                    Button {
                        let newCamera = dataManager.addCamera(name: searchTextTrimmed)
                        selectedCamera = newCamera.name
                        dismiss()
                    } label: {
                        Label(String(format: NSLocalizedString("action.addNew", comment: ""), searchTextTrimmed), systemImage: "plus.circle")
                    }
                }
            }
            
            ForEach(filteredCameras, id: \.name) { camera in
                Button {
                    selectedCamera = camera.name
                    dismiss()
                } label: {
                    HStack {
                        Text(camera.name)
                        Spacer()
                        if selectedCamera == camera.name {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        let success = dataManager.deleteCamera(camera)
                        if !success {
                            showDeleteError = true
                        }
                    } label: {
                        Label("action.delete", systemImage: "trash")
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: Text("camera.search"))
        .navigationTitle("load.selectCamera")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                // Show info button if cameras exist, add button only if no cameras
                if hasNoCameras {
                    Button {
                        newCameraNameInput = ""
                        showingAddCamera = true
                    } label: {
                        Image(systemName: "plus")
                    }
                } else {
                    Button {
                        showingCameraInfo = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                }
            }
        }
        .alert("cameras.info.title", isPresented: $showingCameraInfo) {
            Button("action.ok", role: .cancel) { }
        } message: {
            Text("cameras.info.message")
        }
        .alert("camera.add", isPresented: $showingAddCamera) {
            TextField("camera.name", text: $newCameraNameInput)
                .autocorrectionDisabled()
            Button("action.cancel", role: .cancel) {
                newCameraNameInput = ""
            }
            Button("action.add") {
                let trimmedName = newCameraNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedName.isEmpty && !isDuplicate {
                    let newCamera = dataManager.addCamera(name: trimmedName)
                    selectedCamera = newCamera.name
                    dismiss()
                } else if isDuplicate {
                    showDuplicateError = true
                }
                newCameraNameInput = ""
            }
            .disabled(newCameraNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isDuplicate)
        } message: {
            if isDuplicate {
                Text("camera.duplicateError")
            } else {
                Text("camera.addMessage")
            }
        }
        .alert("camera.duplicateTitle", isPresented: $showDuplicateError) {
            Button("action.ok", role: .cancel) { }
        } message: {
            Text("camera.duplicateMessage")
        }
        .alert("camera.deleteError", isPresented: $showDeleteError) {
            Button("action.ok", role: .cancel) { }
        } message: {
            Text("camera.deleteErrorMessage")
        }
    }
}

