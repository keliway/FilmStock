//
//  FilmRowView.swift
//  FilmStock
//
//  Table row view (iOS List style)
//

import SwiftUI

struct FilmRowView: View {
    let groupedFilm: GroupedFilm
    @EnvironmentObject var dataManager: FilmStockDataManager
    @State private var image: UIImage?
    @State private var showingEdit = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Logo (small)
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
            
            // Menu button for edit/delete
            Menu {
                Button("Edit", systemImage: "pencil") {
                    showingEdit = true
                }
                Button("Delete", systemImage: "trash", role: .destructive) {
                    showingDeleteAlert = true
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showingEdit) {
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
        .onAppear {
            loadImage()
        }
    }
    
    private func deleteFilm() {
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
    
    private func loadImage() {
        // First, try user-uploaded image if imageName is specified
        if let customImageName = groupedFilm.imageName {
            if let userImage = ImageStorage.shared.loadImage(filename: customImageName, manufacturer: groupedFilm.manufacturer) {
                self.image = userImage
                return
            }
        }
        
        // Then try bundle images
        var variations: [String] = []
        
        // First, try custom imageName if specified (for bundle images)
        if let customImageName = groupedFilm.imageName {
            variations.append(customImageName + ".png")
            variations.append(customImageName.lowercased() + ".png")
        }
        
        // Then try auto-detected name from film name
        let baseName = groupedFilm.name.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "", options: .regularExpression)
        variations.append(contentsOf: [
            baseName + ".png",
            baseName.lowercased() + ".png",
            baseName.capitalized + ".png",
            baseName.uppercased() + ".png"
        ])
        
        // Add variation where only first letter is capitalized and rest is lowercase
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

struct FilmRowViewContent: View {
    let groupedFilm: GroupedFilm
    @EnvironmentObject var dataManager: FilmStockDataManager
    @State private var image: UIImage?
    
    var body: some View {
        HStack(spacing: 12) {
            // Logo (small)
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
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.trailing, 16)
        }
        .padding(.leading, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            loadImage()
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
    
    private func loadImage() {
        // First, try user-uploaded image if imageName is specified
        if let customImageName = groupedFilm.imageName {
            if let userImage = ImageStorage.shared.loadImage(filename: customImageName, manufacturer: groupedFilm.manufacturer) {
                self.image = userImage
                return
            }
        }
        
        // Then try bundle images
        var variations: [String] = []
        
        // First, try custom imageName if specified (for bundle images)
        if let customImageName = groupedFilm.imageName {
            variations.append(customImageName + ".png")
            variations.append(customImageName.lowercased() + ".png")
        }
        
        // Then try auto-detected name from film name
        let baseName = groupedFilm.name.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "", options: .regularExpression)
        variations.append(contentsOf: [
            baseName + ".png",
            baseName.lowercased() + ".png",
            baseName.capitalized + ".png",
            baseName.uppercased() + ".png"
        ])
        
        // Add variation where only first letter is capitalized and rest is lowercase
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

