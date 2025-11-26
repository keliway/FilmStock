//
//  ManageFormatsView.swift
//  FilmStock
//
//  Manage film formats - enable/disable and add custom formats
//

import SwiftUI

struct ManageFormatsView: View {
    @ObservedObject var settingsManager = SettingsManager.shared
    @State private var showingAddFormat = false
    @State private var newFormatName = ""
    @State private var showDuplicateError = false
    
    var builtInFormats: [String] {
        FilmStock.FilmFormat.allCases.map { $0.displayName }
    }
    
    var isDuplicate: Bool {
        let trimmed = newFormatName.trimmingCharacters(in: .whitespacesAndNewlines)
        return builtInFormats.contains(trimmed) || settingsManager.customFormats.contains(trimmed)
    }
    
    var body: some View {
        List {
            // Built-in formats section
            Section {
                ForEach(builtInFormats, id: \.self) { format in
                    Button {
                        settingsManager.toggleFormat(format)
                    } label: {
                        HStack {
                            Text(format)
                                .foregroundColor(.primary)
                            Spacer()
                            if settingsManager.isFormatEnabled(format) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            } header: {
                Text("formats.builtIn")
            } footer: {
                Text("formats.builtIn.footer")
            }
            
            // Custom formats section
            Section {
                if settingsManager.customFormats.isEmpty {
                    Text("formats.noCustom")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(settingsManager.customFormats, id: \.self) { format in
                        Button {
                            settingsManager.toggleFormat(format)
                        } label: {
                            HStack {
                                Text(format)
                                    .foregroundColor(.primary)
                                Spacer()
                                if settingsManager.isFormatEnabled(format) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let format = settingsManager.customFormats[index]
                            settingsManager.deleteCustomFormat(format)
                        }
                    }
                }
            } header: {
                Text("formats.custom")
            } footer: {
                if !settingsManager.customFormats.isEmpty {
                    Text("formats.custom.footer")
                }
            }
            
            // Add custom format button at the bottom
            Section {
                Button {
                    newFormatName = ""
                    showingAddFormat = true
                } label: {
                    Label("formats.addCustom", systemImage: "plus.circle")
                }
            }
        }
        .navigationTitle("formats.manage")
        .navigationBarTitleDisplayMode(.inline)
        .alert("formats.add", isPresented: $showingAddFormat) {
            TextField("formats.name", text: $newFormatName)
                .autocorrectionDisabled()
            Button("action.cancel", role: .cancel) {
                newFormatName = ""
            }
            Button("action.add") {
                let trimmed = newFormatName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty && !isDuplicate {
                    settingsManager.addCustomFormat(trimmed)
                } else if isDuplicate {
                    showDuplicateError = true
                }
                newFormatName = ""
            }
            .disabled(newFormatName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isDuplicate)
        } message: {
            if isDuplicate {
                Text("formats.duplicateError")
            } else {
                Text("formats.addMessage")
            }
        }
        .alert("formats.duplicateTitle", isPresented: $showDuplicateError) {
            Button("action.ok", role: .cancel) { }
        } message: {
            Text("formats.duplicateMessage")
        }
    }
}

