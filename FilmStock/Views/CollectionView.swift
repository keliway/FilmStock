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
    @State private var isEditMode = false
    @State private var selectedItems: Set<String> = []
    
    var body: some View {
        NavigationStack {
            if filmsWithImages.isEmpty {
                ContentUnavailableView(
                    "No Film Reminder Cards (yet)",
                    systemImage: "camera.viewfinder",
                    description: Text("Upload your own film reminders when adding/editing a film and start your own collection!")
                )
            } else {
                ZStack {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8)
                        ], spacing: 8) {
                            ForEach(Array(filmsWithImages.enumerated()), id: \.element.id) { index, item in
                                ZStack(alignment: .topTrailing) {
                                    Button {
                                        if isEditMode {
                                            // Toggle selection in edit mode
                                            if selectedItems.contains(item.id) {
                                                selectedItems.remove(item.id)
                                            } else {
                                                selectedItems.insert(item.id)
                                            }
                                        } else {
                                            // Open detail view in normal mode
                                            selectedIndex = index
                                        }
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
                                            .overlay(
                                                // Selection overlay
                                                Group {
                                                    if isEditMode {
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .fill(Color.black.opacity(selectedItems.contains(item.id) ? 0.3 : 0))
                                                    }
                                                }
                                            )
                                    }
                                    
                                    // Selection checkmark
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
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .padding(.bottom, isEditMode && !selectedItems.isEmpty ? 80 : 0)
                    }
                    
                    // Floating delete button at bottom right
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
        .navigationTitle("My Collection")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditMode {
                    Button("Done") {
                        isEditMode = false
                        selectedItems.removeAll()
                    }
                } else {
                    Button("Edit") {
                        isEditMode = true
                    }
                }
            }
        }
        .onAppear {
            loadCollectionItems()
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
        .alert("Delete Image", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if isEditMode && !selectedItems.isEmpty {
                    // Delete multiple selected items
                    let itemsToDelete = filmsWithImages.filter { selectedItems.contains($0.id) }
                    for item in itemsToDelete {
                        deleteImage(item)
                    }
                    selectedItems.removeAll()
                    isEditMode = false
                } else if let item = itemToDelete {
                    // Delete single item from context menu
                    deleteImage(item)
                }
            }
        } message: {
            if isEditMode && !selectedItems.isEmpty {
                let count = selectedItems.count
                Text("Are you sure you want to delete \(count) image\(count == 1 ? "" : "s")?")
            } else if let item = itemToDelete {
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

