//
//  EditFilmView.swift
//  FilmStock
//
//  Edit film metadata and reminder image (per-roll expiry/frozen are edited in FilmDetailView)
//

import SwiftUI
import SwiftData

struct EditFilmView: View {
    let groupedFilm: GroupedFilm
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataManager: FilmStockDataManager

    @State private var name = ""
    @State private var manufacturer = ""
    @State private var type: FilmStock.FilmType = .bw
    @State private var filmSpeed = 400
    private let isoValues = [1, 2, 4, 5, 8, 10, 12, 16, 20, 25, 32, 40, 50, 64, 80, 100, 125,
                              160, 200, 250, 320, 400, 500, 640, 800, 1000, 1250, 1600, 2000,
                              2500, 3200, 6400]

    @State private var relatedFilms: [FilmStock] = []
    @State private var nameError: String?

    @State private var selectedImage: UIImage?
    @State private var defaultImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingImageCatalog = false
    @State private var rawSelectedImage: UIImage?
    @State private var existingImageFilename: String?
    @State private var selectedCatalogFilename: String?
    @State private var imageSource: ImageSource = .autoDetected
    @State private var catalogSelectedSource: ImageSource?

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
                        HStack {
                            Text("film.manufacturer")
                            Spacer()
                            if manufacturer.isEmpty {
                                Text("film.selectManufacturer")
                                    .foregroundColor(.secondary)
                            } else {
                                Text(manufacturer)
                                    .foregroundColor(.primary)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        TextField("film.name", text: $name)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .onSubmit {
                                UIApplication.shared.sendAction(
                                    #selector(UIResponder.resignFirstResponder),
                                    to: nil, from: nil, for: nil
                                )
                            }
                            .onChange(of: name) { _, _ in nameError = nil }
                        if let error = nameError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }

                    Picker("film.type", selection: $type) {
                        ForEach(FilmStock.FilmType.allCases, id: \.self) { filmType in
                            Text(filmType.displayName).tag(filmType)
                        }
                    }

                    Picker("film.speed", selection: $filmSpeed) {
                        ForEach(isoValues, id: \.self) { iso in
                            Text("ISO \(iso)").tag(iso)
                        }
                    }
                    .pickerStyle(.wheel)

                    // Film Reminder Image
                    VStack(alignment: .leading, spacing: 12) {
                        Text("film.filmReminder")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

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

                        if selectedImage != nil || defaultImage != nil {
                            HStack(spacing: 12) {
                                if let customImg = selectedImage {
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: customImg)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 100, height: 100)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(
                                                        imageSource == .custom || imageSource == .catalog
                                                            ? Color.accentColor : Color.clear,
                                                        lineWidth: 3
                                                    )
                                            )
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                imageSource = selectedCatalogFilename != nil ? .catalog : .custom
                                            }

                                        Button {
                                            selectedImage = nil
                                            selectedCatalogFilename = nil
                                            imageSource = defaultImage != nil ? .autoDetected : .none
                                        } label: {
                                            ZStack {
                                                Circle()
                                                    .fill(Color.black.opacity(0.6))
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.white)
                                                    .font(.system(size: 20))
                                            }
                                            .frame(width: 24, height: 24)
                                        }
                                        .buttonStyle(.plain)
                                        .offset(x: 4, y: -4)
                                        .zIndex(1)
                                    }
                                    .frame(width: 100, height: 100)
                                }

                                if let defImg = defaultImage {
                                    Image(uiImage: defImg)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 100, height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(
                                                    imageSource == .autoDetected ? Color.accentColor : Color.clear,
                                                    lineWidth: 3
                                                )
                                        )
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            imageSource = .autoDetected
                                        }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("film.editFilm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("action.save") {
                        if validateInputs() {
                            saveChanges()
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(name.isEmpty || manufacturer.isEmpty)
                }
            }
            .onAppear { loadInitialValues() }
            .sheet(isPresented: $showingImagePicker) {
                ImageSourcePicker(finalImage: $rawSelectedImage, isPresented: $showingImagePicker)
            }
            .sheet(isPresented: $showingImageCatalog) {
                ImageCatalogView(
                    selectedImage: $selectedImage,
                    selectedImageFilename: $selectedCatalogFilename,
                    selectedImageSource: $catalogSelectedSource
                )
            }
            .onChange(of: rawSelectedImage) { _, newValue in
                if let img = newValue {
                    selectedImage = img
                    imageSource = .custom
                    selectedCatalogFilename = nil
                    catalogSelectedSource = nil
                }
            }
            .onChange(of: catalogSelectedSource) { _, newValue in
                if let source = newValue { imageSource = source }
            }
            .onChange(of: selectedImage) { _, newValue in
                if newValue == nil {
                    selectedCatalogFilename = nil
                    imageSource = defaultImage != nil ? .autoDetected : .none
                }
            }
            .onChange(of: manufacturer) { _, newValue in
                if selectedImage == nil && !name.isEmpty && !newValue.isEmpty {
                    defaultImage = ImageStorage.shared.loadDefaultImage(filmName: name, manufacturer: newValue)
                }
            }
            .onChange(of: name) { _, newValue in
                if selectedImage == nil && !newValue.isEmpty && !manufacturer.isEmpty {
                    defaultImage = ImageStorage.shared.loadDefaultImage(filmName: newValue, manufacturer: manufacturer)
                }
            }
        }
    }

    private func loadInitialValues() {
        name = groupedFilm.name
        manufacturer = groupedFilm.manufacturer
        type = groupedFilm.type
        filmSpeed = groupedFilm.filmSpeed

        let filmImageSource = ImageSource(rawValue: groupedFilm.imageSource) ?? .autoDetected
        imageSource = filmImageSource

        switch filmImageSource {
        case .custom:
            if let imageName = groupedFilm.imageName {
                existingImageFilename = imageName
                let (mfr, filename) = ImageStorage.parseCustomImageName(imageName, defaultManufacturer: groupedFilm.manufacturer)
                selectedImage = ImageStorage.shared.loadImage(filename: filename, manufacturer: mfr)
            }
        case .catalog:
            if let imageName = groupedFilm.imageName {
                selectedCatalogFilename = imageName
                selectedImage = ImageStorage.shared.loadCatalogImage(filename: imageName)
            }
        case .autoDetected:
            defaultImage = ImageStorage.shared.loadDefaultImage(
                filmName: groupedFilm.name,
                manufacturer: groupedFilm.manufacturer
            )
        case .none:
            break
        }

        relatedFilms = dataManager.filmStocks.filter { film in
            film.name == groupedFilm.name &&
            film.manufacturer == groupedFilm.manufacturer &&
            film.type == groupedFilm.type &&
            film.filmSpeed == groupedFilm.filmSpeed
        }
    }

    private func validateInputs() -> Bool {
        nameError = nil
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            nameError = NSLocalizedString("error.nameEmpty", comment: "")
            return false
        }
        return true
    }

    private func saveChanges() {
        var newImageName: String? = nil
        let finalImageSource = imageSource

        switch finalImageSource {
        case .custom:
            if let catalogFilename = selectedCatalogFilename {
                newImageName = catalogFilename
                if let existingFilename = existingImageFilename, existingFilename != catalogFilename {
                    let (oldMfr, oldFile) = ImageStorage.parseCustomImageName(existingFilename, defaultManufacturer: groupedFilm.manufacturer)
                    ImageStorage.shared.deleteImage(filename: oldFile, manufacturer: oldMfr)
                }
            } else if let customImg = selectedImage {
                if let existingFilename = existingImageFilename {
                    let (oldMfr, oldFile) = ImageStorage.parseCustomImageName(existingFilename, defaultManufacturer: groupedFilm.manufacturer)
                    ImageStorage.shared.deleteImage(filename: oldFile, manufacturer: oldMfr)
                }
                newImageName = ImageStorage.shared.saveImage(customImg, forManufacturer: manufacturer, filmName: name)
            }
        case .catalog:
            if let existingFilename = existingImageFilename {
                let (oldMfr, oldFile) = ImageStorage.parseCustomImageName(existingFilename, defaultManufacturer: groupedFilm.manufacturer)
                ImageStorage.shared.deleteImage(filename: oldFile, manufacturer: oldMfr)
            }
            newImageName = selectedCatalogFilename
        case .autoDetected, .none:
            if let existingFilename = existingImageFilename {
                let (oldMfr, oldFile) = ImageStorage.parseCustomImageName(existingFilename, defaultManufacturer: groupedFilm.manufacturer)
                ImageStorage.shared.deleteImage(filename: oldFile, manufacturer: oldMfr)
            }
            newImageName = nil
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        // Update metadata on all related FilmStock entries (preserving each roll's own expiry, frozen, exposures, etc.)
        for (index, existing) in relatedFilms.enumerated() {
            let updated = FilmStock(
                id: existing.id,
                name: trimmedName,
                manufacturer: manufacturer,
                type: type,
                filmSpeed: filmSpeed,
                format: existing.format,
                customFormatName: existing.customFormatName,
                quantity: existing.quantity,
                expireDate: existing.expireDate,
                comments: existing.comments,
                isFrozen: existing.isFrozen,
                isFridge: existing.isFridge,
                exposures: existing.exposures,
                createdAt: existing.createdAt,
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )
            dataManager.updateFilmStock(
                updated,
                imageName: index == 0 ? newImageName : nil,
                imageSource: index == 0 ? finalImageSource.rawValue : nil
            )
        }

        // Reload to ensure UI reflects changes
        dataManager.loadFilmStocks()
    }
}
