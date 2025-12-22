//
//  SettingsManager.swift
//  FilmStock
//
//  Manages app settings and preferences
//

import Foundation
import SwiftUI
import Combine

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    private let hideEmptyKey = "settings_hideEmpty"
    private let defaultViewModeKey = "settings_defaultViewMode"
    private let appearanceKey = "settings_appearance"
    private let enabledFormatsKey = "settings_enabledFormats"
    private let customFormatsKey = "settings_customFormats"
    private let showExpiryDateInChipKey = "settings_showExpiryDateInChip"
    
    // Filter preferences
    private let filterManufacturersKey = "filter_manufacturers"
    private let filterTypesKey = "filter_types"
    private let filterSpeedRangesKey = "filter_speedRanges"
    private let filterFormatsKey = "filter_formats"
    private let filterShowExpiredOnlyKey = "filter_showExpiredOnly"
    private let filterShowFrozenOnlyKey = "filter_showFrozenOnly"
    
    // Sort preferences
    private let sortFieldKey = "sort_field"
    private let sortAscendingKey = "sort_ascending"
    
    @Published var hideEmptyByDefault: Bool {
        didSet {
            UserDefaults.standard.set(hideEmptyByDefault, forKey: hideEmptyKey)
        }
    }
    
    @Published var useTableViewByDefault: Bool {
        didSet {
            UserDefaults.standard.set(useTableViewByDefault, forKey: defaultViewModeKey)
        }
    }
    
    @Published var appearance: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: appearanceKey)
        }
    }
    
    @Published var enabledFormats: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(enabledFormats), forKey: enabledFormatsKey)
        }
    }
    
    @Published var customFormats: [String] {
        didSet {
            UserDefaults.standard.set(customFormats, forKey: customFormatsKey)
        }
    }
    
    @Published var showExpiryDateInChip: Bool {
        didSet {
            UserDefaults.standard.set(showExpiryDateInChip, forKey: showExpiryDateInChipKey)
        }
    }
    
    // Filter preferences
    @Published var filterManufacturers: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(filterManufacturers), forKey: filterManufacturersKey)
        }
    }
    
    @Published var filterTypes: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(filterTypes), forKey: filterTypesKey)
        }
    }
    
    @Published var filterSpeedRanges: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(filterSpeedRanges), forKey: filterSpeedRangesKey)
        }
    }
    
    @Published var filterFormats: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(filterFormats), forKey: filterFormatsKey)
        }
    }
    
    @Published var filterShowExpiredOnly: Bool {
        didSet {
            UserDefaults.standard.set(filterShowExpiredOnly, forKey: filterShowExpiredOnlyKey)
        }
    }
    
    @Published var filterShowFrozenOnly: Bool {
        didSet {
            UserDefaults.standard.set(filterShowFrozenOnly, forKey: filterShowFrozenOnlyKey)
        }
    }
    
    // Sort preferences
    @Published var sortField: String {
        didSet {
            UserDefaults.standard.set(sortField, forKey: sortFieldKey)
        }
    }
    
    @Published var sortAscending: Bool {
        didSet {
            UserDefaults.standard.set(sortAscending, forKey: sortAscendingKey)
        }
    }
    
    // All available formats (built-in + custom)
    var allAvailableFormats: [String] {
        let builtIn = FilmStock.FilmFormat.allCases.map { $0.displayName }
        return builtIn + customFormats
    }
    
    // Formats to show in Add/Edit views
    var formatsToShow: [String] {
        return allAvailableFormats.filter { enabledFormats.contains($0) }
    }
    
    func isFormatEnabled(_ format: String) -> Bool {
        enabledFormats.contains(format)
    }
    
    func toggleFormat(_ format: String) {
        if enabledFormats.contains(format) {
            enabledFormats.remove(format)
        } else {
            enabledFormats.insert(format)
        }
    }
    
    func addCustomFormat(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !customFormats.contains(trimmed) else { return }
        guard !FilmStock.FilmFormat.allCases.map({ $0.displayName }).contains(trimmed) else { return }
        
        customFormats.append(trimmed)
        enabledFormats.insert(trimmed)
    }
    
    func deleteCustomFormat(_ name: String) {
        customFormats.removeAll { $0 == name }
        enabledFormats.remove(name)
    }
    
    func isCustomFormat(_ name: String) -> Bool {
        customFormats.contains(name)
    }
    
    private init() {
        // Load saved settings or use defaults
        self.hideEmptyByDefault = UserDefaults.standard.object(forKey: hideEmptyKey) as? Bool ?? true
        self.useTableViewByDefault = UserDefaults.standard.object(forKey: defaultViewModeKey) as? Bool ?? false
        self.showExpiryDateInChip = UserDefaults.standard.object(forKey: showExpiryDateInChipKey) as? Bool ?? false
        
        if let savedAppearance = UserDefaults.standard.string(forKey: appearanceKey),
           let mode = AppearanceMode(rawValue: savedAppearance) {
            self.appearance = mode
        } else {
            self.appearance = .system
        }
        
        // Load enabled formats (default: all built-in formats enabled)
        if let savedFormats = UserDefaults.standard.array(forKey: enabledFormatsKey) as? [String] {
            self.enabledFormats = Set(savedFormats)
        } else {
            // Default: enable all built-in formats
            self.enabledFormats = Set(FilmStock.FilmFormat.allCases.map { $0.displayName })
        }
        
        // Load custom formats
        self.customFormats = UserDefaults.standard.array(forKey: customFormatsKey) as? [String] ?? []
        
        // Load filter preferences (default: empty/disabled)
        self.filterManufacturers = Set(UserDefaults.standard.array(forKey: filterManufacturersKey) as? [String] ?? [])
        self.filterTypes = Set(UserDefaults.standard.array(forKey: filterTypesKey) as? [String] ?? [])
        self.filterSpeedRanges = Set(UserDefaults.standard.array(forKey: filterSpeedRangesKey) as? [String] ?? [])
        self.filterFormats = Set(UserDefaults.standard.array(forKey: filterFormatsKey) as? [String] ?? [])
        self.filterShowExpiredOnly = UserDefaults.standard.object(forKey: filterShowExpiredOnlyKey) as? Bool ?? false
        self.filterShowFrozenOnly = UserDefaults.standard.object(forKey: filterShowFrozenOnlyKey) as? Bool ?? false
        
        // Load sort preferences (default: manufacturer, ascending)
        self.sortField = UserDefaults.standard.string(forKey: sortFieldKey) ?? "manufacturer"
        self.sortAscending = UserDefaults.standard.object(forKey: sortAscendingKey) as? Bool ?? true
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    var id: String { rawValue }
    
    var localizedName: String {
        switch self {
        case .system: return NSLocalizedString("settings.appearance.system", comment: "")
        case .light: return NSLocalizedString("settings.appearance.light", comment: "")
        case .dark: return NSLocalizedString("settings.appearance.dark", comment: "")
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

