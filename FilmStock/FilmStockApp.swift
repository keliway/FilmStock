//
//  FilmStockApp.swift
//  FilmStock
//
//  Created on 2025
//

import SwiftUI
import SwiftData

@main
struct FilmStockApp: App {
    @StateObject private var dataManager = FilmStockDataManager()
    @StateObject private var settingsManager = SettingsManager.shared
    
    private let modelContainer: ModelContainer = FilmStockApp.makeModelContainer()
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(dataManager)
                .preferredColorScheme(settingsManager.appearance.colorScheme)
        }
        .modelContainer(modelContainer)
    }
    
    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema([
            Manufacturer.self,
            Film.self,
            MyFilm.self,
            Camera.self,
            LoadedFilm.self,
            FinishedFilm.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        func createContainer() throws -> ModelContainer {
            try ModelContainer(for: schema, configurations: [configuration])
        }
        
        do {
            return try createContainer()
        } catch {
            print("FilmStockApp: ModelContainer failed (\(error)). Attempting store reset.")
            resetPersistedStore(at: configuration.url)
            do {
                return try createContainer()
            } catch {
                fatalError("FilmStockApp: unable to create ModelContainer after store reset: \(error)")
            }
        }
    }
    
    private static func resetPersistedStore(at url: URL) {
        let fileManager = FileManager.default
        let relatedURLs = [
            url,
            URL(fileURLWithPath: url.path + "-wal"),
            URL(fileURLWithPath: url.path + "-shm")
        ]
        for fileURL in relatedURLs where fileManager.fileExists(atPath: fileURL.path) {
            try? fileManager.removeItem(at: fileURL)
        }
    }
}

