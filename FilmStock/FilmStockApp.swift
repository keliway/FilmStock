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
    
    init() {
        // Check if we need to delete old database due to schema change
        // This handles the migration from Array<String> to String for expireDate
        let schemaVersionKey = "databaseSchemaVersion"
        let currentSchemaVersion = 2 // Increment when schema changes
        
        if UserDefaults.standard.integer(forKey: schemaVersionKey) < currentSchemaVersion {
            // Delete old database files to allow fresh start with new schema
            if let storeURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let databaseURL = storeURL.appendingPathComponent("default.store")
                let databaseShmURL = storeURL.appendingPathComponent("default.store-shm")
                let databaseWalURL = storeURL.appendingPathComponent("default.store-wal")
                
                try? FileManager.default.removeItem(at: databaseURL)
                try? FileManager.default.removeItem(at: databaseShmURL)
                try? FileManager.default.removeItem(at: databaseWalURL)
                
                // Reset migration flag so app can re-migrate from JSON if needed
                UserDefaults.standard.removeObject(forKey: "hasMigratedToSwiftData")
                
                // Update schema version
                UserDefaults.standard.set(currentSchemaVersion, forKey: schemaVersionKey)
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(dataManager)
        }
        .modelContainer(for: [Manufacturer.self, Film.self, MyFilm.self, Camera.self, LoadedFilm.self])
    }
}

