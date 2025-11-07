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
    
    @State private var name = ""
    @State private var manufacturer = ""
    @State private var type: FilmStock.FilmType = .bw
    @State private var filmSpeed = 400
    
    private let isoValues = [1, 2, 4, 5, 8, 10, 12, 16, 20, 25, 32, 40, 50, 64, 80, 100, 125, 160, 200, 250, 320, 400, 500, 640, 800, 1000, 1250, 1600, 2000, 2500, 3200, 6400]
    @State private var format: FilmStock.FilmFormat = .thirtyFive
    @State private var quantity = 1
    @State private var expireDates: [String] = [""]
    @State private var comments = ""
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
    
    // For editing
    var filmToEdit: FilmStock?
    
    init(filmToEdit: FilmStock? = nil) {
        self.filmToEdit = filmToEdit
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
            Form {
                Section("Film Information") {
                    NavigationLink {
                        ManufacturerPickerView(
                            selectedManufacturer: $manufacturer
                        )
                        .environmentObject(dataManager)
                    } label: {
                        Text(manufacturer.isEmpty ? "Select Manufacturer" : manufacturer)
                            .foregroundColor(manufacturer.isEmpty ? .secondary : .primary)
                    }
                    
                    TextField("Name", text: $name)
                        .submitLabel(.done)
                        .onSubmit {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                    
                    Picker("Type", selection: $type) {
                        ForEach(FilmStock.FilmType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    
                    Picker("Speed", selection: $filmSpeed) {
                        ForEach(isoValues, id: \.self) { iso in
                            Text("ISO \(iso)").tag(iso)
                        }
                    }
                    .pickerStyle(.wheel)
                    
                    Picker("Format", selection: $format) {
                        ForEach(FilmStock.FilmFormat.allCases, id: \.self) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    
                    // Image selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Film reminder")
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
                                        Text("Take Photo")
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
                                        Text("Open Catalog")
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
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 0...999)
                }
                
                Section("Expire Dates") {
                    ForEach(expireDates.indices, id: \.self) { index in
                        TextField("MM/YYYY or YYYY", text: Binding(
                            get: { expireDates[index] },
                            set: { expireDates[index] = $0 }
                        ))
                        .submitLabel(.done)
                        .onSubmit {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                    }
                    .onDelete { indexSet in
                        expireDates.remove(atOffsets: indexSet)
                    }
                    
                    Button("Add Date") {
                        expireDates.append("")
                    }
                }
                
                Section("Comments") {
                    TextEditor(text: $comments)
                        .frame(height: 120)
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("Done") {
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
            .navigationTitle(filmToEdit == nil ? "Add Film" : "Edit Film")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
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
        }
    }
    
    private func saveFilm() {
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
        
        if let existingFilm = filmToEdit {
            // Update existing film - create new instance with updated values
            let updated = FilmStock(
                id: existingFilm.id,
                name: name,
                manufacturer: manufacturer,
                type: type,
                filmSpeed: filmSpeed,
                format: format,
                quantity: quantity,
                expireDate: filteredDates.isEmpty ? nil : filteredDates,
                comments: comments.isEmpty ? nil : comments,
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
            quantity: quantity,
                expireDate: filteredDates.isEmpty ? nil : filteredDates,
            comments: comments.isEmpty ? nil : comments,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: nil
        )
        
            Task {
                let wasUpdated = await dataManager.addFilmStock(film, imageName: imageName, imageSource: finalImageSource.rawValue)
                await MainActor.run {
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
    }
}

struct ManufacturerPickerView: View {
    @EnvironmentObject var dataManager: FilmStockDataManager
    @Binding var selectedManufacturer: String
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    
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
    
    var body: some View {
        List {
            // Option to add new manufacturer
            if !searchText.isEmpty && !manufacturers.contains(where: { $0.name.localizedCaseInsensitiveEquals(searchText) }) {
                Section {
                    Button {
                        let newManufacturer = dataManager.addManufacturer(name: searchText)
                        selectedManufacturer = newManufacturer.name
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.accentColor)
                            Text("Add \"\(searchText)\"")
                        }
                    }
                }
            }
            
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
            }
        }
        .searchable(text: $searchText, prompt: "Search or add manufacturer")
        .navigationTitle("Select Manufacturer")
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension String {
    func localizedCaseInsensitiveEquals(_ other: String) -> Bool {
        self.localizedCaseInsensitiveCompare(other) == .orderedSame
    }
}

