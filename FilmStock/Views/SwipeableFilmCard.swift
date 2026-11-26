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

    private var hasAvailableFormats: Bool {
        groupedFilm.formats.contains { $0.quantity > 0 }
    }

    private var isFilmLoaded: Bool {
        dataManager.isGroupedFilmLoaded(groupedFilm)
    }

    var body: some View {
        FilmCardView(groupedFilm: groupedFilm)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if isFilmLoaded {
                    Button {
                        deleteErrorMessage = String(
                            format: NSLocalizedString("error.cannotDeleteLoaded", comment: ""),
                            groupedFilm.name
                        )
                        showingDeleteError = true
                    } label: {
                        Label("action.delete", systemImage: "trash")
                    }
                    .tint(.gray)
                } else {
                    Button(role: .destructive) {
                        if let error = dataManager.deleteGroupedFilm(groupedFilm) {
                            deleteErrorMessage = error
                            showingDeleteError = true
                        }
                    } label: {
                        Label("action.delete", systemImage: "trash")
                    }
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
}
