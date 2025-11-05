//
//  ManageView.swift
//  FilmStock
//
//  Manage view with table (iOS HIG style)
//

import SwiftUI

struct ManageView: View {
    @EnvironmentObject var dataManager: FilmStockDataManager
    @State private var searchText = ""
    @State private var showingAddFilm = false
    
    var filteredFilms: [GroupedFilm] {
        var grouped = dataManager.groupedFilms()
        
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            grouped = grouped.filter {
                $0.name.lowercased().contains(query) ||
                $0.manufacturer.lowercased().contains(query)
            }
        }
        
        return grouped
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredFilms) { group in
                    FilmManageRowView(groupedFilm: group)
                }
            }
            .navigationTitle("Manage Films")
            .searchable(text: $searchText, prompt: "Search films")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddFilm = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddFilm) {
                AddFilmView()
            }
        }
    }
}

struct FilmManageRowView: View {
    let groupedFilm: GroupedFilm
    @EnvironmentObject var dataManager: FilmStockDataManager
    @State private var image: UIImage?
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Logo
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 20, height: 20)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(groupedFilm.name)
                    .font(.body)
                
                Text(groupedFilm.manufacturer)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Format quantities
            HStack(spacing: 12) {
                formatQty(groupedFilm.formats, format: .thirtyFive)
                formatQty(groupedFilm.formats, format: .oneTwenty)
                formatQty(groupedFilm.formats, format: .fourByFive)
            }
            
            Menu {
                Button("Edit", systemImage: "pencil") {
                    showingEditSheet = true
                }
                Button("Delete", systemImage: "trash", role: .destructive) {
                    showingDeleteAlert = true
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        .onAppear {
            loadImage()
        }
        .sheet(isPresented: $showingEditSheet) {
            EditFilmView(groupedFilm: groupedFilm)
                .environmentObject(dataManager)
        }
        .alert("Delete Film", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteFilm()
            }
        } message: {
            Text("Are you sure you want to delete \(groupedFilm.name)?")
        }
    }
    
    @ViewBuilder
    private func formatQty(_ formats: [GroupedFilm.FormatInfo], format: FilmStock.FilmFormat) -> some View {
        let qty = formats
            .filter { normalizeFormat($0.format) == format }
            .reduce(0) { $0 + $1.quantity }
        
        VStack(spacing: 2) {
            Text(format.displayName)
                .font(.caption2)
                .foregroundColor(.secondary)
        Text(qty > 0 ? "\(qty)" : "-")
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .frame(width: 40)
            .multilineTextAlignment(.center)
    }
    
    private func normalizeFormat(_ format: FilmStock.FilmFormat) -> FilmStock.FilmFormat {
        switch format {
        case .oneTwenty, .oneTwentySeven:
            return .oneTwenty
        default:
            return format
        }
    }
    
    private func deleteFilm() {
        // Delete all formats of this grouped film
        let filmsToDelete = dataManager.filmStocks.filter { film in
            film.name == groupedFilm.name &&
            film.manufacturer == groupedFilm.manufacturer &&
            film.type == groupedFilm.type &&
            film.filmSpeed == groupedFilm.filmSpeed
        }
        
        for film in filmsToDelete {
            dataManager.deleteFilmStock(film)
        }
    }
    
    private func loadImage() {
        var variations: [String] = []
        
        // First, try custom imageName if specified
        if let customImageName = groupedFilm.imageName {
            variations.append(customImageName + ".png")
            variations.append(customImageName.lowercased() + ".png")
        }
        
        // Then try auto-detected name from film name
        let baseName = groupedFilm.name.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "", options: .regularExpression)
        variations.append(contentsOf: [
            baseName + ".png",                    // Original case: "Pro400H.png"
            baseName.lowercased() + ".png",       // Lowercase: "pro400h.png"
            baseName.capitalized + ".png",        // Capitalized: "Pro400h.png"
            baseName.uppercased() + ".png"        // Uppercase: "PRO400H.png"
        ])
        
        // Add variation where only first letter is capitalized and rest is lowercase
        // This handles cases like "Pro400H" -> "Pro400h"
        if baseName.count > 1 {
            let firstChar = String(baseName.prefix(1)).uppercased()
            let rest = String(baseName.dropFirst()).lowercased()
            variations.append((firstChar + rest) + ".png")
        }
        
        // Try bundle with manufacturer subdirectory structure
        let manufacturerName = groupedFilm.manufacturer
        
        // Try multiple methods to find images
        var imagePaths: [URL] = []
        
        guard let resourcePath = Bundle.main.resourcePath else { return }
        let resourceURL = URL(fileURLWithPath: resourcePath, isDirectory: true)
        let imagesURL = resourceURL.appendingPathComponent("images", isDirectory: true)
        
        // When images folder is added as a group (yellow folder in Xcode),
        // Xcode flattens subdirectories, so files are in images/ directly
        // Try flattened structure first (most likely for groups)
        for variation in variations {
            let imageURL = imagesURL.appendingPathComponent(variation, isDirectory: false)
            imagePaths.append(imageURL)
        }
        
        // Also try manufacturer subdirectory structure (in case folder references are used)
        let manufacturerURL = imagesURL.appendingPathComponent(manufacturerName, isDirectory: true)
        for variation in variations {
            let imageURL = manufacturerURL.appendingPathComponent(variation, isDirectory: false)
            imagePaths.append(imageURL)
        }
        
        // Try Bundle.main.url methods
        for variation in variations {
            let resourceName = variation.replacingOccurrences(of: ".png", with: "")
            // Try with subdirectory
            if let bundleURL = Bundle.main.url(forResource: resourceName, withExtension: "png", subdirectory: "images/\(manufacturerName)") {
                imagePaths.append(bundleURL)
            }
            // Try without subdirectory (flattened)
            if let bundleURL = Bundle.main.url(forResource: resourceName, withExtension: "png", subdirectory: "images") {
                imagePaths.append(bundleURL)
            }
            // Try at bundle root
            if let bundleURL = Bundle.main.url(forResource: resourceName, withExtension: "png") {
                imagePaths.append(bundleURL)
            }
        }
        
        // Try all paths
        for imageURL in imagePaths {
            if FileManager.default.fileExists(atPath: imageURL.path),
           let data = try? Data(contentsOf: imageURL),
           let uiImage = UIImage(data: data) {
            self.image = uiImage
                return
            }
        }
    }
}

