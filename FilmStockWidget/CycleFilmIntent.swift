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

private enum WidgetLoadedFilmCounter {
    static func count() -> Int {
        let schema = Schema([
            Manufacturer.self,
            Film.self,
            MyFilm.self,
            Camera.self,
            LoadedFilm.self,
            FinishedFilm.self
        ])
        
        let appGroupID = "group.app.halbe.no.FilmStock"
        var databaseURL: URL?
        
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            databaseURL = containerURL.appendingPathComponent("default.store")
        } else if let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            databaseURL = appSupportURL.appendingPathComponent("default.store")
        }
        
        guard databaseURL != nil else {
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

struct NextFilmIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Film"
    static var description = IntentDescription("Show next loaded film")
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult {
        let appGroupID = "group.app.halbe.no.FilmStock"
        guard let userDefaults = UserDefaults(suiteName: appGroupID) else {
            return .result()
        }
        
        var currentIndex = userDefaults.integer(forKey: "currentFilmIndex")
        let filmCount = WidgetLoadedFilmCounter.count()
        
        if filmCount > 0 {
            currentIndex = (currentIndex + 1) % filmCount
            userDefaults.set(currentIndex, forKey: "currentFilmIndex")
        }
        
        WidgetCenter.shared.reloadTimelines(ofKind: "LoadedFilmsWidget")
        
        return .result()
    }
}

struct PreviousFilmIntent: AppIntent {
    static var title: LocalizedStringResource = "Previous Film"
    static var description = IntentDescription("Show previous loaded film")
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult {
        let appGroupID = "group.app.halbe.no.FilmStock"
        guard let userDefaults = UserDefaults(suiteName: appGroupID) else {
            return .result()
        }
        
        var currentIndex = userDefaults.integer(forKey: "currentFilmIndex")
        let filmCount = WidgetLoadedFilmCounter.count()
        
        if filmCount > 0 {
            currentIndex = (currentIndex - 1 + filmCount) % filmCount
            userDefaults.set(currentIndex, forKey: "currentFilmIndex")
        }
        
        WidgetCenter.shared.reloadTimelines(ofKind: "LoadedFilmsWidget")
        
        return .result()
    }
}

