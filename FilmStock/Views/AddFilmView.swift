//
//  AddFilmView.swift
//  FilmStock
//
//  Add/Edit film view (iOS Form style)
//

import SwiftUI

struct AddFilmView: View {
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
        return formats
    }
    
    private func formatFromString(_ str: String) -> FilmStock.FilmFormat {
        if let builtIn = FilmStock.FilmFormat.allCases.first(where: { $0.displayName == str }) {
            return builtIn
        }
        return .other
    }
    @State private var quantity = 1
    @State private var expireDates: [String] = [""]
    @State private var comments = ""
    @State private var isFrozen = false
    @State private var selectedImage: UIImage?
    @State private var defaultImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingImageCatalog = false
    @State private var rawSelectedImage: UIImage?
    @State private var selectedCatalogFilename: String? // Tracks catalog image filename (e.g., "ilford_hp5")
    @State private var imageSource: ImageSource = .autoDetected
    @State private var catalogSelectedSource: ImageSource? // Tracks what was selected from catalog
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var hasAutoPopulatedMetadata = false // Track if we've auto-populated speed/type
    
    // Validation errors
    @State private var nameError: String?
    @State private var expireDateErrors: [Int: String] = [:]
    
    // For editing
    var filmToEdit: FilmStock?
    
    init(filmToEdit: FilmStock? = nil) {
        self.filmToEdit = filmToEdit
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
            Form {
                Section("film.filmInformation") {
                    NavigationLink {
                        ManufacturerPickerView(
                            selectedManufacturer: $manufacturer
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
                            .submitLabel(.done)
                            .onSubmit {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }
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
                
                Section {
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
                            .submitLabel(.done)
                            
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
                        .frame(height: 120)
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("action.done") {
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                }
                            }
                        }
                }
                }
                
                // Toast notification
                if showToast {
                    VStack {
                        Spacer()
                            .frame(height: 100)
                        HStack {
                            Spacer()
                            Text(toastMessage)
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.black.opacity(0.8))
                                .cornerRadius(8)
                                .padding(.horizontal, 16)
                            Spacer()
                        }
                        Spacer()
            }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut, value: showToast)
                }
            }
            .navigationTitle(filmToEdit == nil ? "film.addFilm" : "film.editFilm")
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
            .sheet(isPresented: $showingImagePicker) {
                ImageSourcePicker(finalImage: $rawSelectedImage, isPresented: $showingImagePicker)
            }
            .sheet(isPresented: $showingImageCatalog) {
                ImageCatalogView(selectedImage: $selectedImage, selectedImageFilename: $selectedCatalogFilename, selectedImageSource: $catalogSelectedSource)
            }
            .onChange(of: rawSelectedImage) { oldValue, newValue in
                if let newValue = newValue {
                    // Image from camera/library is already cropped, use directly
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
            .onAppear {
                if let film = filmToEdit {
                    // Pre-fill with existing film data
                    name = film.name
                    manufacturer = film.manufacturer
                    type = film.type
                    filmSpeed = film.filmSpeed
                    format = film.format
                    quantity = film.quantity
                    expireDates = film.expireDate ?? [""]
                    if expireDates.isEmpty {
                        expireDates = [""]
                    }
                    comments = film.comments ?? ""
                    isFrozen = film.isFrozen
                    
                    // Load default image for auto-detection
                    defaultImage = ImageStorage.shared.loadDefaultImage(filmName: film.name, manufacturer: film.manufacturer)
                    
                    // Set initial image source to auto-detected
                    if defaultImage != nil {
                        imageSource = .autoDetected
                    } else {
                        imageSource = .none
                    }
                } else {
                    // When adding new film, load default image if name/manufacturer are already set
                    if !name.isEmpty && !manufacturer.isEmpty {
                        defaultImage = ImageStorage.shared.loadDefaultImage(filmName: name, manufacturer: manufacturer)
                        if defaultImage != nil {
                            imageSource = .autoDetected
                        } else {
                            imageSource = .none
                        }
                    }
                }
            }
            .onChange(of: manufacturer) { oldValue, newValue in
                // Always try to load default image and metadata when manufacturer changes (for auto-detection)
                if !name.isEmpty && !newValue.isEmpty {
                    let metadata = ImageStorage.shared.detectFilmMetadata(filmName: name, manufacturer: newValue)
                    defaultImage = metadata.hasImage ? ImageStorage.shared.loadDefaultImage(filmName: name, manufacturer: newValue) : nil
                    
                    // Auto-populate speed and type if detected (only once, or when changing from one detected film to another)
                    if let detectedSpeed = metadata.filmSpeed {
                        filmSpeed = detectedSpeed
                        hasAutoPopulatedMetadata = true
                    }
                    if let detectedType = metadata.type {
                        // Map type string to FilmType enum
                        switch detectedType {
                        case "BW":
                            type = .bw
                        case "Color":
                            type = .color
                        case "Slide":
                            type = .slide
                        default:
                            break
                        }
                        hasAutoPopulatedMetadata = true
                    }
                } else {
                    defaultImage = nil
                }
            }
            .onChange(of: name) { oldValue, newValue in
                // Always try to load default image and metadata when name changes (for auto-detection)
                if !newValue.isEmpty && !manufacturer.isEmpty {
                    let metadata = ImageStorage.shared.detectFilmMetadata(filmName: newValue, manufacturer: manufacturer)
                    defaultImage = metadata.hasImage ? ImageStorage.shared.loadDefaultImage(filmName: newValue, manufacturer: manufacturer) : nil
                    
                    // Auto-populate speed and type if detected (only once, or when changing from one detected film to another)
                    if let detectedSpeed = metadata.filmSpeed {
                        filmSpeed = detectedSpeed
                        hasAutoPopulatedMetadata = true
                    }
                    if let detectedType = metadata.type {
                        // Map type string to FilmType enum
                        switch detectedType {
                        case "BW":
                            type = .bw
                        case "Color":
                            type = .color
                        case "Slide":
                            type = .slide
                        default:
                            break
                        }
                        hasAutoPopulatedMetadata = true
                    }
                } else {
                    defaultImage = nil
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
            // Add new film
            // If manufacturer doesn't exist, it will be created automatically in addFilmStock
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
        
        let wasUpdated = dataManager.addFilmStock(film, imageName: imageName, imageSource: finalImageSource.rawValue)
        if wasUpdated {
            toastMessage = "Film already existed and was updated"
            showToast = true
            
            // Dismiss after showing toast
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                dismiss()
            }
        } else {
            dismiss()
        }
    }
    }
}

