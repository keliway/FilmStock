//
//  FilmDetailView.swift
//  FilmStock
//
//  Film detail view (iOS HIG style)
//

import SwiftUI

struct FilmDetailView: View {
    let groupedFilm: GroupedFilm
    @EnvironmentObject var dataManager: FilmStockDataManager
    @State private var image: UIImage?
    @State private var relatedFilms: [FilmStock] = []
    
    var body: some View {
        List {
            // Image at top
            if let image = image {
                Section {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .listRowInsets(EdgeInsets())
                }
            }
            
            // Film info
            Section {
                InfoRow(label: "Manufacturer", value: groupedFilm.manufacturer)
                InfoRow(label: "Type", value: groupedFilm.type.displayName)
                InfoRow(label: "Speed", value: "ISO \(groupedFilm.filmSpeed)")
            }
            
            // Formats section
            Section("Formats") {
                ForEach(groupedFilm.formats) { format in
                    FormatDetailRow(format: format)
                }
            }
            
            // Other formats if exists
            if relatedFilms.count > 1 {
                Section("Other Formats") {
                    ForEach(relatedFilms.filter { $0.id != groupedFilm.formats.first?.filmId }) { film in
                        NavigationLink {
                            // TODO: Show detail for other format
                        } label: {
                            HStack {
                                Text(film.format.displayName)
                                Spacer()
                                Text("\(film.quantity) \(film.format.quantityUnit)")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            
            // Quantity control - for each format
            if !groupedFilm.formats.isEmpty {
                Section("Quantity") {
                    ForEach(groupedFilm.formats) { formatInfo in
                        if let film = relatedFilms.first(where: { $0.id == formatInfo.filmId }) {
                            HStack {
                                Text(formatInfo.format.displayName)
                                    .foregroundColor(.secondary)
                                Spacer()
                                QuantityControlView(film: film)
                            }
                        }
                    }
                }
            }
            
            // Comments
            if let comments = relatedFilms.first?.comments, !comments.isEmpty {
                Section("Comments") {
                    Text(comments)
                        .foregroundColor(.primary)
                }
            }
        }
        .navigationTitle(groupedFilm.name)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadImage()
            loadRelatedFilms()
        }
    }
    
    private func loadImage() {
        let imageName = groupedFilm.name.lowercased().replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression) + ".jpg"
        
        // Try Documents/images first (user uploaded)
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imagesDir = documentsURL.appendingPathComponent("images")
        let imageURL = imagesDir.appendingPathComponent(imageName)
        
        if let data = try? Data(contentsOf: imageURL),
           let uiImage = UIImage(data: data) {
            self.image = uiImage
        } else {
            // Try bundle (if images are included in app)
            if let bundleURL = Bundle.main.url(forResource: imageName.replacingOccurrences(of: ".jpg", with: ""), withExtension: "jpg", subdirectory: "images"),
               let data = try? Data(contentsOf: bundleURL),
               let uiImage = UIImage(data: data) {
                self.image = uiImage
            }
        }
    }
    
    private func loadRelatedFilms() {
        relatedFilms = dataManager.filmStocks.filter { film in
            film.name == groupedFilm.name &&
            film.manufacturer == groupedFilm.manufacturer &&
            film.type == groupedFilm.type &&
            film.filmSpeed == groupedFilm.filmSpeed
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

struct FormatDetailRow: View {
    let format: GroupedFilm.FormatInfo
    
    var body: some View {
        HStack {
            Text(format.format.displayName)
            Spacer()
            Text("\(format.quantity) \(format.format.quantityUnit)")
                .foregroundColor(.secondary)
            if !format.expireDate.isEmpty {
                Text(formatExpireDates(format.expireDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func formatExpireDates(_ dates: [String]) -> String {
        dates.map { FilmStock.formatExpireDate($0) }.joined(separator: ", ")
    }
}

struct QuantityControlView: View {
    let film: FilmStock
    @EnvironmentObject var dataManager: FilmStockDataManager
    @State private var quantity: Int
    
    init(film: FilmStock) {
        self.film = film
        _quantity = State(initialValue: film.quantity)
    }
    
    var body: some View {
        Stepper(
            value: $quantity,
            in: 0...999
        ) {
            Text("\(quantity) \(film.format.quantityUnit)")
        }
        .onChange(of: quantity) { newValue in
            var updated = film
            updated.quantity = newValue
            dataManager.updateFilmStock(updated)
        }
    }
}
