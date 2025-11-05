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
        let appGroupID = "group.halbe.no.FilmStock"
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
        let appGroupID = "group.halbe.no.FilmStock"
        var databaseURL: URL?
        
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            databaseURL = containerURL.appendingPathComponent("default.store")
        } else {
            // Fallback to Application Support directory (should work if both are in same app bundle)
            if let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                databaseURL = appSupportURL.appendingPathComponent("default.store")
            }
        }
        
        guard let dbURL = databaseURL else {
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
                
                // Load image
                var imageData: Data?
                
                // Try custom image first
                if let imageName = film.imageName {
                    imageData = loadImageData(filename: imageName, manufacturer: film.manufacturer?.name ?? "")
                }
                
                // Fallback to default image
                if imageData == nil {
                    imageData = loadDefaultImageData(filmName: film.name, manufacturer: film.manufacturer?.name ?? "")
                }
                
                return LoadedFilmWidgetData(
                    id: loadedFilm.id,
                    filmName: film.name,
                    manufacturer: film.manufacturer?.name ?? "",
                    format: loadedFilm.format,
                    camera: loadedFilm.camera?.name ?? "",
                    imageData: imageData,
                    loadedAt: loadedFilm.loadedAt
                )
            }
        } catch {
            return []
        }
    }
    
    private func loadImageData(filename: String, manufacturer: String) -> Data? {
        // Try App Group container first
        let appGroupID = "group.halbe.no.FilmStock"
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
    
    private func loadDefaultImageData(filmName: String, manufacturer: String) -> Data? {
        let baseName = filmName.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "", options: .regularExpression)
        var variations = [
            baseName + ".png",
            baseName.lowercased() + ".png",
            baseName.capitalized + ".png",
            baseName.uppercased() + ".png"
        ]
        
        if baseName.count > 1 {
            let firstChar = String(baseName.prefix(1)).uppercased()
            let rest = String(baseName.dropFirst()).lowercased()
            variations.append((firstChar + rest) + ".png")
        }
        
        // Only check App Group container (images copied by main app)
        // Widget extensions can't access main app bundle directly
        let appGroupID = "group.halbe.no.FilmStock"
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return nil
        }
        
        let defaultImagesURL = containerURL.appendingPathComponent("DefaultImages", isDirectory: true)
        let manufacturerURL = defaultImagesURL.appendingPathComponent(manufacturer, isDirectory: true)
        
        for variation in variations {
            let imageURL = manufacturerURL.appendingPathComponent(variation, isDirectory: false)
            if FileManager.default.fileExists(atPath: imageURL.path),
               let data = try? Data(contentsOf: imageURL) {
                return data
            }
        }
        
        return nil
    }
}

