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
        LoadedFilmsWidgetEntry(
            date: Date(),
            loadedFilms: [
                LoadedFilmWidgetData(
                    id: "placeholder",
                    filmName: "HP5 Plus",
                    manufacturer: "Ilford",
                    format: "35",
                    customFormatName: nil,
                    camera: "Leica M6",
                    imageData: nil,
                    loadedAt: Date(),
                    effectiveISO: 400
                )
            ],
            currentIndex: 0,
            configuration: LoadedFilmsWidgetConfiguration()
        )
    }
    
    func snapshot(for configuration: LoadedFilmsWidgetConfiguration, in context: Context) async -> LoadedFilmsWidgetEntry {
        if context.isPreview {
            return placeholder(in: context)
        }
        return createEntry(for: configuration, at: Date())
    }
    
    func timeline(for configuration: LoadedFilmsWidgetConfiguration, in context: Context) async -> Timeline<LoadedFilmsWidgetEntry> {
        let currentDate = Date()
        let entry = createEntry(for: configuration, at: currentDate)
        
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate) ?? currentDate.addingTimeInterval(3600)
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
    
    private func createEntry(for configuration: LoadedFilmsWidgetConfiguration, at date: Date) -> LoadedFilmsWidgetEntry {
        let loadedFilms = fetchLoadedFilms()
        
        let userDefaults = UserDefaults(suiteName: WidgetDataStore.appGroupID)
        var currentIndex = userDefaults?.integer(forKey: WidgetDataStore.currentFilmIndexKey) ?? 0
        
        if loadedFilms.isEmpty {
            currentIndex = 0
        } else {
            currentIndex = max(0, min(currentIndex, loadedFilms.count - 1))
        }
        
        userDefaults?.set(currentIndex, forKey: WidgetDataStore.currentFilmIndexKey)
        
        return LoadedFilmsWidgetEntry(
            date: date,
            loadedFilms: loadedFilms,
            currentIndex: currentIndex,
            configuration: configuration
        )
    }
    
    private func fetchLoadedFilms() -> [LoadedFilmWidgetData] {
        do {
            let container = try WidgetDataStore.makeModelContainer()
            let context = ModelContext(container)
            
            let descriptor = FetchDescriptor<LoadedFilm>(
                sortBy: [SortDescriptor(\.loadedAt, order: .reverse)]
            )
            let loadedFilms = try context.fetch(descriptor)
            
            return loadedFilms.compactMap { loadedFilm -> LoadedFilmWidgetData? in
                guard let film = loadedFilm.film ?? loadedFilm.myFilm?.film else { return nil }
                
                var imageData: Data?
                let manufacturerName = film.manufacturer?.name ?? ""
                
                switch film.imageSource {
                case "custom":
                    if let imageName = film.imageName {
                        let (manufacturer, filename) = parseCustomImageName(imageName, defaultManufacturer: manufacturerName)
                        imageData = loadImageData(filename: filename, manufacturer: manufacturer)
                    }
                    
                case "catalog":
                    if let catalogFilename = film.imageName {
                        imageData = loadCatalogImageData(filename: catalogFilename)
                    }
                    
                case "none":
                    imageData = nil
                    
                default:
                    imageData = loadDefaultImageData(filmName: film.name, manufacturer: manufacturerName)
                }
                
                let effectiveISO = loadedFilm.shotAtISO ?? film.filmSpeed
                let resolvedCamera = loadedFilm.cameraName ?? loadedFilm.camera?.name ?? ""
                
                return LoadedFilmWidgetData(
                    id: loadedFilm.id,
                    filmName: film.name,
                    manufacturer: manufacturerName,
                    format: loadedFilm.format,
                    customFormatName: loadedFilm.myFilm?.customFormatName,
                    camera: resolvedCamera,
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
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WidgetDataStore.appGroupID) {
            let userImagesDir = containerURL.appendingPathComponent("UserImages", isDirectory: true)
            let manufacturerDir = userImagesDir.appendingPathComponent(manufacturer, isDirectory: true)
            let fileURL = manufacturerDir.appendingPathComponent("\(filename).jpg")
            
            if FileManager.default.fileExists(atPath: fileURL.path) {
                return try? Data(contentsOf: fileURL)
            }
        }
        
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
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WidgetDataStore.appGroupID) else {
            return nil
        }
        
        let baseName = filename.replacingOccurrences(of: ".png", with: "", options: .caseInsensitive)
        guard let underscoreIndex = baseName.firstIndex(of: "_") else {
            return nil
        }
        
        let defaultImagesURL = containerURL.appendingPathComponent("DefaultImages", isDirectory: true)
        let targetManufacturer = String(baseName[..<underscoreIndex]).lowercased()
        let targetFileLower = (baseName + ".png").lowercased()
        
        // Resolve manufacturer directory case-insensitively (for physical iOS APFS)
        let directMfrURL = defaultImagesURL.appendingPathComponent(targetManufacturer, isDirectory: true)
        let manufacturerURL: URL
        if FileManager.default.fileExists(atPath: directMfrURL.path) {
            manufacturerURL = directMfrURL
        } else if let subdirs = try? FileManager.default.contentsOfDirectory(at: defaultImagesURL, includingPropertiesForKeys: nil),
                  let matchDir = subdirs.first(where: { $0.lastPathComponent.lowercased() == targetManufacturer }) {
            manufacturerURL = matchDir
        } else {
            return nil
        }
        
        // Try exact filename first, then case-insensitive directory scan
        let exactFileURL = manufacturerURL.appendingPathComponent(baseName + ".png")
        if FileManager.default.fileExists(atPath: exactFileURL.path),
           let data = try? Data(contentsOf: exactFileURL) {
            return data
        }
        
        if let files = try? FileManager.default.contentsOfDirectory(at: manufacturerURL, includingPropertiesForKeys: nil),
           let matchedURL = files.first(where: { $0.lastPathComponent.lowercased() == targetFileLower }),
           let data = try? Data(contentsOf: matchedURL) {
            return data
        }
        
        return nil
    }
    
    private func normalizeToken(_ raw: String) -> String {
        raw.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "", options: .regularExpression).lowercased()
    }
    
    private func loadDefaultImageData(filmName: String, manufacturer: String) -> Data? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WidgetDataStore.appGroupID) else {
            return nil
        }
        
        let manufacturersJSONURL = containerURL.appendingPathComponent("manufacturers.json")
        if let jsonData = try? Data(contentsOf: manufacturersJSONURL),
           let manufacturersWrapper = try? JSONDecoder().decode(ManufacturersDataWrapper.self, from: jsonData) {
            
            guard let manufacturerInfo = manufacturersWrapper.manufacturers.first(where: {
                $0.name.caseInsensitiveCompare(manufacturer) == .orderedSame
            }) else {
                return trySimpleMatching(filmName: filmName, manufacturer: manufacturer)
            }
            
            let normalizedUserInput = normalizeToken(filmName)
            
            for filmInfo in manufacturerInfo.films {
                let allNames = [filmInfo.filename] + filmInfo.aliases
                for alias in allNames where normalizeToken(alias) == normalizedUserInput {
                    let canonicalFilename = "\(manufacturerInfo.name.lowercased())_\(filmInfo.filename)"
                    if let data = loadCatalogImageData(filename: canonicalFilename) {
                        return data
                    }
                    let userMfrFilename = "\(manufacturer.lowercased())_\(filmInfo.filename)"
                    if let data = loadCatalogImageData(filename: userMfrFilename) {
                        return data
                    }
                }
            }
        }
        
        return trySimpleMatching(filmName: filmName, manufacturer: manufacturer)
    }
    
    private func trySimpleMatching(filmName: String, manufacturer: String) -> Data? {
        let normalizedManufacturer = normalizeToken(manufacturer)
        let baseName = filmName.replacingOccurrences(of: "[^a-zA-Z0-9_]", with: "", options: .regularExpression)
        let strippedName = normalizeToken(filmName)
        guard !normalizedManufacturer.isEmpty else { return nil }
        
        for candidate in ["\(normalizedManufacturer)_\(baseName)", "\(normalizedManufacturer)_\(strippedName)"] {
            if let data = loadCatalogImageData(filename: candidate) {
                return data
            }
        }
        return nil
    }
    
    struct FilmInfo: Codable {
        let filename: String
        let speed: Int?
        let type: String?
        let aliases: [String]

        enum CodingKeys: String, CodingKey {
            case filename, speed, type, aliases
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            filename = try container.decode(String.self, forKey: .filename)
            speed = try container.decodeIfPresent(Int.self, forKey: .speed)
            type = try container.decodeIfPresent(String.self, forKey: .type)
            aliases = try container.decodeIfPresent([String].self, forKey: .aliases) ?? []
        }
    }
    
    struct ManufacturerInfo: Codable {
        let name: String
        var films: [FilmInfo]
    }
    
    struct ManufacturersDataWrapper: Codable {
        var manufacturers: [ManufacturerInfo]
    }
}

