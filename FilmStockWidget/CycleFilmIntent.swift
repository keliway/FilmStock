//
//  CycleFilmIntent.swift
//  FilmStockWidget
//
//  App Intent for cycling through loaded films in the widget
//

import AppIntents
import WidgetKit
import SwiftData
import Foundation

struct NextFilmIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Film"
    static var description = IntentDescription("Show next loaded film")
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult {
        let appGroupID = "group.halbe.no.FilmStock"
        guard let userDefaults = UserDefaults(suiteName: appGroupID) else {
            return .result()
        }
        
        // Get current index and count
        var currentIndex = userDefaults.integer(forKey: "currentFilmIndex")
        
        // Get the count of loaded films by fetching from database
        // For now, we'll increment and let the timeline provider clamp it
        // But we need to wrap around, so we'll fetch the count
        let filmCount = getLoadedFilmCount()
        
        if filmCount > 0 {
            currentIndex = (currentIndex + 1) % filmCount
            userDefaults.set(currentIndex, forKey: "currentFilmIndex")
        }
        
        WidgetCenter.shared.reloadTimelines(ofKind: "LoadedFilmsWidget")
        
        return .result()
    }
    
    private func getLoadedFilmCount() -> Int {
        // Create a shared model container for widget access
        let schema = Schema([
            Manufacturer.self,
            Film.self,
            MyFilm.self,
            Camera.self,
            LoadedFilm.self
        ])
        
        let appGroupID = "group.halbe.no.FilmStock"
        var databaseURL: URL?
        
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            databaseURL = containerURL.appendingPathComponent("default.store")
        } else {
            if let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                databaseURL = appSupportURL.appendingPathComponent("default.store")
            }
        }
        
        guard let dbURL = databaseURL else {
            return 0
        }
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            let context = ModelContext(container)
            
            let descriptor = FetchDescriptor<LoadedFilm>(
                sortBy: [SortDescriptor(\.loadedAt, order: .reverse)]
            )
            
            let loadedFilms = try context.fetch(descriptor)
            return loadedFilms.count
        } catch {
            return 0
        }
    }
}

struct PreviousFilmIntent: AppIntent {
    static var title: LocalizedStringResource = "Previous Film"
    static var description = IntentDescription("Show previous loaded film")
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult {
        let appGroupID = "group.halbe.no.FilmStock"
        guard let userDefaults = UserDefaults(suiteName: appGroupID) else {
            return .result()
        }
        
        // Get current index and count
        var currentIndex = userDefaults.integer(forKey: "currentFilmIndex")
        
        // Get the count of loaded films
        let filmCount = getLoadedFilmCount()
        
        if filmCount > 0 {
            // Wrap around: if at 0, go to last; otherwise decrement
            currentIndex = (currentIndex - 1 + filmCount) % filmCount
            userDefaults.set(currentIndex, forKey: "currentFilmIndex")
        }
        
        WidgetCenter.shared.reloadTimelines(ofKind: "LoadedFilmsWidget")
        
        return .result()
    }
    
    private func getLoadedFilmCount() -> Int {
        // Create a shared model container for widget access
        let schema = Schema([
            Manufacturer.self,
            Film.self,
            MyFilm.self,
            Camera.self,
            LoadedFilm.self
        ])
        
        let appGroupID = "group.halbe.no.FilmStock"
        var databaseURL: URL?
        
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            databaseURL = containerURL.appendingPathComponent("default.store")
        } else {
            if let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                databaseURL = appSupportURL.appendingPathComponent("default.store")
            }
        }
        
        guard let dbURL = databaseURL else {
            return 0
        }
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            let context = ModelContext(container)
            
            let descriptor = FetchDescriptor<LoadedFilm>(
                sortBy: [SortDescriptor(\.loadedAt, order: .reverse)]
            )
            
            let loadedFilms = try context.fetch(descriptor)
            return loadedFilms.count
        } catch {
            return 0
        }
    }
}

