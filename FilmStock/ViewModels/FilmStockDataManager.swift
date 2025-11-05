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
    private let migrationKey = "hasMigratedToSwiftData"
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        loadFilmStocks()
    }
    
    func migrateIfNeeded() async {
        guard let context = modelContext else { return }
        
        // Copy default images to App Group container for widget access (runs once)
        ImageStorage.shared.copyDefaultImagesToAppGroup()
        
        // Check if migration has already been done
        if UserDefaults.standard.bool(forKey: migrationKey) {
            return
        }
        
        // Check if there's existing JSON data to migrate
        let fileName = "filmstocks.json"
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
        
        var jsonData: Data?
        
        // Try Documents directory first
        if FileManager.default.fileExists(atPath: fileURL.path) {
            jsonData = try? Data(contentsOf: fileURL)
        }
        
        // Try bundle if not in Documents
        if jsonData == nil {
            if let bundleURL = Bundle.main.url(forResource: "filmstocks", withExtension: "json") {
                jsonData = try? Data(contentsOf: bundleURL)
            }
        }
        
        guard let data = jsonData, !data.isEmpty else {
            // No JSON data, just load manufacturers
            await loadManufacturers(context: context)
            UserDefaults.standard.set(true, forKey: migrationKey)
            return
        }
        
        // Migrate JSON data
        do {
            let decoder = JSONDecoder()
            let wrapper = try decoder.decode(FilmStockDataWrapper.self, from: data)
            
            // Load manufacturers first
            await loadManufacturers(context: context)
            
            // Migrate each film stock
            for filmStock in wrapper.filmstocks {
                await migrateFilmStock(filmStock, context: context)
            }
            
            // Mark migration as complete
            UserDefaults.standard.set(true, forKey: migrationKey)
            
            // Load films after migration
            loadFilmStocks()
        } catch {
            print("Migration error: \(error)")
            await loadManufacturers(context: context)
            UserDefaults.standard.set(true, forKey: migrationKey)
        }
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
            let wrapper = try decoder.decode(ManufacturersDataWrapper.self, from: data)
            
            for manufacturerName in wrapper.manufacturers {
                let manufacturer = Manufacturer(name: manufacturerName, isCustom: false)
                context.insert(manufacturer)
            }
            
            try context.save()
        } catch {
            print("Failed to load manufacturers: \(error)")
        }
    }
    
    private func migrateFilmStock(_ filmStock: FilmStock, context: ModelContext) async {
        // Find or create manufacturer
        let manufacturerDescriptor = FetchDescriptor<Manufacturer>(
            predicate: #Predicate { $0.name == filmStock.manufacturer }
        )
        var manufacturer: Manufacturer
        
        if let existing = try? context.fetch(manufacturerDescriptor).first {
            manufacturer = existing
        } else {
            manufacturer = Manufacturer(name: filmStock.manufacturer, isCustom: true)
            context.insert(manufacturer)
        }
        
        // Find or create film - fetch all and filter to avoid predicate complexity
        let filmDescriptor = FetchDescriptor<Film>()
        let allFilms = (try? context.fetch(filmDescriptor)) ?? []
        
        var film: Film
        
        if let existing = allFilms.first(where: { film in
            film.name == filmStock.name &&
            film.manufacturer?.name == filmStock.manufacturer &&
            film.type == filmStock.type.rawValue &&
            film.filmSpeed == filmStock.filmSpeed
        }) {
            film = existing
        } else {
            film = Film(
                name: filmStock.name,
                manufacturer: manufacturer,
                type: filmStock.type.rawValue,
                filmSpeed: filmStock.filmSpeed,
                imageName: nil
            )
            context.insert(film)
        }
        
        // Create MyFilm entry
        let myFilm = MyFilm(
            id: filmStock.id,
            format: filmStock.format.rawValue,
            quantity: filmStock.quantity,
            expireDate: filmStock.expireDate,
            comments: filmStock.comments,
            createdAt: filmStock.createdAt,
            updatedAt: filmStock.updatedAt,
            film: film
        )
        context.insert(myFilm)
        
        try? context.save()
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
                createdAt: myFilm.createdAt,
                updatedAt: myFilm.updatedAt
            )
        }
    }
    
    func addFilmStock(_ filmStock: FilmStock, imageName: String? = nil) {
        guard let context = modelContext else { return }
        
        Task {
            // Find or create manufacturer
            let manufacturer = await findOrCreateManufacturer(name: filmStock.manufacturer, context: context)
            
            // Find or create film
            let film = await findOrCreateFilm(
                name: filmStock.name,
                manufacturer: manufacturer,
                type: filmStock.type.rawValue,
                filmSpeed: filmStock.filmSpeed,
                imageName: imageName,
                context: context
            )
            
            // Create MyFilm entry
            let myFilm = MyFilm(
                id: filmStock.id,
                format: filmStock.format.rawValue,
                quantity: filmStock.quantity,
                expireDate: filmStock.expireDate,
                comments: filmStock.comments,
                createdAt: filmStock.createdAt,
                updatedAt: filmStock.updatedAt,
                film: film
            )
            
            context.insert(myFilm)
            try? context.save()
            
            await MainActor.run {
                loadFilmStocks()
            }
        }
    }
    
    func updateFilmStock(_ filmStock: FilmStock, imageName: String? = nil) {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<MyFilm>(
            predicate: #Predicate { $0.id == filmStock.id }
        )
        
        guard let myFilm = try? context.fetch(descriptor).first else { return }
        
        // Update MyFilm
        myFilm.quantity = filmStock.quantity
        myFilm.expireDateArray = filmStock.expireDate
        myFilm.comments = filmStock.comments
        myFilm.updatedAt = ISO8601DateFormatter().string(from: Date())
        
        // If format changed, we need to update it
        if myFilm.format != filmStock.format.rawValue {
            myFilm.format = filmStock.format.rawValue
        }
        
        // Update film's imageName if provided
        if let film = myFilm.film, let imageName = imageName {
            // Delete old image if it exists and is different
            if let oldImageName = film.imageName, oldImageName != imageName {
                if let manufacturer = film.manufacturer {
                    ImageStorage.shared.deleteImage(filename: oldImageName, manufacturer: manufacturer.name)
                }
            }
            film.imageName = imageName
        }
        
        try? context.save()
        loadFilmStocks()
    }
    
    func deleteFilmStock(_ filmStock: FilmStock) {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<MyFilm>(
            predicate: #Predicate { $0.id == filmStock.id }
        )
        
        guard let myFilm = try? context.fetch(descriptor).first else { return }
        
        context.delete(myFilm)
        try? context.save()
        loadFilmStocks()
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
                            quantity: myFilm.quantity,
                            expireDate: myFilm.expireDateArray,
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
        let descriptor = FetchDescriptor<Manufacturer>(
            sortBy: [SortDescriptor(\.name)]
        )
        return (try? context.fetch(descriptor)) ?? []
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
    
    func deleteManufacturer(_ manufacturer: Manufacturer) {
        guard let context = modelContext else { return }
        
        // Only allow deletion of custom manufacturers
        guard manufacturer.isCustom else { return }
        
        // Check if any films use this manufacturer - fetch all and filter in memory
        let descriptor = FetchDescriptor<Film>()
        let allFilms = (try? context.fetch(descriptor)) ?? []
        
        let filmsUsingManufacturer = allFilms.filter { film in
            film.manufacturer?.name == manufacturer.name
        }
        
        if !filmsUsingManufacturer.isEmpty {
            // Don't delete if films are using it
            return
        }
        
        context.delete(manufacturer)
        try? context.save()
    }
    
    // MARK: - Helper Methods
    
    private func findOrCreateManufacturer(name: String, context: ModelContext) async -> Manufacturer {
        let descriptor = FetchDescriptor<Manufacturer>(
            predicate: #Predicate { $0.name == name }
        )
        
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        
        let manufacturer = Manufacturer(name: name, isCustom: true)
        context.insert(manufacturer)
        try? context.save()
        return manufacturer
    }
    
    private func findOrCreateFilm(name: String, manufacturer: Manufacturer, type: String, filmSpeed: Int, imageName: String? = nil, context: ModelContext) async -> Film {
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
            // Update imageName if provided
            if let imageName = imageName {
                existing.imageName = imageName
                try? context.save()
            }
            return existing
        }
        
        let film = Film(
            name: name,
            manufacturer: manufacturer,
            type: type,
            filmSpeed: filmSpeed,
            imageName: imageName
        )
        context.insert(film)
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
        
        // Create loaded film entry
        let loadedFilm = LoadedFilm(
            id: UUID().uuidString,
            film: film,
            format: format.rawValue,
            camera: camera,
            myFilm: myFilm,
            quantity: quantity
        )
        context.insert(loadedFilm)
        
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
        
        // If quantity is specified, unload only that amount
        if let quantityToUnload = quantity {
            // Decrease the loaded quantity
            loadedFilm.quantity = max(0, loadedFilm.quantity - quantityToUnload)
            
            // If quantity reaches 0, delete the loaded film entry
            if loadedFilm.quantity == 0 {
                context.delete(loadedFilm)
            }
        } else {
            // Don't restore quantity - unloading means the film was used
            // Just delete the loaded film entry
            context.delete(loadedFilm)
        }
        
        try? context.save()
        loadFilmStocks() // Refresh the list
        NotificationCenter.default.post(name: NSNotification.Name("LoadedFilmsChanged"), object: nil)
        WidgetCenter.shared.reloadTimelines(ofKind: "LoadedFilmsWidget")
    }
    
    func canLoadFilm() -> Bool {
        guard let context = modelContext else { return false }
        let descriptor = FetchDescriptor<LoadedFilm>()
        let loadedFilms = (try? context.fetch(descriptor)) ?? []
        return loadedFilms.count < 5
    }
}

private struct FilmStockDataWrapper: Codable {
    let filmstocks: [FilmStock]
}

private struct ManufacturersDataWrapper: Codable {
    let manufacturers: [String]
}
