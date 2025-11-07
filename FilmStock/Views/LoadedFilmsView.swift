//
//  LoadedFilmsView.swift
//  FilmStock
//
//  View showing all currently loaded films
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

struct LoadedFilmsView: View {
    @EnvironmentObject var dataManager: FilmStockDataManager
    @State private var loadedFilms: [LoadedFilm] = []
    @State private var showingHelp = false
    
    var body: some View {
        NavigationStack {
            List {
                if loadedFilms.isEmpty {
                    ContentUnavailableView(
                        "empty.noLoadedFilms.title",
                        systemImage: "camera",
                        description: Text("empty.noLoadedFilms.message")
                    )
                } else {
                    ForEach(loadedFilms, id: \.id) { loadedFilm in
                        LoadedFilmRow(loadedFilm: loadedFilm)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                // Primary action: Unload one sheet (for sheet films only) - detail swipe action
                                if isSheetFormat(loadedFilm.format) && loadedFilm.quantity > 1 {
                                    Button {
                                        unloadOneSheet(loadedFilm)
                                    } label: {
                                        Label("action.unloadOne", systemImage: "minus.circle")
                                    }
                                    .tint(.orange)
                                }
                                
                                // Secondary action: Unload all
                                Button {
                                    unloadFilm(loadedFilm)
                                } label: {
                                    Label("action.unloadAll", systemImage: "arrow.uturn.backward")
                                }
                                .tint(.green)
                            }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("tab.loadedFilms")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingHelp = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                }
            }
            .alert("help.loadedFilms.title", isPresented: $showingHelp) {
                Button("action.done", role: .cancel) { }
            } message: {
                Text("help.loadedFilms.message")
            }
            .onAppear {
                loadFilms()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("LoadedFilmsChanged"))) { _ in
                loadFilms()
            }
        }
    }
    
    private func loadFilms() {
        loadedFilms = dataManager.getLoadedFilms()
    }
    
    private func unloadFilm(_ loadedFilm: LoadedFilm) {
        dataManager.unloadFilm(loadedFilm)
        loadFilms()
    }
    
    private func unloadOneSheet(_ loadedFilm: LoadedFilm) {
        dataManager.unloadFilm(loadedFilm, quantity: 1)
        loadFilms()
    }
    
    private func isSheetFormat(_ format: String) -> Bool {
        guard let filmFormat = FilmStock.FilmFormat(rawValue: format) else {
            return false
        }
        return filmFormat == .fourByFive || filmFormat == .fiveBySeven || filmFormat == .eightByTen
    }
}

struct LoadedFilmRow: View {
    let loadedFilm: LoadedFilm
    @State private var filmImage: UIImage?
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 12) {
                // Film image
                if let image = filmImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "camera")
                                .foregroundColor(.gray)
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    if let film = loadedFilm.film {
                        Text("\(film.manufacturer?.name ?? "") \(film.name)")
                            .font(.headline)
                        
                        HStack(spacing: 4) {
                            Text("ISO \(film.filmSpeed)")
                            Text("•")
                            Text(formatDisplayName)
                            if isSheetFormat(loadedFilm.format) {
                                Text("•")
                                Text(loadedFilm.quantity == 1 
                                     ? String(format: NSLocalizedString("format.sheet.count", comment: ""), loadedFilm.quantity)
                                     : String(format: NSLocalizedString("format.sheets.count", comment: ""), loadedFilm.quantity))
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                    
                    if let camera = loadedFilm.camera {
                        HStack(spacing: 4) {
                            Image(systemName: "camera.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(camera.name)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text(String(format: NSLocalizedString("time.loadedAt", comment: ""), formatDate(loadedFilm.loadedAt)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
            
            // Red "EXPIRED" chip in top right
            if isExpired {
                Text("EXPIRED")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.red, lineWidth: 1)
                    )
                    .padding(.top, 4)
                    .padding(.trailing, 4)
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private var formatDisplayName: String {
        guard let format = FilmStock.FilmFormat(rawValue: loadedFilm.format) else {
            return loadedFilm.format
        }
        return format.displayName
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func loadImage() {
        guard let film = loadedFilm.film else { return }
        
        let imageSource = ImageSource(rawValue: film.imageSource) ?? .autoDetected
        let manufacturerName = film.manufacturer?.name ?? ""
        
        switch imageSource {
        case .custom:
            // Load user-taken photo
            if let customImageName = film.imageName {
                // Handle manufacturer/filename format (for catalog-selected photos)
                let (manufacturer, filename) = parseCustomImageName(customImageName, defaultManufacturer: manufacturerName)
                if let userImage = ImageStorage.shared.loadImage(filename: filename, manufacturer: manufacturer) {
                    filmImage = userImage
                    return
                }
            }
            
        case .catalog:
            // Load catalog image by exact filename
            if let catalogImageName = film.imageName {
                if let catalogImage = ImageStorage.shared.loadCatalogImage(filename: catalogImageName) {
                    filmImage = catalogImage
                    return
                }
            }
            
        case .autoDetected:
            // Auto-detect default image based on manufacturer + film name
            if let defaultImage = ImageStorage.shared.loadDefaultImage(filmName: film.name, manufacturer: manufacturerName) {
                filmImage = defaultImage
                return
            }
            
        case .none:
            // No image
            filmImage = nil
            return
        }
    }
    
    private func isSheetFormat(_ format: String) -> Bool {
        guard let filmFormat = FilmStock.FilmFormat(rawValue: format) else {
            return false
        }
        return filmFormat == .fourByFive || filmFormat == .fiveBySeven || filmFormat == .eightByTen
    }
    
    private var isExpired: Bool {
        guard let expireDates = loadedFilm.myFilm?.expireDateArray, !expireDates.isEmpty else {
            return false
        }
        
        let today = Date()
        let calendar = Calendar.current
        
        // Check if any expire date has passed
        for dateString in expireDates {
            if let expireDate = FilmStock.parseExpireDate(dateString) {
                var compareDate = expireDate
                
                // For YYYY format, compare to end of year (Dec 31)
                if dateString.count == 4 {
                    let year = calendar.component(.year, from: expireDate)
                    if let endOfYear = calendar.date(from: DateComponents(year: year, month: 12, day: 31)) {
                        compareDate = endOfYear
                    }
                } else if dateString.split(separator: "/").count == 2 {
                    // For MM/YYYY format, compare to end of month
                    let components = calendar.dateComponents([.year, .month], from: expireDate)
                    if let year = components.year,
                       let month = components.month,
                       let daysInMonth = calendar.range(of: .day, in: .month, for: expireDate)?.count,
                       let endOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: daysInMonth)) {
                        compareDate = endOfMonth
                    }
                }
                // For MM/DD/YYYY format, compare directly (already set)
                
                // Compare dates (ignore time)
                if let todayStart = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: today),
                   let compareStart = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: compareDate) {
                    if todayStart > compareStart {
                        return true
                    }
                }
            }
        }
        
        return false
    }
}

