//
//  CycleFilmIntent.swift
//  FilmStockWidget
//
//  App Intent and shared store helpers for cycling through loaded films in the widget
//

import AppIntents
import WidgetKit
import SwiftData
import Foundation

enum WidgetDataStore {
    static let appGroupID = "group.app.halbe.no.FilmStock"
    static let widgetKind = "LoadedFilmsWidget"
    static let currentFilmIndexKey = "currentFilmIndex"

    static let schema = Schema([
        Manufacturer.self,
        Film.self,
        MyFilm.self,
        Camera.self,
        LoadedFilm.self,
        FinishedFilm.self
    ])

    static func makeModelContainer() throws -> ModelContainer {
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    }

    static func loadedFilmCount() -> Int {
        do {
            let container = try makeModelContainer()
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<LoadedFilm>()
            return try context.fetchCount(descriptor)
        } catch {
            return 0
        }
    }

    static func stepFilmIndex(by delta: Int) {
        guard let userDefaults = UserDefaults(suiteName: appGroupID) else { return }
        let filmCount = loadedFilmCount()
        if filmCount > 0 {
            let current = max(0, min(userDefaults.integer(forKey: currentFilmIndexKey), filmCount - 1))
            let next = ((current + delta) % filmCount + filmCount) % filmCount
            userDefaults.set(next, forKey: currentFilmIndexKey)
        } else {
            userDefaults.set(0, forKey: currentFilmIndexKey)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    }
}

struct NextFilmIntent: AppIntent {
    static var title: LocalizedStringResource = "widget.intent.next.title"
    static var description = IntentDescription("widget.intent.next.description")
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult {
        WidgetDataStore.stepFilmIndex(by: 1)
        return .result()
    }
}

struct PreviousFilmIntent: AppIntent {
    static var title: LocalizedStringResource = "widget.intent.previous.title"
    static var description = IntentDescription("widget.intent.previous.description")
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult {
        WidgetDataStore.stepFilmIndex(by: -1)
        return .result()
    }
}

