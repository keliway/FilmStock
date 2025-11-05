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
    
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(dataManager)
        }
        .modelContainer(for: [Manufacturer.self, Film.self, MyFilm.self, Camera.self, LoadedFilm.self])
    }
}

