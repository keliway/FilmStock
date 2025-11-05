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
    @State private var quantity = 0
    @State private var expireDates: [String] = [""]
    @State private var comments = ""
    @State private var selectedImage: UIImage?
    @State private var defaultImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingImageSourceDialog = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var showingCropView = false
    @State private var rawSelectedImage: UIImage?
    @State private var useDefaultImage = false
    
    // For editing
    var filmToEdit: FilmStock?
    
    init(filmToEdit: FilmStock? = nil) {
        self.filmToEdit = filmToEdit
    }
    
    var body: some View {
        NavigationStack {
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
                        .onChange(of: name) { oldValue, newValue in
                            // Load default image when name changes
                            if !newValue.isEmpty && !manufacturer.isEmpty {
                                defaultImage = ImageStorage.shared.loadDefaultImage(filmName: newValue, manufacturer: manufacturer)
                                if defaultImage == nil && selectedImage == nil {
                                    useDefaultImage = false
                                }
                            } else {
                                defaultImage = nil
                            }
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
                        
                        // Upload button - only show if no custom image is uploaded
                        if selectedImage == nil {
                            Button {
                                showingImageSourceDialog = true
                            } label: {
                                HStack {
                                    Image(systemName: "photo.on.rectangle")
                                    Text("Upload Image")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .confirmationDialog("Select Image Source", isPresented: $showingImageSourceDialog, titleVisibility: .visible) {
                                Button("Camera") {
                                    imageSourceType = .camera
                                    showingImagePicker = true
                                }
                                Button("Photo Library") {
                                    imageSourceType = .photoLibrary
                                    showingImagePicker = true
                                }
                                Button("Cancel", role: .cancel) {}
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
                                                    .stroke(useDefaultImage ? Color.clear : Color.accentColor, lineWidth: 3)
                                            )
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                useDefaultImage = false
                                            }
                                        
                                        Button(action: {
                                            self.selectedImage = nil
                                            if defaultImage != nil {
                                                useDefaultImage = true
                                            } else {
                                                useDefaultImage = false
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
                                                .stroke(useDefaultImage ? Color.accentColor : Color.clear, lineWidth: 3)
                                        )
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            useDefaultImage = true
                                        }
                                }
                            }
                            .contentShape(Rectangle())
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section("Quantity") {
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
            .fullScreenCover(isPresented: Binding(
                get: { showingImagePicker && imageSourceType == .camera },
                set: { if !$0 { showingImagePicker = false } }
            )) {
                ZStack {
                    Color.black
                        .ignoresSafeArea(.all)
                    CustomCameraView(image: $rawSelectedImage, isPresented: $showingImagePicker)
                        .ignoresSafeArea(.all)
                }
            }
            .sheet(isPresented: Binding(
                get: { showingImagePicker && imageSourceType == .photoLibrary },
                set: { if !$0 { showingImagePicker = false } }
            )) {
                PhotoLibraryPicker(image: $rawSelectedImage, isPresented: $showingImagePicker)
            }
            .sheet(isPresented: $showingCropView) {
                if let image = rawSelectedImage {
                    SquareCropView(image: image) { croppedImage in
                        selectedImage = croppedImage
                        useDefaultImage = false
                        showingCropView = false
                    }
                }
            }
            .onChange(of: rawSelectedImage) { oldValue, newValue in
                if let newValue = newValue {
                    if imageSourceType == .camera {
                        // For camera, image is already cropped, use directly
                        selectedImage = newValue
                        useDefaultImage = false
                    } else {
                        // For photo library, show crop view
                        showingCropView = true
                    }
                }
            }
            .onChange(of: selectedImage) { oldValue, newValue in
                // When an image is uploaded, automatically select it
                if newValue != nil {
                    useDefaultImage = false
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
                    
                    // Load images
                    defaultImage = ImageStorage.shared.loadDefaultImage(filmName: film.name, manufacturer: film.manufacturer)
                    
                    // Check if film has a custom image
                    if let imageName = dataManager.getImageName(for: film) {
                        selectedImage = ImageStorage.shared.loadImage(filename: imageName, manufacturer: film.manufacturer)
                        useDefaultImage = false
                    } else {
                        // Set selection state based on whether default image exists
                        if defaultImage != nil {
                            useDefaultImage = true
                        }
                    }
                } else {
                    // When adding new film, load default image if name/manufacturer are already set
                    if !name.isEmpty && !manufacturer.isEmpty {
                        defaultImage = ImageStorage.shared.loadDefaultImage(filmName: name, manufacturer: manufacturer)
                        if defaultImage != nil && selectedImage == nil {
                            useDefaultImage = true
                        }
                    }
                }
            }
            .onChange(of: manufacturer) { oldValue, newValue in
                // Load default image when manufacturer changes
                if !name.isEmpty && !newValue.isEmpty {
                    defaultImage = ImageStorage.shared.loadDefaultImage(filmName: name, manufacturer: newValue)
                    if defaultImage == nil && selectedImage == nil {
                        useDefaultImage = false
                    }
                } else {
                    defaultImage = nil
                }
            }
        }
    }
    
    private func saveFilm() {
        let filteredDates = expireDates.filter { !$0.isEmpty }
        
        // Save custom image if selected (not using default)
        var imageName: String? = nil
        if !useDefaultImage, let image = selectedImage {
            imageName = ImageStorage.shared.saveImage(image, forManufacturer: manufacturer, filmName: name)
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
            
            dataManager.updateFilmStock(updated, imageName: imageName)
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
            
            dataManager.addFilmStock(film, imageName: imageName)
        }
        
        dismiss()
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

