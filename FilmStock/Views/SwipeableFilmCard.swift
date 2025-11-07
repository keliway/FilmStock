//
//  SwipeableFilmCard.swift
//  FilmStock
//
//  Swipeable card view with actions
//

import SwiftUI

struct SwipeableFilmCard: View {
    let groupedFilm: GroupedFilm
    @EnvironmentObject var dataManager: FilmStockDataManager
    @State private var showingLoad = false
    @State private var showingDeleteError = false
    @State private var deleteErrorMessage = ""
    
    var body: some View {
        FilmCardView(groupedFilm: groupedFilm)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    deleteFilm()
                } label: {
                    Label("action.delete", systemImage: "trash")
                }
                
                Button {
                    showingLoad = true
                } label: {
                    Label("action.load", systemImage: "camera")
                }
                .tint(.blue)
                .disabled(!hasAvailableFormats)
            }
            .sheet(isPresented: $showingLoad) {
                LoadFilmView(groupedFilm: groupedFilm)
                    .environmentObject(dataManager)
            }
            .alert("error.cannotDelete.title", isPresented: $showingDeleteError) {
                Button("action.ok", role: .cancel) { }
            } message: {
                Text(deleteErrorMessage)
            }
    }
    
    private var hasAvailableFormats: Bool {
        groupedFilm.formats.contains { $0.quantity > 0 }
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
        
        dataManager.deleteFilmStocks(filmsToDelete)
    }
}

