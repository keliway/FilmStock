//
//  EditFilmView.swift
//  FilmStock
//
//  Edits general film properties: name, manufacturer, type, ISO, and film reminder image.
//  Roll-specific properties (format, expiry, frozen, exposures) are managed via RollGroupEditSheet.
//

import SwiftUI

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

    @State private var name = ""
    @State private var manufacturer = ""
    @State private var type: FilmStock.FilmType = .bw
    @State private var filmSpeed = 400

    private let isoValues = [1, 2, 4, 5, 8, 10, 12, 16, 20, 25, 32, 40, 50, 64, 80, 100, 125,
                              160, 200, 250, 320, 400, 500, 640, 800, 1000, 1250, 1600, 2000,
                              2500, 3200, 6400]

    @State private var selectedImage: UIImage?
    @State private var defaultImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingImageCatalog = false
    @State private var rawSelectedImage: UIImage?
    @State private var selectedCatalogFilename: String?
    @State private var imageSource: ImageSource = .autoDetected
    @State private var catalogSelectedSource: ImageSource?

    @State private var nameError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("film.filmInformation") {
                    // Manufacturer
                    NavigationLink {
                        ManufacturerPickerView(
                            selectedManufacturer: $manufacturer,
                            allowAddingManufacturer: false
                        )
                        .environmentObject(dataManager)
                    } label: {
                        if manufacturer.isEmpty {
                            Text("film.selectManufacturer").foregroundColor(.secondary)
                        } else {
                            Text(manufacturer).foregroundColor(.primary)
                        }
                    }

                    // Name
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("film.name", text: $name)
                            .autocorrectionDisabled()
                            .onChange(of: name) { _, _ in nameError = nil }
                        if let error = nameError {
                            Text(error).font(.caption).foregroundColor(.red)
                        }
                    }

                    // Type
                    Picker("film.type", selection: $type) {
                        ForEach(FilmStock.FilmType.allCases, id: \.self) { t in
                            Text(t.displayName).tag(t)
                        }
                    }

                    // ISO speed
                    Picker("film.speed", selection: $filmSpeed) {
                        ForEach(isoValues, id: \.self) { iso in
                            Text("ISO \(iso)").tag(iso)
                        }
                    }
                    .pickerStyle(.wheel)

                    // Film reminder image
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
                                if let img = selectedImage {
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: img)
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
                                                Circle().fill(Color.black.opacity(0.6))
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
                                        .onTapGesture { imageSource = .autoDetected }
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
                        if validateAndSave() { dismiss() }
                    }
                    .fontWeight(.semibold)
                    .disabled(name.isEmpty || manufacturer.isEmpty)
                }
            }
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
                if !name.isEmpty && !newValue.isEmpty {
                    defaultImage = ImageStorage.shared.loadDefaultImage(filmName: name, manufacturer: newValue)
                }
            }
            .onChange(of: name) { _, newValue in
                if !newValue.isEmpty && !manufacturer.isEmpty {
                    defaultImage = ImageStorage.shared.loadDefaultImage(filmName: newValue, manufacturer: manufacturer)
                }
            }
            .onAppear { loadInitialValues() }
        }
    }

    // MARK: - Load

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
                let (mfr, filename) = parseCustomImageName(imageName, defaultManufacturer: groupedFilm.manufacturer)
                selectedImage = ImageStorage.shared.loadImage(filename: filename, manufacturer: mfr)
                selectedCatalogFilename = imageName.contains("/") ? imageName : nil
            }
        case .catalog:
            if let catalogFilename = groupedFilm.imageName {
                selectedImage = ImageStorage.shared.loadCatalogImage(filename: catalogFilename)
                selectedCatalogFilename = catalogFilename
            }
        case .autoDetected:
            defaultImage = ImageStorage.shared.loadDefaultImage(filmName: groupedFilm.name, manufacturer: groupedFilm.manufacturer)
        case .none:
            break
        }
    }

    // MARK: - Save

    @discardableResult
    private func validateAndSave() -> Bool {
        nameError = nil
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            nameError = NSLocalizedString("error.nameEmpty", comment: "")
            return false
        }

        var resolvedImageName: String? = nil
        let finalImageSource = imageSource

        switch finalImageSource {
        case .custom:
            if let catalogFilename = selectedCatalogFilename {
                resolvedImageName = catalogFilename
            } else if let img = selectedImage {
                resolvedImageName = ImageStorage.shared.saveImage(img, forManufacturer: manufacturer, filmName: name)
            }
        case .catalog:
            resolvedImageName = selectedCatalogFilename
        case .autoDetected, .none:
            resolvedImageName = nil
        }

        dataManager.updateFilmInfo(
            groupedFilm: groupedFilm,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            manufacturer: manufacturer,
            type: type,
            filmSpeed: filmSpeed,
            imageName: resolvedImageName,
            imageSource: finalImageSource.rawValue
        )
        return true
    }
}
