//
//  EditFilmView.swift
//  FilmStock
//
//  Edits general film properties: name, manufacturer, type, ISO, and film reminder image.
//  Roll-specific properties (format, expiry, frozen, exposures) are managed via RollGroupEditSheet.
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

    @State private var selectedImage: UIImage?
    @State private var defaultImage: UIImage?
    @State private var existingCustomImageKey: String?   // normalized "Manufacturer/filename" if film started with a custom photo
    @State private var selectedCatalogFilename: String?  // for .catalog: catalog key; for .custom: "Manufacturer/filename"
    @State private var didPickFreshCameraPhoto = false   // true only when user took/picked a brand-new photo in this session
    @State private var imageSource: ImageSource = .autoDetected

    @State private var nameError: String?
    @State private var hasLoaded = false

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
                        ForEach(FilmStock.standardISOValues, id: \.self) { iso in
                            Text("ISO \(iso)").tag(iso)
                        }
                    }
                    .pickerStyle(.wheel)

                    // Film reminder image
                    FilmReminderImageEditor(
                        selectedImage: $selectedImage,
                        defaultImage: defaultImage,
                        selectedCatalogFilename: $selectedCatalogFilename,
                        imageSource: $imageSource,
                        onCustomPhotoPicked: { didPickFreshCameraPhoto = true }
                    )
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
            .onAppear {
                guard !hasLoaded else { return }
                hasLoaded = true
                loadInitialValues()
            }
        }
    }

    // MARK: - Load

    private func loadInitialValues() {
        name = groupedFilm.name
        manufacturer = groupedFilm.manufacturer
        type = groupedFilm.type
        filmSpeed = groupedFilm.filmSpeed
        defaultImage = ImageStorage.shared.loadDefaultImage(filmName: groupedFilm.name, manufacturer: groupedFilm.manufacturer)

        let filmImageSource = ImageSource(rawValue: groupedFilm.imageSource) ?? .autoDetected
        imageSource = filmImageSource

        switch filmImageSource {
        case .custom:
            if let imageName = groupedFilm.imageName {
                let (mfr, filename) = ImageStorage.parseCustomImageName(imageName, defaultManufacturer: groupedFilm.manufacturer)
                let qualifiedKey = "\(mfr)/\(filename)"
                existingCustomImageKey = qualifiedKey
                selectedCatalogFilename = qualifiedKey
                selectedImage = ImageStorage.shared.loadImage(filename: filename, manufacturer: mfr)
            }
        case .catalog:
            if let catalogFilename = groupedFilm.imageName {
                selectedImage = ImageStorage.shared.loadCatalogImage(filename: catalogFilename)
                selectedCatalogFilename = catalogFilename
            }
        case .autoDetected, .none:
            break
        }
    }

    // MARK: - Save

    @discardableResult
    private func validateAndSave() -> Bool {
        nameError = nil
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            nameError = NSLocalizedString("error.nameEmpty", comment: "")
            return false
        }

        var resolvedImageName: String? = nil
        let finalImageSource = imageSource

        switch finalImageSource {
        case .custom:
            if let qualifiedFilename = selectedCatalogFilename, !didPickFreshCameraPhoto {
                // Existing custom photo (unchanged or picked from "My Photos"): keep its qualified
                // "Manufacturer/filename" reference — no re-compression, survives manufacturer changes.
                resolvedImageName = qualifiedFilename
            } else if let img = selectedImage,
                      let savedFile = ImageStorage.shared.saveImage(img, forManufacturer: manufacturer, filmName: trimmedName) {
                resolvedImageName = "\(manufacturer)/\(savedFile)"
            }
        case .catalog:
            resolvedImageName = selectedCatalogFilename
        case .autoDetected, .none:
            resolvedImageName = nil
        }

        // Update database first so reference counting sees the post-edit state
        dataManager.updateFilmInfo(
            groupedFilm: groupedFilm,
            name: trimmedName,
            manufacturer: manufacturer,
            type: type,
            filmSpeed: filmSpeed,
            imageName: resolvedImageName,
            imageSource: finalImageSource.rawValue
        )

        // Only delete the previous custom photo file if this edit stopped using it AND no other film references it
        if let oldKey = existingCustomImageKey, oldKey != resolvedImageName {
            dataManager.deleteCustomImageIfUnreferenced(imageName: oldKey, defaultManufacturer: groupedFilm.manufacturer)
        }

        return true
    }
}
