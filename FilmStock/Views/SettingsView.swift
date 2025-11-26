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
                    Toggle("settings.hideEmpty", isOn: Binding(
                        get: { settingsManager.hideEmptyByDefault },
                        set: { newValue in
                            settingsManager.hideEmptyByDefault = newValue
                            hideEmpty = newValue
                        }
                    ))
                    Toggle("settings.tableView", isOn: Binding(
                        get: { settingsManager.useTableViewByDefault },
                        set: { newValue in
                            settingsManager.useTableViewByDefault = newValue
                            viewMode = newValue ? .list : .cards
                        }
                    ))
                } header: {
                    Text("settings.myFilms")
                } footer: {
                    Text("settings.hideEmpty.footer")
                }
                
                // Film Formats Section
                Section {
                    NavigationLink {
                        ManageFormatsView()
                    } label: {
                        HStack {
                            Text("settings.formats")
                            Spacer()
                            Text("\(settingsManager.enabledFormats.count)")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("settings.formats.header")
                } footer: {
                    Text("settings.formats.footer")
                }
                
                // General Section
                Section {
                    // Appearance
                    NavigationLink {
                        AppearanceSettingsView()
                    } label: {
                        HStack {
                            Text("settings.appearance")
                            Spacer()
                            Text(settingsManager.appearance.localizedName)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Version
                    HStack {
                        Text("settings.version")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }
                    
                    // About
                    NavigationLink {
                        AboutView()
                    } label: {
                        Text("settings.about")
                    }
                } header: {
                    Text("settings.general")
                }
                
                // Support Section
                Section {
                    NavigationLink {
                        SupportView()
                    } label: {
                        HStack(spacing: 16) {
                            if #available(iOS 17.4, *) {
                                Image(systemName: "cup.and.heat.waves.fill")
                                    .font(.title2)
                                    .foregroundColor(.orange)
                                    .frame(width: 32)
                            } else {
                                Image(systemName: "heart.fill")
                                    .font(.title2)
                                    .foregroundColor(.orange)
                                    .frame(width: 32)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("support.buyMeCoffee")
                                    .font(.body)
                                Text("support.description")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                } header: {
                    Text("settings.support")
                }
            }
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("action.done") {
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

