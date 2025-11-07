//
//  ImageCatalogView.swift
//  FilmStock
//
//  Gallery view showing all custom images grouped by manufacturer
//

import SwiftUI

struct ImageCatalogView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedImage: UIImage?
    @Binding var selectedImageFilename: String? // e.g., "ilford_hp5"
    @Binding var selectedImageSource: ImageSource? // Track if it's catalog or custom
    @State private var imagesByManufacturer: [String: [(imageName: String, image: UIImage)]] = [:]
    @State private var customPhotos: [(filename: String, manufacturer: String, image: UIImage)] = []
    @State private var catalogMode: CatalogMode = .defaultCatalog
    
    enum CatalogMode: String, CaseIterable, Identifiable {
        case defaultCatalog
        case myPhotos
        
        var id: String { rawValue }
        
        var localizedName: String {
            switch self {
            case .defaultCatalog: return NSLocalizedString("image.defaultCatalog", comment: "")
            case .myPhotos: return NSLocalizedString("image.myPhotos", comment: "")
            }
        }
    }
    
    var sortedManufacturers: [String] {
        imagesByManufacturer.keys.sorted()
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented control
                Picker("Catalog Mode", selection: $catalogMode) {
                    ForEach(CatalogMode.allCases) { mode in
                        Text(mode.localizedName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content
                Group {
                    if catalogMode == .defaultCatalog {
                        defaultCatalogView
                    } else {
                        myPhotosView
                    }
                }
            }
            .navigationTitle("image.catalog")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("action.done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadImages()
                loadCustomPhotos()
            }
        }
    }
    
    @ViewBuilder
    private var defaultCatalogView: some View {
        if imagesByManufacturer.isEmpty {
            ContentUnavailableView(
                "empty.noCatalogImages.title",
                systemImage: "photo.on.rectangle",
                description: Text("empty.noCatalogImages.message")
            )
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    ForEach(sortedManufacturers, id: \.self) { manufacturer in
                        if let images = imagesByManufacturer[manufacturer] {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(manufacturer)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 16)
                                
                                LazyVGrid(columns: [
                                    GridItem(.flexible(), spacing: 8),
                                    GridItem(.flexible(), spacing: 8),
                                    GridItem(.flexible(), spacing: 8)
                                ], spacing: 8) {
                                    ForEach(images, id: \.imageName) { item in
                                        Button {
                                            selectedImage = item.image
                                            // Store the filename as manufacturer_filmname (without .png)
                                            let manufacturerLower = manufacturer.lowercased()
                                            selectedImageFilename = "\(manufacturerLower)_\(item.imageName)"
                                            selectedImageSource = .catalog
                                            dismiss()
                                        } label: {
                                            Image(uiImage: item.image)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: (UIScreen.main.bounds.width - 64) / 3, height: (UIScreen.main.bounds.width - 64) / 3)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                                )
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                }
                .padding(.vertical, 16)
            }
        }
    }
    
    @ViewBuilder
    private var myPhotosView: some View {
        if customPhotos.isEmpty {
            ContentUnavailableView(
                "empty.noCustomPhotos.title",
                systemImage: "camera",
                description: Text("empty.noCustomPhotos.message")
            )
        } else {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ], spacing: 8) {
                    ForEach(customPhotos, id: \.filename) { item in
                        Button {
                            selectedImage = item.image
                            // Store manufacturer/filename so we can load from correct directory
                            selectedImageFilename = "\(item.manufacturer)/\(item.filename)"
                            selectedImageSource = .custom
                            dismiss()
                        } label: {
                            Image(uiImage: item.image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: (UIScreen.main.bounds.width - 48) / 3, height: (UIScreen.main.bounds.width - 48) / 3)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                        }
                    }
                }
                .padding(16)
            }
        }
    }
    
    private func loadImages() {
        imagesByManufacturer = ImageStorage.shared.getAllDefaultImages()
    }
    
    private func loadCustomPhotos() {
        customPhotos = ImageStorage.shared.getAllCustomPhotos()
    }
}

