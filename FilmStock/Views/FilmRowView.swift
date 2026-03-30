//
//  FilmRowView.swift
//  FilmStock
//
//  Table row view (iOS List style)
//

import SwiftUI

// Helper function to parse custom image name
// Returns (manufacturer, filename) tuple
private func parseCustomImageName(_ imageName: String, defaultManufacturer: String) -> (String, String) {
    if imageName.contains("/") {
        let components = imageName.split(separator: "/", maxSplits: 1)
        if components.count == 2 {
            return (String(components[0]), String(components[1]))
        }
    }
    return (defaultManufacturer, imageName)
}

// MARK: - Browse table columns (built-in format names + Settings custom formats)

private func normalizeFormatForBrowseTable(_ format: FilmStock.FilmFormat) -> FilmStock.FilmFormat {
    switch format {
    case .oneTwenty, .oneTwentySeven: return .oneTwenty
    default: return format
    }
}

/// Stock count for one column label (`FilmFormat.displayName` or a name from `SettingsManager.customFormats`).
private func quantityForBrowseFormatColumn(
    title: String,
    formats: [GroupedFilm.FormatInfo],
    settings: SettingsManager
) -> Int {
    if settings.isCustomFormat(title) {
        return formats
            .filter { $0.format == .other && $0.customFormatName == title }
            .reduce(0) { $0 + $1.quantity }
    }
    guard let builtIn = FilmStock.FilmFormat.allCases.first(where: { $0.displayName == title }) else {
        return 0
    }
    if builtIn == .other {
        return formats
            .filter { info in
                guard info.format == .other else { return false }
                guard let name = info.customFormatName, !name.isEmpty else { return true }
                return !settings.isCustomFormat(name)
            }
            .reduce(0) { $0 + $1.quantity }
    }
    return formats
        .filter { normalizeFormatForBrowseTable($0.format) == normalizeFormatForBrowseTable(builtIn) }
        .reduce(0) { $0 + $1.quantity }
}

@ViewBuilder
private func browseFormatColumn(title: String, formats: [GroupedFilm.FormatInfo], settings: SettingsManager) -> some View {
    let qty = quantityForBrowseFormatColumn(title: title, formats: formats, settings: settings)
    VStack(spacing: 2) {
        Text(title)
            .font(.caption2)
            .foregroundColor(.secondary)
            .lineLimit(2)
            .minimumScaleFactor(0.75)
            .multilineTextAlignment(.center)
        Text(qty > 0 ? "\(qty)" : "-")
            .font(.subheadline)
            .fontWeight(.medium)
    }
    .frame(minWidth: 36, maxWidth: 56)
    .multilineTextAlignment(.center)
}

struct FilmRowView: View {
    let groupedFilm: GroupedFilm
    @EnvironmentObject var dataManager: FilmStockDataManager
    @ObservedObject private var settingsManager = SettingsManager.shared
    @State private var image: UIImage?
    @State private var showingEdit = false
    @State private var showingDeleteAlert = false
    @State private var showingDeleteError = false
    @State private var deleteErrorMessage = ""
    
    private var formatColumnTitles: [String] {
        settingsManager.formatsToShow
    }
    
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
                
                // Format quantities (scrollable horizontally)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(formatColumnTitles, id: \.self) { title in
                            browseFormatColumn(title: title, formats: groupedFilm.formats, settings: settingsManager)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(width: 160)
            
