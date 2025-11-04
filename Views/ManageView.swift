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
            HStack(spacing: 16) {
                formatQty(groupedFilm.formats, format: .thirtyFive)
                formatQty(groupedFilm.formats, format: .oneTwenty)
                formatQty(groupedFilm.formats, format: .fourByFive)
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            
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
            // TODO: Edit view
            Text("Edit View - To be implemented")
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
            .filter { formatQty($0.format) == format }
            .reduce(0) { $0 + $1.quantity }
        
        Text(qty > 0 ? "\(qty)" : "-")
            .frame(width: 30)
            .multilineTextAlignment(.center)
    }
    
    private func formatQty(_ format: FilmStock.FilmFormat) -> FilmStock.FilmFormat {
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
        let imageName = groupedFilm.name.lowercased().replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression) + ".jpg"
        if let imageURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("images")
            .appendingPathComponent(imageName),
           let data = try? Data(contentsOf: imageURL),
           let uiImage = UIImage(data: data) {
            self.image = uiImage
        }
    }
}

