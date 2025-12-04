//
//  LoadedFilmsTimelineProvider.swift
//  FilmStockWidget
//
//  Timeline provider for loaded films widget
//

import WidgetKit
import SwiftUI
import SwiftData
import Foundation

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

struct LoadedFilmsTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = LoadedFilmsWidgetEntry
    typealias Intent = LoadedFilmsWidgetConfiguration
    
    func placeholder(in context: Context) -> LoadedFilmsWidgetEntry {
        let intent = LoadedFilmsWidgetConfiguration()
        return createEntry(for: intent, at: Date())
    }
    
    func snapshot(for configuration: LoadedFilmsWidgetConfiguration, in context: Context) async -> LoadedFilmsWidgetEntry {
        return createEntry(for: configuration, at: Date())
    }
    
    func timeline(for configuration: LoadedFilmsWidgetConfiguration, in context: Context) async -> Timeline<LoadedFilmsWidgetEntry> {
        let currentDate = Date()
        let entry = createEntry(for: configuration, at: currentDate)
        
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
    
    private func createEntry(for configuration: LoadedFilmsWidgetConfiguration, at date: Date) -> LoadedFilmsWidgetEntry {
        let loadedFilms = fetchLoadedFilms()
        
        // Get current index from UserDefaults
        let appGroupID = "group.app.halbe.no.FilmStock"
        let userDefaults = UserDefaults(suiteName: appGroupID)
        var currentIndex = userDefaults?.integer(forKey: "currentFilmIndex") ?? 0
        
        // Ensure index is within bounds
        if loadedFilms.isEmpty {
            currentIndex = 0
        } else {
            currentIndex = max(0, min(currentIndex, loadedFilms.count - 1))
        }
        
        // Store the adjusted index
        userDefaults?.set(currentIndex, forKey: "currentFilmIndex")
        
        return LoadedFilmsWidgetEntry(
            date: date,
            loadedFilms: loadedFilms,
            currentIndex: currentIndex,
            configuration: configuration
        )
    }
    
    
    
    private func fetchLoadedFilms() -> [LoadedFilmWidgetData] {
        // Create a shared model container for widget access using the same database as the main app
        let schema = Schema([
            Manufacturer.self,
            Film.self,
            MyFilm.self,
            Camera.self,
            LoadedFilm.self
        ])
        
        // For widget extensions, we need to use App Groups to share the database
        // with the main app. If App Groups are not set up, try using the default location.
        // First, try App Group container (recommended for widget extensions)
        let appGroupID = "group.app.halbe.no.FilmStock"
        var databaseURL: URL?
        
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            databaseURL = containerURL.appendingPathComponent("default.store")
        } else {
            // Fallback to Application Support directory (should work if both are in same app bundle)
            if let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                databaseURL = appSupportURL.appendingPathComponent("default.store")
            }
        }
        
        guard databaseURL != nil else {
            return []
        }
        
        // Create ModelConfiguration - use default configuration which should access the same database
        // as the main app when both are in the same app bundle
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        
        do {
            // Create container - this should access the same database as the main app
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            let context = ModelContext(container)
            
            // Fetch loaded films
            let descriptor = FetchDescriptor<LoadedFilm>(
                sortBy: [SortDescriptor(\.loadedAt, order: .reverse)]
            )
            
            let loadedFilms: [LoadedFilm]
            do {
                loadedFilms = try context.fetch(descriptor)
            } catch {
                return []
            }
            
            // Convert to widget data
            return loadedFilms.compactMap { loadedFilm -> LoadedFilmWidgetData? in
                guard let film = loadedFilm.film else { return nil }
                
                // Load image based on imageSource
                var imageData: Data?
                let manufacturerName = film.manufacturer?.name ?? ""
                
                // Determine image source (default to auto-detected if not set)
                let imageSourceRaw = film.imageSource
                
                switch imageSourceRaw {
                case "custom":
                    // Load user-taken photo
                    if let imageName = film.imageName {
                        // Handle manufacturer/filename format (for catalog-selected photos)
                        let (manufacturer, filename) = parseCustomImageName(imageName, defaultManufacturer: manufacturerName)
                        imageData = loadImageData(filename: filename, manufacturer: manufacturer)
                    }
                    
                case "catalog":
                    // Load catalog image from bundle
                    if let catalogFilename = film.imageName {
                        imageData = loadCatalogImageData(filename: catalogFilename)
                    }
                    
                case "auto", "none", _:
                    // Auto-detect or no image - try to load default image
                    imageData = loadDefaultImageData(filmName: film.name, manufacturer: manufacturerName)
                }
                
                // Get effective ISO (shot at ISO if set, otherwise film's native ISO)
                let effectiveISO = loadedFilm.shotAtISO ?? film.filmSpeed
                
                return LoadedFilmWidgetData(
                    id: loadedFilm.id,
                    filmName: film.name,
                    manufacturer: manufacturerName,
                    format: loadedFilm.format,
                    customFormatName: loadedFilm.myFilm?.customFormatName,
                    camera: loadedFilm.camera?.name ?? "",
                    imageData: imageData,
                    loadedAt: loadedFilm.loadedAt,
                    effectiveISO: effectiveISO
                )
            }
        } catch {
            return []
        }
    }
    
    private func loadImageData(filename: String, manufacturer: String) -> Data? {
        // Try App Group container first
        let appGroupID = "group.app.halbe.no.FilmStock"
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let userImagesDir = containerURL.appendingPathComponent("UserImages", isDirectory: true)
            let manufacturerDir = userImagesDir.appendingPathComponent(manufacturer, isDirectory: true)
            let fileURL = manufacturerDir.appendingPathComponent("\(filename).jpg")
            
            if FileManager.default.fileExists(atPath: fileURL.path) {
                return try? Data(contentsOf: fileURL)
            }
        }
        
        // Fallback to Documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let userImagesDirectory = documentsPath.appendingPathComponent("UserImages", isDirectory: true)
        let manufacturerDir = userImagesDirectory.appendingPathComponent(manufacturer, isDirectory: true)
        let fileURL = manufacturerDir.appendingPathComponent("\(filename).jpg")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        return try? Data(contentsOf: fileURL)
    }
    
    private func loadCatalogImageData(filename: String) -> Data? {
        // Load catalog image directly by filename (e.g., "ilford_hp5")
        let appGroupID = "group.app.halbe.no.FilmStock"
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return nil
        }
        
        // Catalog images are stored flat in the root of DefaultImages
        let defaultImagesURL = containerURL.appendingPathComponent("DefaultImages", isDirectory: true)
        
        // Parse manufacturer from filename (manufacturer_filmname format)
        if let underscoreIndex = filename.firstIndex(of: "_") {
            let manufacturer = String(filename[..<underscoreIndex])
            let manufacturerURL = defaultImagesURL.appendingPathComponent(manufacturer, isDirectory: true)
            let imageURL = manufacturerURL.appendingPathComponent(filename + ".png")
            
            if FileManager.default.fileExists(atPath: imageURL.path),
               let data = try? Data(contentsOf: imageURL) {
                return data
            }
        }
        
        return nil
    }
    
    private func loadDefaultImageData(filmName: String, manufacturer: String) -> Data? {
        // Load manufacturers.json from App Group to match film names properly
        let appGroupID = "group.app.halbe.no.FilmStock"
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return nil
        }
        
        let manufacturersJSONURL = containerURL.appendingPathComponent("manufacturers.json")
        
        // Try to use manufacturers.json for proper matching
        if let jsonData = try? Data(contentsOf: manufacturersJSONURL),
           let manufacturersWrapper = try? JSONDecoder().decode(ManufacturersDataWrapper.self, from: jsonData) {
            
            // Find manufacturer (case-insensitive)
            guard let manufacturerInfo = manufacturersWrapper.manufacturers.first(where: { $0.name.lowercased() == manufacturer.lowercased() }) else {
                return trySimpleMatching(filmName: filmName, manufacturer: manufacturer)
            }
            
            // Normalize user input
            let normalizedUserInput = filmName.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "", options: .regularExpression).lowercased()
            
            // Try to find matching film
            for filmInfo in manufacturerInfo.films {
                let allNames = [filmInfo.filename] + filmInfo.aliases
                
                for alias in allNames {
                    let normalizedAlias = alias.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "", options: .regularExpression).lowercased()
                    
                    if normalizedUserInput == normalizedAlias {
                        let filename = "\(manufacturer.lowercased())_\(filmInfo.filename)"
                        
                        if let data = loadCatalogImageData(filename: filename) {
                            return data
                        }
                    }
                }
            }
        }
        
        // Fallback to simple matching
        return trySimpleMatching(filmName: filmName, manufacturer: manufacturer)
    }
    
    private func trySimpleMatching(filmName: String, manufacturer: String) -> Data? {
        let normalizedFilmName = filmName.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "", options: .regularExpression).lowercased()
        let normalizedManufacturer = manufacturer.lowercased()
        
        let variations = [
            "\(normalizedManufacturer)_\(normalizedFilmName)",
            "\(manufacturer.lowercased())_\(filmName.lowercased())",
        ]
        
        for variation in variations {
            if let data = loadCatalogImageData(filename: variation) {
                return data
            }
        }
        
        return nil
    }
    
    // Add the required structs for decoding manufacturers.json
    struct FilmInfo: Codable {
        let filename: String
        let speed: Int?
        let type: String?
        let aliases: [String]
    }
    
    struct ManufacturerInfo: Codable {
        let name: String
        var films: [FilmInfo]
    }
    
    struct ManufacturersDataWrapper: Codable {
        var manufacturers: [ManufacturerInfo]
    }
}

