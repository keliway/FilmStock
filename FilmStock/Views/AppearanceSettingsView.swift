//
//  AppearanceSettingsView.swift
//  FilmStock
//
//  Appearance settings for light/dark mode
//

import SwiftUI

struct AppearanceSettingsView: View {
    @ObservedObject var settingsManager = SettingsManager.shared
    
    var body: some View {
        List {
            ForEach(AppearanceMode.allCases) { mode in
                Button {
                    settingsManager.appearance = mode
                } label: {
                    HStack {
                        Text(mode.localizedName)
                            .foregroundColor(.primary)
                        Spacer()
                        if settingsManager.appearance == mode {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
        }
        .navigationTitle("settings.appearance")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(settingsManager.appearance.colorScheme)
    }
}

#Preview {
    NavigationStack {
        AppearanceSettingsView()
    }
}

