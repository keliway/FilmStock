//
//  ManageCamerasView.swift
//  FilmStock
//
//  Manage cameras for loading films
//

import SwiftUI

struct ManageCamerasView: View {
    @EnvironmentObject var dataManager: FilmStockDataManager
    @Environment(\.dismiss) var dismiss
    
    @State private var showingAddCamera = false
    @State private var newCameraName = ""
    @State private var showDuplicateError = false
    @State private var showDeleteError = false
    @State private var deleteErrorMessage = ""
    
    var allCameras: [Camera] {
        dataManager.getAllCameras()
    }
    
    var isDuplicate: Bool {
        let trimmedName = newCameraName.trimmingCharacters(in: .whitespacesAndNewlines)
        return allCameras.contains(where: { $0.name.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame })
    }
    
    var body: some View {
        NavigationStack {
            List {
                if allCameras.isEmpty {
                    Section {
                        Text("cameras.empty")
                            .foregroundColor(.secondary)
                    }
                } else {
                    Section {
                        ForEach(allCameras, id: \.name) { camera in
                            Text(camera.name)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let camera = allCameras[index]
                                if !dataManager.deleteCamera(camera) {
                                    showDeleteError = true
                                    deleteErrorMessage = String(format: NSLocalizedString("camera.deleteErrorMessage", comment: ""), camera.name)
                                }
                            }
                        }
                    } footer: {
                        Text("cameras.swipeToDelete")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("cameras.manage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("action.done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        newCameraName = ""
                        showingAddCamera = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("camera.add", isPresented: $showingAddCamera) {
                TextField("camera.name", text: $newCameraName)
                    .autocorrectionDisabled()
                Button("action.cancel", role: .cancel) {
                    newCameraName = ""
                }
                Button("action.add") {
                    let trimmedName = newCameraName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedName.isEmpty && !isDuplicate {
                        _ = dataManager.addCamera(name: trimmedName)
                    } else if isDuplicate {
                        showDuplicateError = true
                    }
                    newCameraName = ""
                }
                .disabled(newCameraName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isDuplicate)
            } message: {
                if isDuplicate {
                    Text("camera.duplicateError")
                } else {
                    Text("camera.addMessage")
                }
            }
            .alert("camera.duplicateTitle", isPresented: $showDuplicateError) {
                Button("action.ok", role: .cancel) { }
            } message: {
                Text("camera.duplicateMessage")
            }
            .alert("camera.deleteError", isPresented: $showDeleteError) {
                Button("action.ok", role: .cancel) { }
            } message: {
                Text(deleteErrorMessage)
            }
        }
    }
}

