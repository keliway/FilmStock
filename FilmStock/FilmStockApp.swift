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
        
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // Retry once after a brief pause in case the widget extension briefly held a SQLite lock,
            // and never destructively delete the user's persisted store.
            print("FilmStockApp: ModelContainer failed on first attempt (\(error)). Retrying...")
            Thread.sleep(forTimeInterval: 0.15)
            do {
                return try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                fatalError("FilmStockApp: unable to create ModelContainer: \(error)")
            }
        }
    }
}
