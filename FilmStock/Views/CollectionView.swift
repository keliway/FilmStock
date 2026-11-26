//
//  CollectionView.swift
//  FilmStock
//
//  My Collection - Gallery of custom uploaded images
//

import SwiftUI
import SwiftData
import WidgetKit

struct CollectionView: View {
    @EnvironmentObject var dataManager: FilmStockDataManager
    @Environment(\.modelContext) private var modelContext
    @State private var filmsWithImages: [CollectionItem] = []
    @State private var selectedIndex: Int?
    @State private var showingDeleteAlert = false
    @State private var itemToDelete: CollectionItem?
    @State private var isEditMode = false
    @State private var selectedItems: Set<String> = []
    @State private var showingHelp = false

    private static let gridColumns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        Group {
            if filmsWithImages.isEmpty {
                ContentUnavailableView(
                    "empty.noCollection.title",
                    systemImage: "camera.viewfinder",
                    description: Text("empty.noCollection.message")
                )
            } else {
                ZStack {
                    ScrollView {
                        LazyVGrid(columns: Self.gridColumns, spacing: 8) {
                            ForEach(Array(filmsWithImages.enumerated()), id: \.element.id) { index, item in
                                ZStack(alignment: .topTrailing) {
                                    Button {
                                        if isEditMode {
                                            if selectedItems.contains(item.id) {
                                                selectedItems.remove(item.id)
                                            } else {
                                                selectedItems.insert(item.id)
                                            }
                                        } else {
                                            selectedIndex = index
                                        }
                                    } label: {
                                        SquareGridThumbnail(image: item.image)
                                            .overlay(
                                                Group {
                                                    if isEditMode {
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .fill(Color.black.opacity(selectedItems.contains(item.id) ? 0.3 : 0))
                                                    }
                                                }
                                            )
                                    }
                                    .buttonStyle(.plain)

                                    if isEditMode {
                                        Image(systemName: selectedItems.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                            .font(.title2)
                                            .foregroundColor(selectedItems.contains(item.id) ? .blue : .white)
                                            .background(
                                                Circle()
                                                    .fill(Color.white.opacity(0.8))
                                            )
                                            .padding(8)
                                    }
                                }
                                .contextMenu {
                                    if !isEditMode {
                                        Button(role: .destructive) {
                                            itemToDelete = item
                                            showingDeleteAlert = true
                                        } label: {
                                            Label("action.delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .padding(.bottom, isEditMode && !selectedItems.isEmpty ? 80 : 0)
                    }

                    if isEditMode && !selectedItems.isEmpty {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Button {
                                    showingDeleteAlert = true
                                } label: {
                                    Image(systemName: "trash.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .frame(width: 56, height: 56)
                                        .background(Color.red)
                                        .clipShape(Circle())
                                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                                }
                                .padding(.trailing, 20)
                                .padding(.bottom, 20)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("tab.collection")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    showingHelp = true
                } label: {
                    Image(systemName: "questionmark.circle")
                }

                if !filmsWithImages.isEmpty {
                    if isEditMode {
                        Button("action.done") {
                            isEditMode = false
                            selectedItems.removeAll()
                        }
                    } else {
                        Button("action.edit") {
                            isEditMode = true
                        }
                    }
                }
            }
        }
        .onAppear {
            Task { await reloadCollectionItems() }
        }
        .onChange(of: dataManager.filmStocksVersion) { _, _ in
            Task { await reloadCollectionItems() }
        }
        .sheet(isPresented: Binding(
            get: { selectedIndex != nil && !isEditMode },
            set: { if !$0 { selectedIndex = nil } }
        )) {
            if let index = selectedIndex, index < filmsWithImages.count {
                ImageDetailView(
                    items: filmsWithImages,
                    initialIndex: index
                )
            }
        }
        .alert("delete.image.title", isPresented: $showingDeleteAlert) {
            Button("action.cancel", role: .cancel) {
                itemToDelete = nil
            }
            Button("action.delete", role: .destructive) {
                if isEditMode && !selectedItems.isEmpty {
                    let itemsToDelete = filmsWithImages.filter { selectedItems.contains($0.id) }
                    deleteImages(itemsToDelete)
                    selectedItems.removeAll()
                    isEditMode = false
                } else if let item = itemToDelete {
                    deleteImages([item])
                }
                itemToDelete = nil
            }
        } message: {
            if isEditMode && !selectedItems.isEmpty {
                let count = selectedItems.count
                Text(String(format: NSLocalizedString("alert.deleteImage.multiple", comment: ""), count))
            } else if let item = itemToDelete {
                Text(String(format: NSLocalizedString("alert.deleteImage.single", comment: ""), item.title))
            }
        }
        .alert("help.collection.title", isPresented: $showingHelp) {
            Button("action.done", role: .cancel) { }
        } message: {
            Text("help.collection.message")
        }
    }

    private func reloadCollectionItems() async {
        let allPhotos = await Task.detached(priority: .userInitiated) {
            ImageStorage.shared.getAllCustomPhotos()
        }.value

        let allFilms = (try? modelContext.fetch(FetchDescriptor<Film>())) ?? []
        var items: [CollectionItem] = []
        var seenIds: Set<String> = []

        for photo in allPhotos {
            let uniqueId = "\(photo.manufacturer)/\(photo.filename)"
            guard seenIds.insert(uniqueId).inserted else { continue }

            var title = photo.manufacturer
            for film in allFilms {
                guard ImageSource(rawValue: film.imageSource) == .custom,
                      let filmImageName = film.imageName else { continue }
                let mfrName = film.manufacturer?.name ?? ""
                let (storedManufacturer, storedFilename) = ImageStorage.parseCustomImageName(
                    filmImageName,
                    defaultManufacturer: mfrName
                )
                if storedManufacturer == photo.manufacturer && storedFilename == photo.filename {
                    title = mfrName.isEmpty ? film.name : "\(mfrName) \(film.name)"
                    break
                }
            }

            items.append(CollectionItem(
                id: uniqueId,
                image: photo.image,
                imageName: photo.filename,
                manufacturer: photo.manufacturer,
                title: title
            ))
        }

        filmsWithImages = items
    }

    private func deleteImages(_ items: [CollectionItem]) {
        guard !items.isEmpty else { return }

        let targetPairs = Set(items.map { "\($0.manufacturer)/\($0.imageName)" })
        for item in items {
            ImageStorage.shared.deleteImage(filename: item.imageName, manufacturer: item.manufacturer)
        }

        let allFilms = (try? modelContext.fetch(FetchDescriptor<Film>())) ?? []
        for film in allFilms {
            guard ImageSource(rawValue: film.imageSource) == .custom,
                  let filmImageName = film.imageName else { continue }
            let mfrName = film.manufacturer?.name ?? ""
            let (storedManufacturer, storedFilename) = ImageStorage.parseCustomImageName(
                filmImageName,
                defaultManufacturer: mfrName
            )
            if targetPairs.contains("\(storedManufacturer)/\(storedFilename)") {
                film.imageName = nil
                film.imageSource = ImageSource.autoDetected.rawValue
            }
        }

        try? modelContext.save()
        dataManager.loadFilmStocks()
        NotificationCenter.default.post(name: NSNotification.Name("LoadedFilmsChanged"), object: nil)
        WidgetCenter.shared.reloadTimelines(ofKind: "LoadedFilmsWidget")
        Task { await reloadCollectionItems() }
    }
}

struct CollectionItem: Identifiable {
    let id: String
    let image: UIImage
    let imageName: String
    let manufacturer: String
    let title: String
}

struct ImageDetailView: View {
    let items: [CollectionItem]
    let initialIndex: Int
    @State private var currentIndex: Int
    @Environment(\.dismiss) var dismiss

    init(items: [CollectionItem], initialIndex: Int) {
        self.items = items
        self.initialIndex = initialIndex
        _currentIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                TabView(selection: $currentIndex) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        VStack {
                            Spacer()

                            Image(uiImage: item.image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding()

                            Spacer()

                            Text(item.title)
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.bottom, 40)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle(String(format: NSLocalizedString("collection.imagePosition", comment: ""), currentIndex + 1, items.count))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("action.done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}
