//
//  EditFilmView.swift
//  FilmStock
//
//  Edit film view (iOS Form style)
//

import SwiftUI

struct EditFilmView: View {
    let groupedFilm: GroupedFilm
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
    @State private var filmToEdit: FilmStock?
    @State private var selectedImage: UIImage?
    @State private var defaultImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingImageCatalog = false
    @State private var rawSelectedImage: UIImage?
    @State private var useDefaultImage = false
    
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
                        .onChange(of: name) { oldValue, newValue in
                            // Load default image when name changes
                            if !newValue.isEmpty && !manufacturer.isEmpty {
                                defaultImage = ImageStorage.shared.loadDefaultImage(filmName: newValue, manufacturer: manufacturer)
                                if defaultImage != nil && selectedImage == nil {
                                    useDefaultImage = true
                                } else if defaultImage == nil && selectedImage == nil {
                                    useDefaultImage = false
                                }
                            } else {
                                defaultImage = nil
                                if selectedImage == nil {
                                    useDefaultImage = false
                                }
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
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Edit Film")
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
                ImageCatalogView(selectedImage: $selectedImage)
            }
            .onChange(of: rawSelectedImage) { oldValue, newValue in
                if let newValue = newValue {
                    // Camera image is already cropped, use directly
                    selectedImage = newValue
                    useDefaultImage = false
                }
            }
            .onChange(of: selectedImage) { oldValue, newValue in
                // When an image is uploaded, automatically select it
                if newValue != nil {
                    useDefaultImage = false
                }
            }
            .onChange(of: manufacturer) { oldValue, newValue in
                // Load default image when manufacturer changes
                if !name.isEmpty && !newValue.isEmpty {
                    defaultImage = ImageStorage.shared.loadDefaultImage(filmName: name, manufacturer: newValue)
                    if defaultImage != nil && selectedImage == nil {
                        useDefaultImage = true
                    } else if defaultImage == nil && selectedImage == nil {
                        useDefaultImage = false
                    }
                } else {
                    defaultImage = nil
                    if selectedImage == nil {
                        useDefaultImage = false
                    }
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
    
    private func saveFilm() {
        let filteredDates = expireDates.filter { !$0.isEmpty }
        
        // Save custom image if selected (not using default)
        var imageName: String? = nil
        if useDefaultImage {
            // Using default image - clear any custom image
            imageName = nil
        } else if let image = selectedImage {
            // Save new custom image
            imageName = ImageStorage.shared.saveImage(image, forManufacturer: manufacturer, filmName: name)
        } else {
            // No image selected - keep existing image if any
            if let existingFilm = filmToEdit {
                imageName = dataManager.getImageName(for: existingFilm)
            }
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
                quantity: quantity,
                expireDate: filteredDates.isEmpty ? nil : filteredDates,
                comments: comments.isEmpty ? nil : comments,
                createdAt: ISO8601DateFormatter().string(from: Date()),
                updatedAt: nil
            )
            
            Task {
                _ = await dataManager.addFilmStock(film)
                await MainActor.run {
                    dismiss()
                }
            }
        }
    }
}

