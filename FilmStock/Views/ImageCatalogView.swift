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
    @Binding var selectedImageFilename: String?
    @Binding var selectedImageSource: ImageSource?
    @State private var imagesByManufacturer: [String: [(imageName: String, image: UIImage)]] = [:]
    @State private var customPhotos: [(filename: String, manufacturer: String, image: UIImage)] = []
    @State private var catalogMode: CatalogMode = .defaultCatalog
    @State private var searchText: String = ""
    // manufacturer name (lowercased) → [filmName (lowercased): [alias (lowercased)]]
    @State private var aliasMap: [String: [String: [String]]] = [:]

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
        filteredImagesByManufacturer.keys.sorted()
    }

    // Filtered catalog: when search is active, keep only matching images per manufacturer.
    var filteredImagesByManufacturer: [String: [(imageName: String, image: UIImage)]] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return imagesByManufacturer }

        var result: [String: [(imageName: String, image: UIImage)]] = [:]
        for (manufacturer, images) in imagesByManufacturer {
            let mfrLower = manufacturer.lowercased()
            let filmAliases = aliasMap[mfrLower] ?? [:]

            let matching = images.filter { item in
                let nameLower = item.imageName.lowercased()
                // Match manufacturer name
                if mfrLower.contains(q) { return true }
                // Match image filename
                if nameLower.contains(q) { return true }
                // Match any alias from the JSON
                let aliases = filmAliases[nameLower] ?? []
                return aliases.contains { $0.contains(q) }
            }
            if !matching.isEmpty {
                result[manufacturer] = matching
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented control — hidden while searching
                if searchText.isEmpty {
                    Picker("Catalog Mode", selection: $catalogMode) {
                        ForEach(CatalogMode.allCases) { mode in
                            Text(mode.localizedName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()
                }

                // Content
                Group {
                    if !searchText.isEmpty || catalogMode == .defaultCatalog {
                        defaultCatalogView
                    } else {
                        myPhotosView
                    }
                }
            }
            .navigationTitle("image.catalog")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: Text(LocalizedStringKey("image.search.prompt")))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("action.done") { dismiss() }
                }
            }
            .onAppear {
                loadImages()
                loadCustomPhotos()
                loadAliasMap()
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
        } else if !searchText.isEmpty && filteredImagesByManufacturer.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    ForEach(sortedManufacturers, id: \.self) { manufacturer in
                        if let images = filteredImagesByManufacturer[manufacturer] {
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

    /// Build a fast lookup: manufacturerLower → filmnameLower → [aliasLower]
    private func loadAliasMap() {
        var map: [String: [String: [String]]] = [:]
        for mfr in ImageStorage.shared.loadManufacturersData() {
            let mfrKey = mfr.name.lowercased()
            var filmMap: [String: [String]] = [:]
            for film in mfr.films {
                let nameKey = film.filename.lowercased()
                filmMap[nameKey] = film.aliases.map { $0.lowercased() }
            }
            map[mfrKey] = filmMap
        }
        aliasMap = map
    }
}