struct ManufacturerPickerView: View {
    @EnvironmentObject var dataManager: FilmStockDataManager
    @Binding var selectedManufacturer: String
    @Environment(\.dismiss) var dismiss
    var allowAddingManufacturer: Bool = true
    @State private var searchText = ""
    @State private var showingAddManufacturer = false
    @State private var newManufacturerName = ""
    @State private var showDuplicateError = false
    @State private var showDeleteError = false
    
    var manufacturers: [Manufacturer] {
        dataManager.getAllManufacturers()
    }
    
    var filteredManufacturers: [Manufacturer] {
        if searchText.isEmpty {
            return manufacturers
        } else {
            return manufacturers.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var isDuplicate: Bool {
        let trimmedName = newManufacturerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return manufacturers.contains(where: { $0.name.localizedCaseInsensitiveEquals(trimmedName) })
    }
    
    var body: some View {
        List {
            // Existing manufacturers
            ForEach(filteredManufacturers, id: \.persistentModelID) { manufacturer in
                Button {
                    selectedManufacturer = manufacturer.name
                    dismiss()
                } label: {
                    HStack {
                        Text(manufacturer.name)
                        Spacer()
                        if selectedManufacturer == manufacturer.name {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if manufacturer.isCustom {
                        Button(role: .destructive) {
                            let success = dataManager.deleteManufacturer(manufacturer)
                            if !success {
                                showDeleteError = true
                            }
                        } label: {
                            Label("action.delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: Text("film.searchManufacturer"))
        .navigationTitle("film.selectManufacturer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if allowAddingManufacturer {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        newManufacturerName = ""
                        showingAddManufacturer = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .alert("manufacturer.add", isPresented: $showingAddManufacturer) {
            TextField("manufacturer.name", text: $newManufacturerName)
                .autocorrectionDisabled()
            Button("action.cancel", role: .cancel) {
                newManufacturerName = ""
            }
            Button("action.add") {
                let trimmedName = newManufacturerName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedName.isEmpty && !isDuplicate {
                    let newManufacturer = dataManager.addManufacturer(name: trimmedName)
                    selectedManufacturer = newManufacturer.name
                    dismiss()
                } else if isDuplicate {
                    showDuplicateError = true
                }
                newManufacturerName = ""
            }
            .disabled(newManufacturerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isDuplicate)
        } message: {
            if isDuplicate {
                Text("manufacturer.duplicateError")
            } else {
                Text("manufacturer.addMessage")
            }
        }
        .alert("manufacturer.duplicateTitle", isPresented: $showDuplicateError) {
            Button("action.ok", role: .cancel) { }
        } message: {
            Text("manufacturer.duplicateMessage")
        }
        .alert("manufacturer.deleteError", isPresented: $showDeleteError) {
            Button("action.ok", role: .cancel) { }
        } message: {
            Text("manufacturer.deleteErrorMessage")
        }
    }
}

extension String {
    func localizedCaseInsensitiveEquals(_ other: String) -> Bool {
        self.localizedCaseInsensitiveCompare(other) == .orderedSame
    }
}

