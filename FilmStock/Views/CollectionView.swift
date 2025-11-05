//
//  CollectionView.swift
//  FilmStock
//
//  My Collection - Gallery of custom uploaded images
//

import SwiftUI
import SwiftData

struct CollectionView: View {
    @EnvironmentObject var dataManager: FilmStockDataManager
    @Environment(\.modelContext) private var modelContext
    @State private var filmsWithImages: [CollectionItem] = []
    @State private var selectedIndex: Int?
    @State private var showingDeleteAlert = false
    @State private var itemToDelete: CollectionItem?
    
    var body: some View {
        NavigationStack {
            if filmsWithImages.isEmpty {
                ContentUnavailableView(
                    "No Images",
                    systemImage: "photo.on.rectangle",
                    description: Text("Upload custom images when adding films to see them here")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8)
                    ], spacing: 8) {
                        ForEach(Array(filmsWithImages.enumerated()), id: \.element.id) { index, item in
                            Button {
                                selectedIndex = index
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
                            .contextMenu {
                                Button(role: .destructive) {
                                    itemToDelete = item
                                    showingDeleteAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle("My Collection")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadCollectionItems()
        }
        .sheet(isPresented: Binding(
            get: { selectedIndex != nil },
            set: { if !$0 { selectedIndex = nil } }
        )) {
            if let index = selectedIndex, index < filmsWithImages.count {
                ImageDetailView(
                    items: filmsWithImages,
                    initialIndex: index
                )
            }
        }
        .alert("Delete Image", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let item = itemToDelete {
                    deleteImage(item)
                }
            }
        } message: {
            if let item = itemToDelete {
                Text("Are you sure you want to delete the image for \(item.title)?")
            }
        }
    }
    
    private func loadCollectionItems() {
        let descriptor = FetchDescriptor<Film>()
        let allFilms = (try? modelContext.fetch(descriptor)) ?? []
        
        var items: [CollectionItem] = []
        
        for film in allFilms {
            if let imageName = film.imageName,
               let manufacturer = film.manufacturer,
               let image = ImageStorage.shared.loadImage(filename: imageName, manufacturer: manufacturer.name) {
                let title = "\(manufacturer.name) \(film.name)"
                // Create unique ID from imageName and manufacturer to avoid duplicates
                let uniqueId = "\(manufacturer.name)_\(imageName)"
                items.append(CollectionItem(
                    id: uniqueId,
                    image: image,
                    imageName: imageName,
                    manufacturer: manufacturer.name,
                    title: title
                ))
            }
        }
        
        filmsWithImages = items
    }
    
    private func deleteImage(_ item: CollectionItem) {
        // Delete the image file
        ImageStorage.shared.deleteImage(filename: item.imageName, manufacturer: item.manufacturer)
        
        // Remove imageName from all films that use this image
        let descriptor = FetchDescriptor<Film>()
        let allFilms = (try? modelContext.fetch(descriptor)) ?? []
        
        for film in allFilms {
            if film.imageName == item.imageName {
                film.imageName = nil
            }
        }
        
        try? modelContext.save()
        dataManager.loadFilmStocks()
        loadCollectionItems()
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
            .navigationTitle("\(currentIndex + 1) of \(items.count)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

