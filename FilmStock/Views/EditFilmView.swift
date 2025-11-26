//
//  EditFilmView.swift
//  FilmStock
//
//  Edit film view (iOS Form style)
//

import SwiftUI

// Helper function to parse custom image name
// Returns (manufacturer, filename) tuple
private func parseCustomImageName(_ imageName: String, defaultManufacturer: String) -> (String, String) {
    if imageName.contains("/") {
        let components = imageName.split(separator: "/", maxSplits: 1)
        if components.count == 2 {
            return (String(components[0]), String(components[1]))
        }
    }
    return (defaultManufacturer, imageName)
}

struct EditFilmView: View {
    let groupedFilm: GroupedFilm
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataManager: FilmStockDataManager
    @ObservedObject private var settingsManager = SettingsManager.shared
    
    @State private var name = ""
    @State private var manufacturer = ""
    @State private var type: FilmStock.FilmType = .bw
    @State private var filmSpeed = 400
    
    private let isoValues = [1, 2, 4, 5, 8, 10, 12, 16, 20, 25, 32, 40, 50, 64, 80, 100, 125, 160, 200, 250, 320, 400, 500, 640, 800, 1000, 1250, 1600, 2000, 2500, 3200, 6400]
    @State private var format: FilmStock.FilmFormat = .thirtyFive
    @State private var selectedFormatString: String = "35mm"
    
    private var allEnabledFormats: [String] {
        var formats: [String] = []
        // Add enabled built-in formats
        for builtIn in FilmStock.FilmFormat.allCases {
            if settingsManager.isFormatEnabled(builtIn.displayName) {
                formats.append(builtIn.displayName)
            }
        }
        // Add enabled custom formats
        for custom in settingsManager.customFormats {
            if settingsManager.isFormatEnabled(custom) {
                formats.append(custom)
            }
        }
        // Include current format even if disabled
        if !formats.contains(selectedFormatString) {
            formats.append(selectedFormatString)
        }
        return formats
    }
    
    private func formatFromString(_ str: String) -> FilmStock.FilmFormat {
        if let builtIn = FilmStock.FilmFormat.allCases.first(where: { $0.displayName == str }) {
            return builtIn
        }
        return .other
    }
    @State private var quantity = 0
    @State private var expireDates: [String] = [""]
    @State private var comments = ""
    @State private var isFrozen = false
    @State private var filmToEdit: FilmStock?
    @State private var selectedImage: UIImage?
    @State private var defaultImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingImageCatalog = false
    @State private var rawSelectedImage: UIImage?
    @State private var selectedCatalogFilename: String? // Tracks catalog image filename (e.g., "ilford_hp5")
    @State private var imageSource: ImageSource = .autoDetected
    @State private var catalogSelectedSource: ImageSource? // Tracks what was selected from catalog
    
