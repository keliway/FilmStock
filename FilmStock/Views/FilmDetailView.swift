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
    @Environment(\.dismiss) var dismiss
    @State private var relatedFilms: [FilmStock] = []
    @State private var showingEditSheet = false
    @State private var showingLoadSheet = false
    @State private var shouldDismissAfterLoad = false
    
    // Computed property to get the current groupedFilm from dataManager
    private var currentGroupedFilm: GroupedFilm? {
        dataManager.groupedFilms().first { $0.id == groupedFilm.id }
    }
    
    // Use current groupedFilm if available, otherwise fall back to initial
    private var displayGroupedFilm: GroupedFilm {
        currentGroupedFilm ?? groupedFilm
    }
    
    var body: some View {
        List {
            // Film info
            Section {
                InfoRow(label: "film.manufacturer", value: displayGroupedFilm.manufacturer)
                InfoRow(label: "film.type", value: displayGroupedFilm.type.displayName)
                InfoRow(label: "film.speed", value: "ISO \(displayGroupedFilm.filmSpeed)")
            }
            
            // Formats section
            Section("detail.formats") {
                ForEach(displayGroupedFilm.formats) { format in
                    if let film = relatedFilms.first(where: { $0.id == format.filmId }) {
                        FormatDetailRow(format: format, currentQuantity: film.quantity)
                    } else {
                        FormatDetailRow(format: format, currentQuantity: format.quantity)
                    }
                }
            }
            
            // Other formats if exists
            if relatedFilms.count > 1 {
                Section("detail.otherFormats") {
                    ForEach(relatedFilms.filter { $0.id != displayGroupedFilm.formats.first?.filmId }) { film in
                            HStack {
                                Text(film.formatDisplayName)
                                Spacer()
                                Text("\(film.quantity) \(film.format.quantityUnit)")
                                    .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Quantity control - for each format
            if !displayGroupedFilm.formats.isEmpty {
                Section("film.quantity") {
                    ForEach(displayGroupedFilm.formats) { formatInfo in
                        if let film = relatedFilms.first(where: { $0.id == formatInfo.filmId }) {
                            HStack {
                                Text(formatInfo.formatDisplayName)
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
                Section("film.comments") {
                    Text(comments)
                        .foregroundColor(.primary)
                }
            }
        }
        .navigationTitle("\(displayGroupedFilm.manufacturer) \(displayGroupedFilm.name)")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("action.edit") {
                    showingEditSheet = true
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if hasAvailableFormats {
                Button {
                    showingLoadSheet = true
                } label: {
                    Text("load.title")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .onAppear {
            loadRelatedFilms()
        }
        .onChange(of: dataManager.filmStocks) { oldValue, newValue in
            loadRelatedFilms()
        }
        .sheet(isPresented: $showingEditSheet) {
            EditFilmView(groupedFilm: displayGroupedFilm)
                .environmentObject(dataManager)
        }
        .onChange(of: showingEditSheet) { oldValue, newValue in
            // When edit sheet dismisses, refresh the data
            if !newValue {
                loadRelatedFilms()
            }
        }
        .sheet(isPresented: $showingLoadSheet) {
            LoadFilmView(groupedFilm: displayGroupedFilm, onLoadComplete: {
                shouldDismissAfterLoad = true
            })
            .environmentObject(dataManager)
        }
        .onChange(of: shouldDismissAfterLoad) { oldValue, newValue in
            if newValue {
                // Dismiss the detail view to go back to My Films list
                dismiss()
            }
        }
    }
    
    private var hasAvailableFormats: Bool {
        displayGroupedFilm.formats.contains { $0.quantity > 0 }
    }
    
    private func loadRelatedFilms() {
        relatedFilms = dataManager.filmStocks.filter { film in
            film.name == displayGroupedFilm.name &&
            film.manufacturer == displayGroupedFilm.manufacturer &&
            film.type == displayGroupedFilm.type &&
            film.filmSpeed == displayGroupedFilm.filmSpeed
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(LocalizedStringKey(label))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

struct FormatDetailRow: View {
    let format: GroupedFilm.FormatInfo
    let currentQuantity: Int
    
    var body: some View {
        HStack {
            Text(format.formatDisplayName)
            Spacer()
            Text(quantityText)
                .foregroundColor(.secondary)
            if let expireDate = format.expireDate, !expireDate.isEmpty {
                Text(formatExpireDates(expireDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var quantityText: String {
        let unit = format.format.quantityUnit
        if unit == "roll(s)" {
            return currentQuantity == 1 
                ? String(format: NSLocalizedString("film.rollCount", comment: ""), currentQuantity)
                : String(format: NSLocalizedString("film.rollsCount", comment: ""), currentQuantity)
        } else if unit == "sheet(s)" {
            return String(format: NSLocalizedString("Sheets: %d", comment: ""), currentQuantity)
        }
        return "\(currentQuantity) \(unit)"
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
            Text(quantityText)
        }
        .onChange(of: quantity) { oldValue, newValue in
            var updated = film
            updated.quantity = newValue
            dataManager.updateFilmStock(updated)
        }
    }
    
    private var quantityText: String {
        let unit = film.format.quantityUnit
        if unit == "roll(s)" {
            return quantity == 1 
                ? String(format: NSLocalizedString("film.rollCount", comment: ""), quantity)
                : String(format: NSLocalizedString("film.rollsCount", comment: ""), quantity)
        } else if unit == "sheet(s)" {
            return String(format: NSLocalizedString("Sheets: %d", comment: ""), quantity)
        }
        return "\(quantity) \(unit)"
    }
}

