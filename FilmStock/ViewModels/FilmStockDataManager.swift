//
//  FilmStockDataManager.swift
//  FilmStock
//
//  Data Management using SwiftData
//

import Foundation
import SwiftUI
import SwiftData
import Combine
import WidgetKit

@MainActor
class FilmStockDataManager: ObservableObject {
    @Published var filmStocks: [FilmStock] = []
    
    private var modelContext: ModelContext?
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        loadFilmStocks()
    }
    
    func migrateIfNeeded() async {
        guard let context = modelContext else { return }
        
        // Copy default images to App Group container for widget access (runs once)
        ImageStorage.shared.copyDefaultImagesToAppGroup()
        
        // Load manufacturers from bundle
        await loadManufacturers(context: context)
    }
    
    private func loadManufacturers(context: ModelContext) async {
        // Check if manufacturers already exist
        let descriptor = FetchDescriptor<Manufacturer>()
        if let existing = try? context.fetch(descriptor), !existing.isEmpty {
            return // Already loaded
        }
        
        // Load from manufacturers.json
        var bundleData: Data?
        if let bundleURL = Bundle.main.url(forResource: "manufacturers", withExtension: "json") {
            bundleData = try? Data(contentsOf: bundleURL)
        }
        
        guard let data = bundleData else { return }
        
        do {
            let decoder = JSONDecoder()
            let wrapper = try decoder.decode(ImageStorage.ManufacturersDataWrapper.self, from: data)
            
            for manufacturerInfo in wrapper.manufacturers {
                let manufacturer = Manufacturer(name: manufacturerInfo.name, isCustom: false)
                context.insert(manufacturer)
            }
            
            try context.save()
        } catch {
            // Failed to load manufacturers
        }
    }
    
    func loadFilmStocks() {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<MyFilm>()
        guard let myFilms = try? context.fetch(descriptor) else {
            filmStocks = []
                return
        }
        
        // Convert MyFilm to FilmStock for compatibility
        filmStocks = myFilms.compactMap { myFilm -> FilmStock? in
            guard let film = myFilm.film,
                  let type = FilmStock.FilmType(rawValue: film.type),
                  let format = FilmStock.FilmFormat(rawValue: myFilm.format) else {
                return nil
            }
            
            return FilmStock(
                id: myFilm.id,
                name: film.name,
                manufacturer: film.manufacturer?.name ?? "",
                type: type,
                filmSpeed: film.filmSpeed,
                format: format,
                quantity: myFilm.quantity,
                expireDate: myFilm.expireDateArray,
                comments: myFilm.comments,
                isFrozen: myFilm.isFrozen ?? false,
                createdAt: myFilm.createdAt,
                updatedAt: myFilm.updatedAt
            )
        }
    }
    
    func addFilmStock(_ filmStock: FilmStock, imageName: String? = nil, imageSource: String = ImageSource.autoDetected.rawValue) -> Bool {
        guard let context = modelContext else { return false }
        
        // Find or create manufacturer
        let manufacturer = findOrCreateManufacturer(name: filmStock.manufacturer, context: context)
        
        // Check if a film with the same name + manufacturer exists (regardless of ISO)
        let descriptor = FetchDescriptor<Film>()
        let allFilms = (try? context.fetch(descriptor)) ?? []
        
        if let existingFilm = allFilms.first(where: { film in
            film.name == filmStock.name &&
            film.manufacturer?.name == filmStock.manufacturer
        }) {
            // Film with same name + manufacturer exists
            // Check if ISO matches
            if existingFilm.filmSpeed == filmStock.filmSpeed &&
               existingFilm.type == filmStock.type.rawValue {
                // ISO matches - update existing film
                // Update image if provided
                if let imageName = imageName {
                    existingFilm.imageName = imageName
                    existingFilm.imageSource = imageSource
                }
                
                // Check if a MyFilm entry with the same format already exists
                if let myFilms = existingFilm.myFilms,
                   let existingMyFilm = myFilms.first(where: { $0.format == filmStock.format.rawValue }) {
                    // Update existing MyFilm entry - ADD quantity, MERGE expiry dates
                    existingMyFilm.quantity += filmStock.quantity
                    existingMyFilm.customFormatName = filmStock.customFormatName
                    
                    // Merge expiry dates - add new ones without duplicates
                    var existingDates = existingMyFilm.expireDateArray ?? []
                    if let newDates = filmStock.expireDate {
                        for newDate in newDates where !newDate.isEmpty {
                            if !existingDates.contains(newDate) {
                                existingDates.append(newDate)
                            }
                        }
                    }
                    existingMyFilm.expireDateArray = existingDates.isEmpty ? nil : existingDates
                    
                    // Only update comments if new comments are provided
                    if let newComments = filmStock.comments, !newComments.isEmpty {
                        existingMyFilm.comments = newComments
                    }
                    existingMyFilm.isFrozen = filmStock.isFrozen
                    existingMyFilm.updatedAt = ISO8601DateFormatter().string(from: Date())
                } else {
                    // Create new MyFilm entry for this format
                    let myFilm = MyFilm(
                        id: filmStock.id,
                        format: filmStock.format.rawValue,
                        customFormatName: filmStock.customFormatName,
                        quantity: filmStock.quantity,
                        expireDate: filmStock.expireDate,
                        comments: filmStock.comments,
                        isFrozen: filmStock.isFrozen,
                        createdAt: filmStock.createdAt,
                        updatedAt: filmStock.updatedAt,
                        film: nil  // Don't set relationship in initializer
                    )
                    context.insert(myFilm)
                    myFilm.film = existingFilm  // Establish relationship after insertion
                }
                
                try? context.save()
                loadFilmStocks()
                
                return true // Film was updated
            } else {
                // ISO doesn't match - create new film
                let film = findOrCreateFilm(
                    name: filmStock.name,
                    manufacturer: manufacturer,
                    type: filmStock.type.rawValue,
                    filmSpeed: filmStock.filmSpeed,
                    imageName: imageName,
                    imageSource: imageSource,
                    context: context
                )
                
                // Create MyFilm entry
                let myFilm = MyFilm(
                    id: filmStock.id,
                    format: filmStock.format.rawValue,
                    customFormatName: filmStock.customFormatName,
                    quantity: filmStock.quantity,
                    expireDate: filmStock.expireDate,
                    comments: filmStock.comments,
                    isFrozen: filmStock.isFrozen,
                    createdAt: filmStock.createdAt,
                    updatedAt: filmStock.updatedAt,
                    film: nil  // Don't set relationship in initializer
                )
                
                context.insert(myFilm)
                myFilm.film = film  // Establish relationship after insertion
                try? context.save()
                loadFilmStocks()
                
                return false // Film was created
            }
        } else {
            // No existing film with same name + manufacturer - create new film
            let film = findOrCreateFilm(
                name: filmStock.name,
                manufacturer: manufacturer,
                type: filmStock.type.rawValue,
                filmSpeed: filmStock.filmSpeed,
                imageName: imageName,
                imageSource: imageSource,
                context: context
            )
            
            // Create MyFilm entry
            let myFilm = MyFilm(
                id: filmStock.id,
                format: filmStock.format.rawValue,
                customFormatName: filmStock.customFormatName,
                quantity: filmStock.quantity,
                expireDate: filmStock.expireDate,
                comments: filmStock.comments,
                isFrozen: filmStock.isFrozen,
                createdAt: filmStock.createdAt,
                updatedAt: filmStock.updatedAt,
                film: nil  // Don't set relationship in initializer
            )
            
            context.insert(myFilm)
            myFilm.film = film  // Establish relationship after insertion
            try? context.save()
            loadFilmStocks()
            
            return false // Film was created
        }
    }
    
    func updateFilmStock(_ filmStock: FilmStock, imageName: String? = nil, imageSource: String = ImageSource.autoDetected.rawValue) {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<MyFilm>(
            predicate: #Predicate { $0.id == filmStock.id }
        )
        
        guard let myFilm = try? context.fetch(descriptor).first,
              let film = myFilm.film else { return }
        
        // Update Film entity properties
        film.name = filmStock.name
        film.type = filmStock.type.rawValue
        film.filmSpeed = filmStock.filmSpeed
        
        // Update manufacturer if it changed
        if film.manufacturer?.name != filmStock.manufacturer {
            // Find or create the new manufacturer
            let manufacturerDescriptor = FetchDescriptor<Manufacturer>(
                predicate: #Predicate { $0.name == filmStock.manufacturer }
            )
            
            let manufacturer: Manufacturer
            if let existing = try? context.fetch(manufacturerDescriptor).first {
                manufacturer = existing
            } else {
                manufacturer = Manufacturer(name: filmStock.manufacturer, isCustom: true)
                context.insert(manufacturer)
    }
    
            film.manufacturer = manufacturer
        }
        
        // Update film's imageName (can be nil to clear it)
        // Check if imageName parameter was explicitly provided (not just default nil)
        // We'll use a different approach: always update if imageName is provided in the call
        // For now, we need to distinguish between "don't change" and "clear"
        // Since we can't do that with optional, we'll always update when called from EditFilmView
        // which always passes imageName (either a value or nil)
        
        // Update imageName and imageSource (custom photos are kept, user can delete manually)
        film.imageName = imageName
        film.imageSource = imageSource
        
        // Update MyFilm
        myFilm.quantity = filmStock.quantity
        myFilm.expireDateArray = filmStock.expireDate
        myFilm.comments = filmStock.comments
        myFilm.isFrozen = filmStock.isFrozen
        myFilm.updatedAt = ISO8601DateFormatter().string(from: Date())
        
        // If format changed, we need to update it
        if myFilm.format != filmStock.format.rawValue {
            myFilm.format = filmStock.format.rawValue
        }
        
        // Always update customFormatName (can be nil for built-in formats)
        myFilm.customFormatName = filmStock.customFormatName
        
        try? context.save()
        loadFilmStocks()
    }
    
    func deleteFilmStock(_ filmStock: FilmStock) {
        deleteFilmStocks([filmStock])
    }
    
    func isFilmLoaded(_ filmStock: FilmStock) -> Bool {
        guard let context = modelContext else { return false }
        
        // Fetch all LoadedFilm entries
        let loadedFilmDescriptor = FetchDescriptor<LoadedFilm>()
        guard let loadedFilms = try? context.fetch(loadedFilmDescriptor) else { return false }
        
        // Check if any loaded film matches this film
        return loadedFilms.contains { loadedFilm in
            guard let film = loadedFilm.film else { return false }
            return film.name == filmStock.name &&
                   film.manufacturer?.name == filmStock.manufacturer &&
                   film.type == filmStock.type.rawValue &&
                   film.filmSpeed == filmStock.filmSpeed
        }
    }
    
    func deleteFilmStocks(_ filmStocks: [FilmStock]) {
        guard let context = modelContext else { return }
        guard !filmStocks.isEmpty else { return }
        
        // Fetch all MyFilm entries
        let myFilmDescriptor = FetchDescriptor<MyFilm>()
        guard let allMyFilms = try? context.fetch(myFilmDescriptor) else { return }
        
        // Fetch all Film entries
        let filmDescriptor = FetchDescriptor<Film>()
        guard let allFilms = try? context.fetch(filmDescriptor) else { return }
        
        // Track which films we're deleting MyFilms from and which MyFilms are being deleted
        var filmsToCheck: Set<PersistentIdentifier> = []
        var deletedMyFilmIds: Set<String> = []
        
        // Find and delete all matching MyFilms from the database
        for filmStock in filmStocks {
            let myFilmsToDelete = allMyFilms.filter { myFilm in
                guard let film = myFilm.film else { return false }
                return film.name == filmStock.name &&
                       film.manufacturer?.name == filmStock.manufacturer &&
                       film.type == filmStock.type.rawValue &&
                       film.filmSpeed == filmStock.filmSpeed
            }
            
            for myFilm in myFilmsToDelete {
                if let film = myFilm.film {
                    filmsToCheck.insert(film.persistentModelID)
                }
                deletedMyFilmIds.insert(myFilm.id)
                context.delete(myFilm)
            }
        }
        
        // Check if any Films now have zero MyFilm entries and delete them
        for filmId in filmsToCheck {
            if let film = allFilms.first(where: { $0.persistentModelID == filmId }) {
                // Check if this film has any remaining MyFilms (excluding the ones we just deleted)
                let remainingMyFilms = allMyFilms.filter { myFilm in
                    guard let myFilmFilm = myFilm.film else { return false }
                    return myFilmFilm.persistentModelID == filmId && !deletedMyFilmIds.contains(myFilm.id)
                }
                
                // If no MyFilms remain for this film, delete the Film entity too
                if remainingMyFilms.isEmpty {
                    context.delete(film)
                }
            }
        }
        
        // Save to database and reload immediately
        if (try? context.save()) != nil {
            loadFilmStocks()
        }
    }
    
    func groupedFilms() -> [GroupedFilm] {
        guard let context = modelContext else { return [] }
        
        let descriptor = FetchDescriptor<Film>()
        guard let films = try? context.fetch(descriptor) else { return [] }
        
        var groups: [String: GroupedFilm] = [:]
        
        for film in films {
            guard let manufacturer = film.manufacturer,
                  let type = FilmStock.FilmType(rawValue: film.type) else {
                continue
            }
            
            let key = "\(film.name)_\(manufacturer.name)_\(film.type)_\(film.filmSpeed)"
            
            if groups[key] == nil {
                // Use first MyFilm ID as the group ID for stability
                let firstMyFilmId = film.myFilms?.first?.id ?? UUID().uuidString
                groups[key] = GroupedFilm(
                    id: firstMyFilmId,
                    name: film.name,
                    manufacturer: manufacturer.name,
                    type: type,
                    filmSpeed: film.filmSpeed,
                    imageName: film.imageName,
                    imageSource: film.imageSource,
                    formats: []
                )
            }
            
            // Get all MyFilm entries for this film
            if let myFilms = film.myFilms {
                for myFilm in myFilms {
                    if let format = FilmStock.FilmFormat(rawValue: myFilm.format) {
            groups[key]?.formats.append(GroupedFilm.FormatInfo(
                            id: myFilm.id,
                            format: format,
                            customFormatName: myFilm.customFormatName,
                            quantity: myFilm.quantity,
                            expireDate: myFilm.expireDateArray,
                            isFrozen: myFilm.isFrozen ?? false,
                            filmId: myFilm.id
            ))
                    }
                }
            }
        }
        
        return Array(groups.values).sorted { film1, film2 in
            if film1.manufacturer != film2.manufacturer {
                return film1.manufacturer < film2.manufacturer
            }
            return film1.name < film2.name
        }
    }
    
    // MARK: - Manufacturer Management
    
    func getAllManufacturers() -> [Manufacturer] {
        guard let context = modelContext else { return [] }
        
        // Fetch all manufacturers
        let manufacturerDescriptor = FetchDescriptor<Manufacturer>()
        guard let allManufacturers = try? context.fetch(manufacturerDescriptor) else { return [] }
        
        // Fetch all films to count usage
        let filmDescriptor = FetchDescriptor<Film>()
        let allFilms = (try? context.fetch(filmDescriptor)) ?? []
        
        // Count total quantity for each manufacturer
        var manufacturerUsage: [String: Int] = [:]
        for film in allFilms {
            guard let manufacturerName = film.manufacturer?.name else { continue }
            let totalQuantity = film.myFilms?.reduce(0) { $0 + $1.quantity } ?? 0
            manufacturerUsage[manufacturerName, default: 0] += totalQuantity
        }
        
        // Define pinned manufacturers (case-insensitive matching)
        let pinnedNames = ["Kodak", "Ilford", "Fomapan", "Cinestill"]
        
        // Separate pinned and unpinned manufacturers
        var pinned: [Manufacturer] = []
        var unpinned: [Manufacturer] = []
        
        for manufacturer in allManufacturers {
            if pinnedNames.contains(where: { $0.localizedCaseInsensitiveCompare(manufacturer.name) == .orderedSame }) {
                pinned.append(manufacturer)
            } else {
                unpinned.append(manufacturer)
            }
        }
        
        // Sort pinned manufacturers in the order they appear in pinnedNames array
        pinned.sort { m1, m2 in
            let index1 = pinnedNames.firstIndex { $0.localizedCaseInsensitiveCompare(m1.name) == .orderedSame } ?? Int.max
            let index2 = pinnedNames.firstIndex { $0.localizedCaseInsensitiveCompare(m2.name) == .orderedSame } ?? Int.max
            return index1 < index2
        }
        
        // Sort unpinned manufacturers by usage (most frequent first), then alphabetically
        unpinned.sort { m1, m2 in
            let usage1 = manufacturerUsage[m1.name] ?? 0
            let usage2 = manufacturerUsage[m2.name] ?? 0
            if usage1 != usage2 {
                return usage1 > usage2 // Most used first
            }
            return m1.name < m2.name // Alphabetical for same usage
        }
        
        // Combine: pinned first, then unpinned
        return pinned + unpinned
    }
    
    func addManufacturer(name: String) -> Manufacturer {
        guard let context = modelContext else {
            return Manufacturer(name: name, isCustom: true)
        }
        
        let manufacturer = Manufacturer(name: name, isCustom: true)
        context.insert(manufacturer)
        try? context.save()
        return manufacturer
    }
    
    func deleteManufacturer(_ manufacturer: Manufacturer) -> Bool {
        guard let context = modelContext else { return false }
        
        // Only allow deletion of custom manufacturers
        guard manufacturer.isCustom else { return false }
        
        // Check if any films use this manufacturer - fetch all and filter in memory
        let descriptor = FetchDescriptor<Film>()
        let allFilms = (try? context.fetch(descriptor)) ?? []
        
        let filmsUsingManufacturer = allFilms.filter { film in
            film.manufacturer?.name == manufacturer.name
        }
        
        if !filmsUsingManufacturer.isEmpty {
            // Don't delete if films are using it
            return false
        }
        
        context.delete(manufacturer)
        try? context.save()
        return true
    }
    
    // MARK: - Helper Methods
    
    private func findOrCreateManufacturer(name: String, context: ModelContext) -> Manufacturer {
        let descriptor = FetchDescriptor<Manufacturer>(
            predicate: #Predicate { $0.name == name }
        )
        
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        
        let manufacturer = Manufacturer(name: name, isCustom: true)
        context.insert(manufacturer)
        // Don't save here - save will happen after all relationships are established
        return manufacturer
    }
    
    private func findOrCreateFilm(name: String, manufacturer: Manufacturer, type: String, filmSpeed: Int, imageName: String? = nil, imageSource: String = ImageSource.autoDetected.rawValue, context: ModelContext) -> Film {
        // Fetch all films and filter in memory to avoid complex predicate issues
        let descriptor = FetchDescriptor<Film>()
        let allFilms = (try? context.fetch(descriptor)) ?? []
        
        // Find existing film matching criteria
        if let existing = allFilms.first(where: { film in
            film.name == name &&
            film.manufacturer?.name == manufacturer.name &&
            film.type == type &&
            film.filmSpeed == filmSpeed
        }) {
            // Update imageName and imageSource if provided
            if let imageName = imageName {
                existing.imageName = imageName
                existing.imageSource = imageSource
                try? context.save()
            }
            return existing
        }
        
        let film = Film(
            name: name,
            manufacturer: nil,  // Don't set relationship in initializer
            type: type,
            filmSpeed: filmSpeed,
            imageName: imageName,
            imageSource: imageSource
        )
        context.insert(film)
        // Now establish the relationship after both objects are in the context
        film.manufacturer = manufacturer
        try? context.save()
        return film
    }
    
    /// Get the imageName for a FilmStock
    func getImageName(for filmStock: FilmStock) -> String? {
        guard let context = modelContext else { return nil }
        
        let descriptor = FetchDescriptor<MyFilm>(
            predicate: #Predicate { $0.id == filmStock.id }
        )
        
        guard let myFilm = try? context.fetch(descriptor).first,
              let film = myFilm.film else {
            return nil
        }
        
        return film.imageName
    }
    
    // MARK: - Camera Management
    
    func getAllCameras() -> [Camera] {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<Camera>(
            sortBy: [SortDescriptor(\.name)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    func addCamera(name: String) -> Camera {
        guard let context = modelContext else {
            return Camera(name: name)
        }
        
        // Check if camera already exists
        let descriptor = FetchDescriptor<Camera>(
            predicate: #Predicate { $0.name == name }
        )
        
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        
        let camera = Camera(name: name)
        context.insert(camera)
        try? context.save()
        return camera
    }
    
    func deleteCamera(_ camera: Camera) -> Bool {
        guard let context = modelContext else { return false }
        
        // Check if any loaded films use this camera
        let descriptor = FetchDescriptor<LoadedFilm>()
        let allLoadedFilms = (try? context.fetch(descriptor)) ?? []
        
        let filmsUsingCamera = allLoadedFilms.filter { loadedFilm in
            loadedFilm.camera?.name == camera.name
        }
        
        if !filmsUsingCamera.isEmpty {
            // Don't delete if films are loaded in this camera
            return false
        }
        
        context.delete(camera)
        try? context.save()
        return true
    }
    
    // MARK: - Loaded Film Management
    
    func getLoadedFilms() -> [LoadedFilm] {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<LoadedFilm>(
            sortBy: [SortDescriptor(\.loadedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    func loadFilm(filmStockId: String, format: FilmStock.FilmFormat, cameraName: String, quantity: Int = 1) -> Bool {
        guard let context = modelContext else { return false }
        
        // Get the MyFilm entry - filmStockId is the MyFilm.id
        let myFilmDescriptor = FetchDescriptor<MyFilm>(
            predicate: #Predicate { $0.id == filmStockId }
        )
        
        guard let myFilm = try? context.fetch(myFilmDescriptor).first,
              myFilm.format == format.rawValue,
              myFilm.quantity >= quantity,
              quantity > 0,
              let film = myFilm.film else {
            return false
        }
        
        // Check if already at max (5 films)
        let loadedFilmsDescriptor = FetchDescriptor<LoadedFilm>()
        let allLoadedFilms = (try? context.fetch(loadedFilmsDescriptor)) ?? []
        if allLoadedFilms.count >= 5 {
            return false
        }
        
        // Find or create camera
        let cameraDescriptor = FetchDescriptor<Camera>(
            predicate: #Predicate { $0.name == cameraName }
        )
        
        var camera: Camera
        if let existing = try? context.fetch(cameraDescriptor).first {
            camera = existing
        } else {
            camera = Camera(name: cameraName)
            context.insert(camera)
        }
        
        // Create loaded film entry - don't set relationships in initializer
        let loadedFilm = LoadedFilm(
            id: UUID().uuidString,
            film: nil,
            format: format.rawValue,
            camera: nil,
            myFilm: nil,
            quantity: quantity
        )
        context.insert(loadedFilm)
        // Establish relationships after insertion
        loadedFilm.film = film
        loadedFilm.camera = camera
        loadedFilm.myFilm = myFilm
        
        // Decrease quantity by the amount loaded
        myFilm.quantity = max(0, myFilm.quantity - quantity)
        
        try? context.save()
        loadFilmStocks() // Refresh the list
        NotificationCenter.default.post(name: NSNotification.Name("LoadedFilmsChanged"), object: nil)
        WidgetCenter.shared.reloadTimelines(ofKind: "LoadedFilmsWidget")
        return true
    }
    
    func unloadFilm(_ loadedFilm: LoadedFilm, quantity: Int? = nil) {
        guard let context = modelContext else { return }
        
        // Track finished films count
        let quantityFinished: Int
        
        // If quantity is specified, unload only that amount
        if let quantityToUnload = quantity {
            quantityFinished = min(quantityToUnload, loadedFilm.quantity)
            // Decrease the loaded quantity
            loadedFilm.quantity = max(0, loadedFilm.quantity - quantityToUnload)
            
            // If quantity reaches 0, delete the loaded film entry
            if loadedFilm.quantity == 0 {
                context.delete(loadedFilm)
            }
        } else {
            quantityFinished = loadedFilm.quantity
            // Don't restore quantity - unloading means the film was used
            // Just delete the loaded film entry
            context.delete(loadedFilm)
        }
        
        // Increment the finished films counter
        incrementFinishedFilmsCount(by: quantityFinished)
        
        try? context.save()
        loadFilmStocks() // Refresh the list
        NotificationCenter.default.post(name: NSNotification.Name("LoadedFilmsChanged"), object: nil)
        WidgetCenter.shared.reloadTimelines(ofKind: "LoadedFilmsWidget")
    }
    
    private static let finishedFilmsKey = "stats_finishedFilmsCount"
    
    func getFinishedFilmsCount() -> Int {
        UserDefaults.standard.integer(forKey: Self.finishedFilmsKey)
    }
    
    private func incrementFinishedFilmsCount(by amount: Int) {
        let current = getFinishedFilmsCount()
        UserDefaults.standard.set(current + amount, forKey: Self.finishedFilmsKey)
    }
    
    func saveContext() {
        guard let context = modelContext else { return }
        try? context.save()
        loadFilmStocks()
    }
    
    func canLoadFilm() -> Bool {
        guard let context = modelContext else { return false }
        let descriptor = FetchDescriptor<LoadedFilm>()
        let loadedFilms = (try? context.fetch(descriptor)) ?? []
        return loadedFilms.count < 5
    }
}

private struct ManufacturersDataWrapper: Codable {
    let manufacturers: [String]
}
