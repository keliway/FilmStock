//
//  ImageCatalogView.swift
//  FilmStock
//
//  Gallery view showing default catalog and custom images
//

import SwiftUI

struct SquareGridThumbnail: View {
    let image: UIImage

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
    }
}

struct ImageCatalogView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedImage: UIImage?
    @Binding var selectedImageFilename: String?
    @Binding var selectedImageSource: ImageSource?

    private struct CustomPhotoEntry: Identifiable {
        var id: String { "\(manufacturer)/\(filename)" }
        let filename: String
        let manufacturer: String
        let image: UIImage
    }

    @State private var imagesByManufacturer: [String: [(imageName: String, image: UIImage)]] = [:]
    @State private var customPhotos: [CustomPhotoEntry] = []
    @State private var isLoading = true
    @State private var catalogMode: CatalogMode = .defaultCatalog
    @State private var searchText: String = ""
    // manufacturer name (lowercased) → [filmName (lowercased): [alias (lowercased)]]
    @State private var aliasMap: [String: [String: [String]]] = [:]

    private static let gridColumns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

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

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var sortedManufacturers: [String] {
        filteredImagesByManufacturer.keys.sorted()
    }

    var filteredImagesByManufacturer: [String: [(imageName: String, image: UIImage)]] {
        let q = trimmedQuery
        guard !q.isEmpty else { return imagesByManufacturer }

        var result: [String: [(imageName: String, image: UIImage)]] = [:]
        for (manufacturer, images) in imagesByManufacturer {
            let mfrLower = manufacturer.lowercased()
            let filmAliases = aliasMap[mfrLower] ?? [:]

            let matching = images.filter { item in
                let nameLower = item.imageName.lowercased()
                if mfrLower.contains(q) || nameLower.contains(q) { return true }
                let aliases = filmAliases[nameLower] ?? []
                return aliases.contains { $0.contains(q) }
            }
            if !matching.isEmpty {
                result[manufacturer] = matching
            }
        }
        return result
    }

    private var filteredCustomPhotos: [CustomPhotoEntry] {
        let q = trimmedQuery
        guard !q.isEmpty else { return customPhotos }
        return customPhotos.filter {
            $0.manufacturer.lowercased().contains(q) || $0.filename.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Catalog Mode", selection: $catalogMode) {
                    ForEach(CatalogMode.allCases) { mode in
                        Text(mode.localizedName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                Group {
                    if isLoading {
                        Spacer()
                        ProgressView()
                        Spacer()
                    } else if catalogMode == .defaultCatalog {
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
            .task {
                await loadCatalogData()
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
        } else if !trimmedQuery.isEmpty && filteredImagesByManufacturer.isEmpty {
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

                                LazyVGrid(columns: Self.gridColumns, spacing: 8) {
                                    ForEach(images, id: \.imageName) { item in
                                        Button {
                                            selectedImage = item.image
                                            selectedImageFilename = "\(manufacturer.lowercased())_\(item.imageName)"
                                            selectedImageSource = .catalog
                                            dismiss()
                                        } label: {
                                            SquareGridThumbnail(image: item.image)
                                        }
                                        .buttonStyle(.plain)
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
        } else if !trimmedQuery.isEmpty && filteredCustomPhotos.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            ScrollView {
                LazyVGrid(columns: Self.gridColumns, spacing: 8) {
                    ForEach(filteredCustomPhotos) { item in
                        Button {
                            selectedImage = item.image
                            selectedImageFilename = item.id
                            selectedImageSource = .custom
                            dismiss()
                        } label: {
                            SquareGridThumbnail(image: item.image)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
        }
    }

    private func loadCatalogData() async {
        let loaded = await Task.detached(priority: .userInitiated) {
            let defaults = ImageStorage.shared.getAllDefaultImages()
            let customs = ImageStorage.shared.getAllCustomPhotos().map {
                CustomPhotoEntry(filename: $0.filename, manufacturer: $0.manufacturer, image: $0.image)
            }
            var aliases: [String: [String: [String]]] = [:]
            for mfr in ImageStorage.shared.loadManufacturersData() {
                let mfrKey = mfr.name.lowercased()
                var filmMap: [String: [String]] = [:]
                for film in mfr.films {
                    filmMap[film.filename.lowercased()] = film.aliases.map { $0.lowercased() }
                }
                aliases[mfrKey] = filmMap
            }
            return (defaults, customs, aliases)
        }.value

        imagesByManufacturer = loaded.0
        customPhotos = loaded.1
        aliasMap = loaded.2
        isLoading = false
    }
}
