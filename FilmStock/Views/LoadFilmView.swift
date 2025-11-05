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
    @State private var newCameraName: String = ""
    @State private var showingCameraPicker = false
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
            .navigationTitle("Load Film")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Load") {
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
        Section("Select Format") {
            if availableFormats.isEmpty {
                Text("No formats available")
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
        
        return HStack {
            Text(format.displayName)
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
        Section("Select Camera") {
            NavigationLink(destination: CameraPickerView(selectedCamera: $selectedCamera, newCameraName: $newCameraName)) {
                HStack {
                    Text("Camera")
                    Spacer()
                    Text(selectedCamera.isEmpty ? "Select Camera" : selectedCamera)
                        .foregroundColor(selectedCamera.isEmpty ? .secondary : .primary)
                }
            }
        }
    }
    
    private var quantitySelectionSection: some View {
        Group {
            if let format = selectedFormat, isSheetFormat(format) {
                Section("Number of Sheets") {
                    Stepper("Sheets: \(sheetQuantity)", value: $sheetQuantity, in: 1...maxSheetQuantity)
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
            errorMessage = "No rolls available for this format"
            return
        }
        
        // Check if we can load (max 5 films)
        guard dataManager.canLoadFilm() else {
            errorMessage = "Maximum of 5 films can be loaded at once"
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
            errorMessage = "Failed to load film. Make sure you have at least \(quantityToLoad) \(unit) available."
        }
    }
}

struct CameraPickerView: View {
    @Binding var selectedCamera: String
    @Binding var newCameraName: String
    @EnvironmentObject var dataManager: FilmStockDataManager
    @Environment(\.dismiss) var dismiss
    @State private var searchText: String = ""
    @State private var showingAddCamera = false
    
    var filteredCameras: [Camera] {
        let cameras = dataManager.getAllCameras()
        if searchText.isEmpty {
            return cameras
        }
        return cameras.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        List {
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
            }
            
            // Add new camera option
            if !searchText.isEmpty && !filteredCameras.contains(where: { $0.name.localizedCaseInsensitiveContains(searchText) }) {
                Button {
                    newCameraName = searchText
                    selectedCamera = searchText
                    dataManager.addCamera(name: searchText)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add \"\(searchText)\"")
                    }
                    .foregroundColor(.accentColor)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search or add camera")
        .navigationTitle("Select Camera")
        .navigationBarTitleDisplayMode(.inline)
    }
}

