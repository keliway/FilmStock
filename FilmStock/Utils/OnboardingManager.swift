//
//  OnboardingManager.swift
//  FilmStock
//
//  Manages onboarding state and tooltip visibility
//

import Foundation

class OnboardingManager {
    static let shared = OnboardingManager()
    
    private let hasCompletedOnboardingKey = "hasCompletedOnboarding"
    private let hasSeenTooltipKey = "hasSeenTooltip_"
    
    private init() {}
    
    var hasCompletedOnboarding: Bool {
        get {
            UserDefaults.standard.bool(forKey: hasCompletedOnboardingKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: hasCompletedOnboardingKey)
        }
    }
    
    func hasSeenTooltip(_ id: String) -> Bool {
        UserDefaults.standard.bool(forKey: hasSeenTooltipKey + id)
    }
    
    func markTooltipSeen(_ id: String) {
        UserDefaults.standard.set(true, forKey: hasSeenTooltipKey + id)
    }
    
    func resetOnboarding() {
        hasCompletedOnboarding = false
        // Clear all tooltip flags
        let keys = UserDefaults.standard.dictionaryRepresentation().keys
        for key in keys where key.hasPrefix(hasSeenTooltipKey) {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}