    // Validation errors
    @State private var nameError: String?
    @State private var expireDateErrors: [Int: String] = [:]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("film.filmInformation") {
                    NavigationLink {
                        ManufacturerPickerView(
                            selectedManufacturer: $manufacturer,
                            allowAddingManufacturer: false
                        )
                        .environmentObject(dataManager)
                    } label: {
                        if manufacturer.isEmpty {
                            Text("film.selectManufacturer")
                                .foregroundColor(.secondary)
                        } else {
                            Text(manufacturer)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("film.name", text: $name)
                            .autocorrectionDisabled()
                            .onChange(of: name) { oldValue, newValue in
                                // Clear error when user starts typing
                                if nameError != nil {
                                    nameError = nil
                                }
                            }
                        
                        if let error = nameError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    Picker("film.type", selection: $type) {
                        ForEach(FilmStock.FilmType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    
                    Picker("film.speed", selection: $filmSpeed) {
                        ForEach(isoValues, id: \.self) { iso in
                            Text("ISO \(iso)").tag(iso)
                        }
                    }
                    .pickerStyle(.wheel)
                    
                    Picker("film.format", selection: $selectedFormatString) {
                        ForEach(allEnabledFormats, id: \.self) { formatStr in
                            Text(formatStr).tag(formatStr)
                        }
                    }
                    .onChange(of: selectedFormatString) { _, newValue in
                        format = formatFromString(newValue)
                    }
                    
                    // Image selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("film.filmReminder")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        // Image selection buttons - only show if no custom image is uploaded
                        if selectedImage == nil {
                            HStack(spacing: 12) {
                                Button {
                                    showingImagePicker = true
                                } label: {
                                    HStack {
                                        Image(systemName: "camera.fill")
                                        Text("image.takePhoto")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.accentColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                                
                                Button {
                                    showingImageCatalog = true
                                } label: {
                                    HStack {
                                        Image(systemName: "photo.on.rectangle")
                                        Text("image.openCatalog")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemGray5))
                                    .foregroundColor(.primary)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        // Image previews
                        if selectedImage != nil || defaultImage != nil {
                            HStack(spacing: 12) {
                                // Custom uploaded image
                                if let selectedImage = selectedImage {
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: selectedImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 100, height: 100)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(imageSource == .custom || imageSource == .catalog ? Color.accentColor : Color.clear, lineWidth: 3)
                                            )
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                // User selected custom/catalog image
                                                if selectedCatalogFilename != nil {
                                                    imageSource = .catalog
                                                } else {
                                                    imageSource = .custom
                                                }
                                            }
                                        
                                        Button(action: {
                                            self.selectedImage = nil
                                            selectedCatalogFilename = nil
                                            if defaultImage != nil {
                                                imageSource = .autoDetected
                                            } else {
                                                imageSource = .none
                                            }
                                        }) {
                                            ZStack {
                                                Circle()
                                                    .fill(Color.black.opacity(0.6))
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.white)
                                                    .font(.system(size: 20))
                                            }
                                            .frame(width: 24, height: 24)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .offset(x: 4, y: -4)
                                        .zIndex(1)
                                    }
                                    .frame(width: 100, height: 100)
                                    .contentShape(Rectangle())
                                }
                                
                                // Default image thumbnail
                                if let defaultImage = defaultImage {
                                    Image(uiImage: defaultImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 100, height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(imageSource == .autoDetected ? Color.accentColor : Color.clear, lineWidth: 3)
                                        )
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            imageSource = .autoDetected
                                        }
                                }
                            }
                            .contentShape(Rectangle())
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section("film.quantity") {
                    Stepper(String(format: NSLocalizedString("Quantity: %d", comment: ""), quantity), value: $quantity, in: 0...999)
                }
                
                Section("film.expiryDate") {
                    ForEach(expireDates.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("film.expiryDateFormat", text: Binding(
                                get: { expireDates[index] },
                                set: { newValue in
                                    // Remove any non-numeric characters
                                    let filtered = newValue.filter { $0.isNumber }
                                    
                                    // Limit to 6 characters
                                    let limited = String(filtered.prefix(6))
                                    
                                    // Auto-format based on length
                                    if limited.count == 6 {
                                        // Format as MM/YYYY
                                        let month = limited.prefix(2)
                                        let year = limited.suffix(4)
                                        expireDates[index] = "\(month)/\(year)"
                                    } else {
                                        // Keep as-is (for 4-digit year or incomplete input)
                                        expireDates[index] = limited
                                    }
                                    
                                    // Clear error when user edits
                                    expireDateErrors.removeValue(forKey: index)
                                }
                            ))
                            .keyboardType(.numberPad)
                            
                            if let error = expireDateErrors[index] {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        expireDates.remove(atOffsets: indexSet)
                        // Clean up error states for removed indices
                        for index in indexSet {
                            expireDateErrors.removeValue(forKey: index)
                        }
                    }
                    
                    Button("film.addExpiryDate") {
                        expireDates.append("")
                    }
                }
                
                Section {
                    Toggle("film.isFrozen", isOn: $isFrozen)
                }
                
                Section("film.comments") {
                    TextEditor(text: $comments)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("film.editFilm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("action.cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("action.save") {
                        saveFilm()
                    }
                    .disabled(name.isEmpty || manufacturer.isEmpty)
                }
            }
            .fullScreenCover(isPresented: $showingImagePicker) {
                ZStack {
                    Color.black
                        .ignoresSafeArea(.all)
                    CustomCameraView(image: $rawSelectedImage, isPresented: $showingImagePicker)
                        .ignoresSafeArea(.all)
                }
            }
            .sheet(isPresented: $showingImageCatalog) {
                ImageCatalogView(selectedImage: $selectedImage, selectedImageFilename: $selectedCatalogFilename, selectedImageSource: $catalogSelectedSource)
            }
            .onChange(of: rawSelectedImage) { oldValue, newValue in
                if let newValue = newValue {
                    // Camera image is already cropped, use directly
                    selectedImage = newValue
                    imageSource = .custom
                    selectedCatalogFilename = nil
                    catalogSelectedSource = nil
                }
            }
            .onChange(of: catalogSelectedSource) { oldValue, newValue in
                // When an image is selected from the catalog view
                if let source = newValue {
                    imageSource = source
                }
            }
            .onChange(of: selectedImage) { oldValue, newValue in
                // Track if user cleared the selection
                if newValue == nil {
                    selectedCatalogFilename = nil
                    // Revert to auto-detected if there's a default image
                    if defaultImage != nil {
                        imageSource = .autoDetected
                    } else {
                        imageSource = .none
                    }
                }
            }
            .onChange(of: manufacturer) { oldValue, newValue in
                // Always try to load default image when manufacturer changes (for auto-detection)
                if !name.isEmpty && !newValue.isEmpty {
                    defaultImage = ImageStorage.shared.loadDefaultImage(filmName: name, manufacturer: newValue)
                } else {
                    defaultImage = nil
                }
            }
            .onChange(of: name) { oldValue, newValue in
                // Always try to load default image when name changes (for auto-detection)
                if !newValue.isEmpty && !manufacturer.isEmpty {
                    defaultImage = ImageStorage.shared.loadDefaultImage(filmName: newValue, manufacturer: manufacturer)
                } else {
                    defaultImage = nil
                }
            }
            .onAppear {
                loadFilmToEdit()
            }
        }
    }
    
    private func loadFilmToEdit() {
        // Find the first matching FilmStock from the groupedFilm
        // Use the first format's ID to find the matching film
        if let firstFormat = groupedFilm.formats.first {
            filmToEdit = dataManager.filmStocks.first { $0.id == firstFormat.id }
        }
        
        // If not found, try to find by matching criteria
        if filmToEdit == nil {
            filmToEdit = dataManager.filmStocks.first { film in
                film.name == groupedFilm.name &&
                film.manufacturer == groupedFilm.manufacturer &&
                film.type == groupedFilm.type &&
                film.filmSpeed == groupedFilm.filmSpeed
            }
        }
        
        // Pre-fill with existing film data
        if let film = filmToEdit {
            name = film.name
            manufacturer = film.manufacturer
            type = film.type
            filmSpeed = film.filmSpeed
            format = film.format
            // Use custom format name if available, otherwise use enum display name
            selectedFormatString = film.formatDisplayName
            quantity = film.quantity
            expireDates = film.expireDate ?? [""]
            if expireDates.isEmpty {
                expireDates = [""]
            }
            comments = film.comments ?? ""
            isFrozen = film.isFrozen
            
            // Load images based on image source
            let filmImageSource = ImageSource(rawValue: groupedFilm.imageSource) ?? .autoDetected
            imageSource = filmImageSource
            
            switch filmImageSource {
            case .custom:
                // Load custom user photo
                if let imageName = groupedFilm.imageName {
                    // Handle manufacturer/filename format (for catalog-selected photos)
                    let (manufacturer, filename) = parseCustomImageName(imageName, defaultManufacturer: film.manufacturer)
                    selectedImage = ImageStorage.shared.loadImage(filename: filename, manufacturer: manufacturer)
                    // Store the full path for later saving
                    selectedCatalogFilename = imageName.contains("/") ? imageName : nil
                }
                
            case .catalog:
                // Load catalog image
                if let catalogFilename = groupedFilm.imageName {
                    selectedImage = ImageStorage.shared.loadCatalogImage(filename: catalogFilename)
                    selectedCatalogFilename = catalogFilename
                }
                
            case .autoDetected:
                // Load auto-detected default image
                defaultImage = ImageStorage.shared.loadDefaultImage(filmName: film.name, manufacturer: film.manufacturer)
                
            case .none:
                // No image
                break
            }
        } else {
            // Fallback to groupedFilm data if no FilmStock found
            name = groupedFilm.name
            manufacturer = groupedFilm.manufacturer
            type = groupedFilm.type
            filmSpeed = groupedFilm.filmSpeed
            if let firstFormat = groupedFilm.formats.first {
                format = firstFormat.format
                quantity = firstFormat.quantity
                expireDates = firstFormat.expireDate ?? [""]
                if expireDates.isEmpty {
                    expireDates = [""]
                }
            }
        }
    }
    
    private func validateForm() -> Bool {
        var isValid = true
        
        // Clear all errors first
        nameError = nil
        expireDateErrors.removeAll()
        
        // Validate name
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            nameError = NSLocalizedString("error.nameEmpty", comment: "")
            isValid = false
        }
        
        // Validate expiry dates
        for (index, dateString) in expireDates.enumerated() {
            // Skip empty dates (they're optional)
            if dateString.isEmpty {
                continue
            }
            
            // Remove any slashes to check numeric content
            let numericOnly = dateString.filter { $0.isNumber }
            
            if numericOnly.count == 4 {
                // YYYY format - validate year
                guard let year = Int(numericOnly), year >= 1950, year <= 2100 else {
                    expireDateErrors[index] = NSLocalizedString("error.invalidYear", comment: "")
                    isValid = false
                    continue
                }
            } else if numericOnly.count == 6 {
                // MMYYYY format - validate month and year
                let monthStr = String(numericOnly.prefix(2))
                let yearStr = String(numericOnly.suffix(4))
                
                guard let month = Int(monthStr), let year = Int(yearStr) else {
                    expireDateErrors[index] = NSLocalizedString("error.invalidDate", comment: "")
                    isValid = false
                    continue
                }
                
                // Validate month (01-12)
                guard month >= 1 && month <= 12 else {
                    expireDateErrors[index] = NSLocalizedString("error.invalidMonth", comment: "")
                    isValid = false
                    continue
                }
                
                // Validate year (1950-2100)
                guard year >= 1950 && year <= 2100 else {
                    expireDateErrors[index] = NSLocalizedString("error.invalidYear", comment: "")
                    isValid = false
                    continue
                }
            } else {
                // Invalid length (not 4 or 6 digits)
                expireDateErrors[index] = NSLocalizedString("error.invalidDateFormat", comment: "")
                isValid = false
            }
        }
        
        return isValid
    }
    
    private func saveFilm() {
        // Validate form before saving
        guard validateForm() else {
            return
        }
        
        let filteredDates = expireDates.filter { !$0.isEmpty }
        
        // Handle image based on source
        var imageName: String? = nil
        let finalImageSource = imageSource
        
        switch imageSource {
        case .custom:
            // Check if user selected an existing custom photo from catalog or took a new one
            if let catalogFilename = selectedCatalogFilename {
                // User selected an existing custom photo - just reference it
                imageName = catalogFilename
            } else if let image = selectedImage {
                // User took a new photo - save it
                imageName = ImageStorage.shared.saveImage(image, forManufacturer: manufacturer, filmName: name)
            }
            
        case .catalog:
            // Store catalog image filename (don't save image, just reference it)
            imageName = selectedCatalogFilename
            
        case .autoDetected, .none:
            // No imageName needed - will auto-detect or show nothing
            imageName = nil
        }
        
        // Determine custom format name if using a custom format
        let customFormatName: String? = format == .other ? selectedFormatString : nil
        
        if let existingFilm = filmToEdit {
            // Update existing film - create new instance with updated values
            let updated = FilmStock(
                id: existingFilm.id,
                name: name,
                manufacturer: manufacturer,
                type: type,
                filmSpeed: filmSpeed,
                format: format,
                customFormatName: customFormatName,
                quantity: quantity,
                expireDate: filteredDates.isEmpty ? nil : filteredDates,
                comments: comments.isEmpty ? nil : comments,
                isFrozen: isFrozen,
                createdAt: existingFilm.createdAt,
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )
            
            dataManager.updateFilmStock(updated, imageName: imageName, imageSource: finalImageSource.rawValue)
            dismiss()
        } else {
            // If no film found, create a new one (shouldn't happen, but handle it)
            let film = FilmStock(
                id: UUID().uuidString,
                name: name,
                manufacturer: manufacturer,
                type: type,
                filmSpeed: filmSpeed,
                format: format,
                customFormatName: customFormatName,
                quantity: quantity,
                expireDate: filteredDates.isEmpty ? nil : filteredDates,
                comments: comments.isEmpty ? nil : comments,
                isFrozen: isFrozen,
                createdAt: ISO8601DateFormatter().string(from: Date()),
                updatedAt: nil
            )
            
            _ = dataManager.addFilmStock(film, imageName: imageName, imageSource: finalImageSource.rawValue)
            dismiss()
        }
    }
}

