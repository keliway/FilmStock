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
    
    enum ViewMode {
        case cards, list
    }
    
    private let speedRanges = [
        ("<100", 0..<100),
        ("100", 100..<200),
        ("200", 200...300),
        ("400", 301...400),
        (">400", 401..<Int.max)
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
                    if let range = speedRanges.first(where: { $0.0 == rangeKey })?.1 {
                        return range.contains(group.filmSpeed)
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
        
        // TODO: Apply expired filter if needed
        
        return grouped
    }
    
    var totalRolls: Int {
        dataManager.filmStocks
            .filter { $0.format != .fourByFive && $0.quantity > 0 }
            .reduce(0) { $0 + $1.quantity }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter Section (iOS-style)
                FilterSectionView(
                    selectedManufacturers: $selectedManufacturers,
                    selectedTypes: $selectedTypes,
                    selectedSpeedRanges: $selectedSpeedRanges,
                    selectedFormats: $selectedFormats,
                    showExpiredOnly: $showExpiredOnly,
                    hideEmpty: $hideEmpty,
                    dataManager: dataManager
                )
                
                // Results count and view toggle
                HStack {
                    Text("\(totalRolls) results")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Picker("View", selection: $viewMode) {
                        Image(systemName: "square.grid.2x2").tag(ViewMode.cards)
                        Image(systemName: "list.bullet").tag(ViewMode.list)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                Divider()
                
                // Content
                if filteredFilms.isEmpty {
                    ContentUnavailableView(
                        "No Films Found",
                        systemImage: "film",
                        description: Text("Try adjusting your filters")
                    )
                } else {
                    ScrollView {
                        if viewMode == .cards {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))], spacing: 16) {
                                ForEach(filteredFilms) { group in
                                    FilmCardView(groupedFilm: group)
                                }
                            }
                            .padding()
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(filteredFilms) { group in
                                    FilmRowView(groupedFilm: group)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Film Stocks")
            .searchable(text: $searchText, prompt: "Search films")
            .navigationDestination(for: GroupedFilm.self) { film in
                FilmDetailView(groupedFilm: film)
            }
        }
    }
}

