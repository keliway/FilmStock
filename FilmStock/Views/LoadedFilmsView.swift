//
//  LoadedFilmsView.swift
//  FilmStock
//
//  View showing all currently loaded films
//

import SwiftUI

struct LoadedFilmsView: View {
    @EnvironmentObject var dataManager: FilmStockDataManager
    @State private var loadedFilms: [LoadedFilm] = []
    
    var body: some View {
        NavigationStack {
            List {
                if loadedFilms.isEmpty {
                    ContentUnavailableView(
                        "No Films Loaded",
                        systemImage: "camera",
                        description: Text("Load a film from the My Films tab to see it here")
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
                                        Label("Unload 1 Sheet", systemImage: "minus.circle")
                                    }
                                    .tint(.orange)
                                }
                                
                                // Secondary action: Unload all
                                Button {
                                    unloadFilm(loadedFilm)
                                } label: {
                                    Label("Unload All", systemImage: "arrow.uturn.backward")
                                }
                                .tint(.green)
                            }
                    }
                }
            }
            .navigationTitle("Loaded Films")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadFilms()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("LoadedFilmsChanged"))) { _ in
                loadFilms()
            }
            .refreshable {
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
                            Text("\(loadedFilm.quantity) \(loadedFilm.quantity == 1 ? "sheet" : "sheets")")
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
                
                Text("Loaded \(formatDate(loadedFilm.loadedAt))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
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
        
        // Try to load custom image first
        if let imageName = film.imageName {
            if let image = ImageStorage.shared.loadImage(filename: imageName, manufacturer: film.manufacturer?.name ?? "") {
                filmImage = image
                return
            }
        }
        
        // Try to load default image
        if let defaultImage = ImageStorage.shared.loadDefaultImage(
            filmName: film.name,
            manufacturer: film.manufacturer?.name ?? ""
        ) {
            filmImage = defaultImage
        }
    }
    
    private func isSheetFormat(_ format: String) -> Bool {
        guard let filmFormat = FilmStock.FilmFormat(rawValue: format) else {
            return false
        }
        return filmFormat == .fourByFive || filmFormat == .fiveBySeven || filmFormat == .eightByTen
    }
}

