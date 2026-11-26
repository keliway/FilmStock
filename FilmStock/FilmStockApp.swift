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
    @StateObject private var dataManager: FilmStockDataManager
    @StateObject private var settingsManager: SettingsManager
    
    private let modelContainer: ModelContainer
    
    init() {
        let args = ProcessInfo.processInfo.arguments
        let isUITesting = args.contains("-UITesting")
        if isUITesting {
            Self.configureUITestingDefaults(arguments: args)
        }
        _dataManager = StateObject(wrappedValue: FilmStockDataManager())
        _settingsManager = StateObject(wrappedValue: SettingsManager.shared)
        if isUITesting {
            SettingsManager.shared.resetToDefaults()
        }
        modelContainer = Self.makeModelContainer(inMemory: isUITesting)
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(dataManager)
                .preferredColorScheme(settingsManager.appearance.colorScheme)
        }
        .modelContainer(modelContainer)
    }
    
    private static func configureUITestingDefaults(arguments: [String]) {
        let defaults = UserDefaults.standard
        let keysToClear = [
            "settings_hideEmpty", "settings_defaultViewMode", "settings_appearance",
            "settings_enabledFormats", "settings_customFormats", "settings_showExpiryDateInChip",
            "settings_enableFridge", "filter_manufacturers", "filter_types",
            "filter_speedRanges", "filter_formats", "filter_showExpiredOnly",
            "filter_showFrozenOnly", "filter_showFridgeOnly", "sort_field",
            "sort_ascending", "browse_group_by", "stats_finishedFilmsCount",
            "migration_rollCentric_v1"
        ]
        for key in keysToClear {
            defaults.removeObject(forKey: key)
        }
        defaults.set(true, forKey: "hasCopiedDefaultImagesToAppGroup_v4")
        
        OnboardingManager.shared.resetOnboarding()
        if arguments.contains("-UITestOnboarding") {
            defaults.removeObject(forKey: "seenWhatsNewVersion")
        } else if arguments.contains("-UITestWhatsNew") {
            OnboardingManager.shared.hasCompletedOnboarding = true
            OnboardingManager.shared.markTooltipSeen("addFilm")
            OnboardingManager.shared.markTooltipSeen("filter")
            defaults.set("2.0", forKey: "seenWhatsNewVersion")
        } else {
            OnboardingManager.shared.hasCompletedOnboarding = true
            OnboardingManager.shared.markTooltipSeen("addFilm")
            OnboardingManager.shared.markTooltipSeen("filter")
            defaults.set(whatsNewVersion, forKey: "seenWhatsNewVersion")
        }
    }
    
    private static func makeModelContainer(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema([
            Manufacturer.self,
            Film.self,
            MyFilm.self,
            Camera.self,
            LoadedFilm.self,
            FinishedFilm.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        
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
