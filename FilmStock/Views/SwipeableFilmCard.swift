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
    @State private var showingDeleteAlert = false
    
    var body: some View {
        FilmCardView(groupedFilm: groupedFilm)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                
                Button {
                    showingLoad = true
                } label: {
                    Label("Load", systemImage: "camera")
                }
                .tint(.blue)
                .disabled(!hasAvailableFormats)
            }
            .sheet(isPresented: $showingLoad) {
                LoadFilmView(groupedFilm: groupedFilm)
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
        
        for film in filmsToDelete {
            dataManager.deleteFilmStock(film)
        }
    }
}

