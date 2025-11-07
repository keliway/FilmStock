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
    
    private init() {
        // Load saved settings or use defaults
        self.hideEmptyByDefault = UserDefaults.standard.object(forKey: hideEmptyKey) as? Bool ?? true
        self.useTableViewByDefault = UserDefaults.standard.object(forKey: defaultViewModeKey) as? Bool ?? false
        
        if let savedAppearance = UserDefaults.standard.string(forKey: appearanceKey),
           let mode = AppearanceMode(rawValue: savedAppearance) {
            self.appearance = mode
        } else {
            self.appearance = .system
        }
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    var id: String { rawValue }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

