//
//  SettingsView.swift
//  FilmStock
//
//  Settings view with app preferences and support
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var settingsManager = SettingsManager.shared
    @Binding var hideEmpty: Bool
    @Binding var viewMode: BrowseView.ViewMode
    
    var body: some View {
        NavigationStack {
            List {
                // My Films Section
                Section {
                    Toggle("Never show empty films", isOn: Binding(
                        get: { settingsManager.hideEmptyByDefault },
                        set: { newValue in
                            settingsManager.hideEmptyByDefault = newValue
                            hideEmpty = newValue
                        }
                    ))
                    Toggle("Always show the table view", isOn: Binding(
                        get: { settingsManager.useTableViewByDefault },
                        set: { newValue in
                            settingsManager.useTableViewByDefault = newValue
                            viewMode = newValue ? .list : .cards
                        }
                    ))
                } header: {
                    Text("My Films")
                } footer: {
                    Text("These settings control the default view when you open the app.")
                }
                
                // General Section
                Section {
                    // Appearance
                    NavigationLink {
                        AppearanceSettingsView()
                    } label: {
                        HStack {
                            Text("Appearance")
                            Spacer()
                            Text(settingsManager.appearance.rawValue)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Version
                    HStack {
                        Text("Version")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }
                    
                    // About
                    NavigationLink {
                        AboutView()
                    } label: {
                        Text("About")
                    }
                } header: {
                    Text("General")
                }
                
                // Support Section
                Section {
                    NavigationLink {
                        SupportView()
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "cup.and.heat.waves.fill")
                                .font(.title2)
                                .foregroundColor(.orange)
                                .frame(width: 32)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Buy Me a Coffee")
                                    .font(.body)
                                Text("Support the development")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                } header: {
                    Text("Support")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(settingsManager.appearance.colorScheme)
    }
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var hideEmpty = true
        @State private var viewMode: BrowseView.ViewMode = .cards
        
        var body: some View {
            SettingsView(hideEmpty: $hideEmpty, viewMode: $viewMode)
        }
    }
    
    return PreviewWrapper()
}

