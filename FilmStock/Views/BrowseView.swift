//
//  BrowseView.swift
//  FilmStock
//
//  Browse/Filter view following iOS HIG
//

import SwiftUI

struct BrowseView: View {
    @EnvironmentObject var dataManager: FilmStockDataManager
    @State private var searchText = ""
    @State private var selectedManufacturers: Set<String> = []
    @State private var selectedTypes: Set<FilmStock.FilmType> = []
    @State private var selectedSpeedRanges: Set<String> = []
    @State private var selectedFormats: Set<FilmStock.FilmFormat> = []
    @State private var showExpiredOnly = false
    @State private var hideEmpty = true
    @State private var viewMode: ViewMode = .cards
    @State private var showingAddFilm = false
    @State private var filmToEdit: GroupedFilm?
    @State private var filmToLoad: GroupedFilm?
    @State private var navigationPath = NavigationPath()
    @State private var showingFilters = false
    
    enum ViewMode {
        case cards, list
    }
    
    private struct SpeedRange {
        let name: String
        let min: Int
        let max: Int
    }
    
    private let speedRanges: [SpeedRange] = [
        SpeedRange(name: "Super slow", min: 0, max: 99),
        SpeedRange(name: "Slow", min: 100, max: 199),
        SpeedRange(name: "Normal", min: 200, max: 300),
        SpeedRange(name: "Fast", min: 301, max: 400),
        SpeedRange(name: "Super fast", min: 401, max: Int.max)
    ]
    
    var filteredFilms: [GroupedFilm] {
        var grouped = dataManager.groupedFilms()
        
        // Apply filters
        if !selectedManufacturers.isEmpty {
            grouped = grouped.filter { selectedManufacturers.contains($0.manufacturer) }
        }
        
        if !selectedTypes.isEmpty {
            grouped = grouped.filter { selectedTypes.contains($0.type) }
        }
        
        if !selectedSpeedRanges.isEmpty {
            grouped = grouped.filter { group in
                selectedSpeedRanges.contains { rangeKey in
                    if let range = speedRanges.first(where: { $0.name == rangeKey }) {
                        return group.filmSpeed >= range.min && group.filmSpeed <= range.max
                    }
                    return false
                }
            }
        }
        
        if !selectedFormats.isEmpty {
            grouped = grouped.filter { group in
                group.formats.contains { selectedFormats.contains($0.format) }
            }
        }
        
        // Apply search
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            grouped = grouped.filter {
                $0.name.lowercased().contains(query) ||
                $0.manufacturer.lowercased().contains(query) ||
                $0.type.displayName.lowercased().contains(query)
            }
        }
        
        // Apply hide empty
        if hideEmpty {
            grouped = grouped.filter { group in
                group.formats.contains { $0.quantity > 0 }
            }
        }
        
        return grouped
    }
    
    var totalRolls: Int {
        dataManager.filmStocks
            .filter { film in
                let format = film.format
                return format != .fourByFive && format != .fiveBySeven && format != .eightByTen && film.quantity > 0
            }
            .reduce(0) { $0 + $1.quantity }
    }
    
    var filteredTotalRolls: Int {
        let allFormats = filteredFilms.flatMap { $0.formats }
        let validFormats = allFormats.filter { formatInfo in
            let format = formatInfo.format
            return format != .fourByFive && format != .fiveBySeven && format != .eightByTen && formatInfo.quantity > 0
        }
        return validFormats.reduce(0) { total, formatInfo in
            total + formatInfo.quantity
        }
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if filteredFilms.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "film")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No Films Found")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Try adjusting your filters")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    List {
                        // Results count and view toggle header
                        Section {
                            EmptyView()
                        } header: {
                            HStack {
                                Text("\(filteredTotalRolls) rolls")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Picker("View", selection: $viewMode) {
                                    Image(systemName: "tablecells").tag(ViewMode.cards)
                                    Image(systemName: "list.bullet").tag(ViewMode.list)
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 120)
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 8)
                            .textCase(nil)
                        }
                        
                        ForEach(filteredFilms) { group in
                            if viewMode == .cards {
                                cardView(for: group)
                            } else {
                                listView(for: group)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .environment(\.defaultMinListHeaderHeight, 0)
                    .environment(\.defaultMinListRowHeight, 0)
                }
            }
            .navigationTitle("My Films")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search films")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        showingFilters = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                            if activeFilterCount > 0 {
                                Text("\(activeFilterCount)")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor)
                                    .foregroundColor(.white)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    Button {
                        showingAddFilm = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(for: GroupedFilm.self) { film in
                FilmDetailView(groupedFilm: film)
            }
            .sheet(isPresented: $showingAddFilm) {
                AddFilmView()
            }
            .sheet(item: $filmToEdit) { film in
                EditFilmView(groupedFilm: film)
            }
            .sheet(item: $filmToLoad) { film in
                LoadFilmView(groupedFilm: film)
                    .environmentObject(dataManager)
            }
            .sheet(isPresented: $showingFilters) {
                FilterPopoverView(
                    selectedManufacturers: $selectedManufacturers,
                    selectedTypes: $selectedTypes,
                    selectedSpeedRanges: $selectedSpeedRanges,
                    selectedFormats: $selectedFormats,
                    showExpiredOnly: $showExpiredOnly,
                    hideEmpty: $hideEmpty,
                    dataManager: dataManager
                )
            }
        }
    }
    
    private var activeFilterCount: Int {
        var count = 0
        if !selectedManufacturers.isEmpty { count += selectedManufacturers.count }
        if !selectedTypes.isEmpty { count += selectedTypes.count }
        if !selectedSpeedRanges.isEmpty { count += selectedSpeedRanges.count }
        if !selectedFormats.isEmpty { count += selectedFormats.count }
        if showExpiredOnly { count += 1 }
        if !hideEmpty { count += 1 }
        return count
    }
    
    @ViewBuilder
    private func cardView(for group: GroupedFilm) -> some View {
        Button {
            navigationPath.append(group)
        } label: {
            SwipeableFilmCard(groupedFilm: group)
                .environmentObject(dataManager)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func listView(for group: GroupedFilm) -> some View {
        Button {
            navigationPath.append(group)
        } label: {
            FilmRowViewContent(groupedFilm: group)
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                deleteFilm(group)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            
            Button {
                loadFilm(group)
            } label: {
                Label("Load", systemImage: "camera")
            }
            .tint(.blue)
            .disabled(!hasAvailableFormats(group))
        }
    }
    
    private func deleteFilm(_ group: GroupedFilm) {
        let filmsToDelete = dataManager.filmStocks.filter { film in
            film.name == group.name &&
            film.manufacturer == group.manufacturer &&
            film.type == group.type &&
            film.filmSpeed == group.filmSpeed
        }
        
        for film in filmsToDelete {
            dataManager.deleteFilmStock(film)
        }
    }
    
    private func editFilm(_ group: GroupedFilm) {
        filmToEdit = group
    }
    
    private func loadFilm(_ group: GroupedFilm) {
        filmToLoad = group
    }
    
    private func hasAvailableFormats(_ group: GroupedFilm) -> Bool {
        group.formats.contains { $0.quantity > 0 }
    }
}

