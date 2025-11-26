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