            // Menu button for edit/delete
            Menu {
                Button("action.edit", systemImage: "pencil") {
                    showingEdit = true
                }
                Button("action.delete", systemImage: "trash", role: isFilmLoaded ? nil : .destructive) {
                    if isFilmLoaded {
                        // Show error message instead of deleting
                        let filmsToCheck = dataManager.filmStocks.filter { film in
                            film.name == groupedFilm.name &&
                            film.manufacturer == groupedFilm.manufacturer &&
                            film.type == groupedFilm.type &&
                            film.filmSpeed == groupedFilm.filmSpeed
                        }
                        if let loadedFilm = filmsToCheck.first {
                            deleteErrorMessage = String(format: NSLocalizedString("error.cannotDeleteLoaded", comment: ""), loadedFilm.name)
                            showingDeleteError = true
                        }
                    } else {
                        showingDeleteAlert = true
                    }
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
        .alert("delete.film.title", isPresented: $showingDeleteAlert) {
            Button("action.cancel", role: .cancel) { }
            Button("action.delete", role: .destructive) {
                deleteFilm()
            }
        } message: {
            Text(String(format: NSLocalizedString("delete.film.message", comment: ""), groupedFilm.name))
        }
        .alert("error.cannotDelete.title", isPresented: $showingDeleteError) {
            Button("action.ok", role: .cancel) { }
        } message: {
            Text(deleteErrorMessage)
        }
        .onAppear {
            loadImage()
        }
    }
    
    private var isFilmLoaded: Bool {
        let filmsToCheck = dataManager.filmStocks.filter { film in
            film.name == groupedFilm.name &&
            film.manufacturer == groupedFilm.manufacturer &&
            film.type == groupedFilm.type &&
            film.filmSpeed == groupedFilm.filmSpeed
        }
        return filmsToCheck.contains { dataManager.isFilmLoaded($0) }
    }
    
    private func deleteFilm() {
        let filmsToDelete = dataManager.filmStocks.filter { film in
            film.name == groupedFilm.name &&
            film.manufacturer == groupedFilm.manufacturer &&
            film.type == groupedFilm.type &&
            film.filmSpeed == groupedFilm.filmSpeed
        }
        
        // Check if any of the films are currently loaded
        if let loadedFilm = filmsToDelete.first(where: { dataManager.isFilmLoaded($0) }) {
            deleteErrorMessage = String(format: NSLocalizedString("error.cannotDeleteLoaded", comment: ""), loadedFilm.name)
            showingDeleteError = true
            return
        }
        
        for film in filmsToDelete {
            dataManager.deleteFilmStock(film)
        }
    }
    
    private func loadImage() {
        let imageSource = ImageSource(rawValue: groupedFilm.imageSource) ?? .autoDetected
        
        switch imageSource {
        case .custom:
            // Load user-taken photo
            if let customImageName = groupedFilm.imageName {
                // Handle manufacturer/filename format (for catalog-selected photos)
                let (manufacturer, filename) = parseCustomImageName(customImageName, defaultManufacturer: groupedFilm.manufacturer)
                if let userImage = ImageStorage.shared.loadImage(filename: filename, manufacturer: manufacturer) {
                    self.image = userImage
                    return
                }
            }
            
        case .catalog:
            // Load catalog image by exact filename
            if let catalogImageName = groupedFilm.imageName {
                if let catalogImage = ImageStorage.shared.loadCatalogImage(filename: catalogImageName) {
                    self.image = catalogImage
                    return
                }
            }
            
        case .autoDetected:
            // Auto-detect default image based on manufacturer + film name
            if let defaultImage = ImageStorage.shared.loadDefaultImage(filmName: groupedFilm.name, manufacturer: groupedFilm.manufacturer) {
                self.image = defaultImage
                return
            }
            
        case .none:
            // No image
            self.image = nil
            return
        }
    }
}

struct FilmRowViewContent: View {
    let groupedFilm: GroupedFilm
    @EnvironmentObject var dataManager: FilmStockDataManager
    @ObservedObject private var settingsManager = SettingsManager.shared
    @State private var image: UIImage?
    
    private var formatColumnTitles: [String] {
        settingsManager.formatsToShow
    }
    
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
            
            // Format quantities (scrollable horizontally)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(formatColumnTitles, id: \.self) { title in
                        browseFormatColumn(title: title, formats: groupedFilm.formats, settings: settingsManager)
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(width: 160)
            
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
        .onChange(of: groupedFilm.imageName) { oldValue, newValue in
            loadImage()
        }
        .onChange(of: groupedFilm.name) { oldValue, newValue in
            loadImage()
        }
        .onChange(of: groupedFilm.manufacturer) { oldValue, newValue in
            loadImage()
        }
    }
    
    private func loadImage() {
        let imageSource = ImageSource(rawValue: groupedFilm.imageSource) ?? .autoDetected
        
        switch imageSource {
        case .custom:
            // Load user-taken photo
            if let customImageName = groupedFilm.imageName {
                // Handle manufacturer/filename format (for catalog-selected photos)
                let (manufacturer, filename) = parseCustomImageName(customImageName, defaultManufacturer: groupedFilm.manufacturer)
                if let userImage = ImageStorage.shared.loadImage(filename: filename, manufacturer: manufacturer) {
                    self.image = userImage
                    return
                }
            }
            
        case .catalog:
            // Load catalog image by exact filename
            if let catalogImageName = groupedFilm.imageName {
                if let catalogImage = ImageStorage.shared.loadCatalogImage(filename: catalogImageName) {
                    self.image = catalogImage
                    return
                }
            }
            
        case .autoDetected:
            // Auto-detect default image based on manufacturer + film name
            if let defaultImage = ImageStorage.shared.loadDefaultImage(filmName: groupedFilm.name, manufacturer: groupedFilm.manufacturer) {
                self.image = defaultImage
                return
            }
            
        case .none:
            // No image
            self.image = nil
            return
        }
    }
}

