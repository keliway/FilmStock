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
    @State private var showFrozenOnly = false
    @State private var hideEmpty = SettingsManager.shared.hideEmptyByDefault
    @State private var viewMode: ViewMode = SettingsManager.shared.useTableViewByDefault ? .list : .cards
    @State private var showingAddFilm = false
    @State private var filmToEdit: GroupedFilm?
    @State private var filmToLoad: GroupedFilm?
    @State private var navigationPath = NavigationPath()
    @State private var showingFilters = false
    @State private var showingSettings = false
    @State private var showAddFilmTooltip = false
    @State private var showFilterTooltip = false
    @State private var tooltipPreferences: [TooltipPreference] = []
    @State private var showingDeleteError = false
    @State private var deleteErrorMessage = ""
    
    enum ViewMode {
        case cards, list
    }
    
    private struct SpeedRange {
        let name: String
        let min: Int
        let max: Int
    }
    
    private let speedRanges: [SpeedRange] = [
        SpeedRange(name: "<100", min: 0, max: 99),
        SpeedRange(name: "100", min: 100, max: 199),
        SpeedRange(name: "200", min: 200, max: 300),
        SpeedRange(name: "400", min: 301, max: 400),
        SpeedRange(name: "400+", min: 401, max: Int.max)
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
        
        // Apply show frozen only
        if showFrozenOnly {
            grouped = grouped.filter { group in
                group.formats.contains { $0.isFrozen }
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
                        Text("empty.noFilms.title")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("empty.noFilms.message")
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
                                Text(String(format: NSLocalizedString(filteredTotalRolls == 1 ? "film.rollCount" : "film.rollsCount", comment: ""), filteredTotalRolls))
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
            .navigationTitle("tab.myFilms")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: Text("search.placeholder"))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        showingFilters = true
                        if showFilterTooltip {
                            OnboardingManager.shared.markTooltipSeen("filter")
                            showFilterTooltip = false
                        }
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
                    .onboardingTooltip(
                        id: "filter",
                        title: "Filter Your Collection",
                        message: "Use filters to find films by manufacturer, type, speed, or format. Perfect for quickly locating what you need.",
                        anchor: .trailing,
                        isVisible: showFilterTooltip
                    ) {
                        showFilterTooltip = false
                    }
                    Button {
                        showingAddFilm = true
                        if showAddFilmTooltip {
                            OnboardingManager.shared.markTooltipSeen("addFilm")
                            showAddFilmTooltip = false
                            // Show next tooltip
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                if !OnboardingManager.shared.hasSeenTooltip("filter") {
                                    showFilterTooltip = true
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .onboardingTooltip(
                        id: "addFilm",
                        title: "Add Your First Film",
                        message: "Tap the + button to add films to your collection. You can track quantities, expiration dates, and even take photos of your film reminder cards.",
                        anchor: .trailing,
                        isVisible: showAddFilmTooltip
                    ) {
                        showAddFilmTooltip = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            if !OnboardingManager.shared.hasSeenTooltip("filter") {
                                showFilterTooltip = true
                            }
                        }
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
                    showFrozenOnly: $showFrozenOnly,
                    hideEmpty: $hideEmpty,
                    dataManager: dataManager
                )
            }
        .sheet(isPresented: $showingSettings) {
            SettingsView(hideEmpty: $hideEmpty, viewMode: $viewMode)
        }
        .alert("error.cannotDelete.title", isPresented: $showingDeleteError) {
            Button("action.ok", role: .cancel) { }
        } message: {
            Text(deleteErrorMessage)
        }
            .onAppear {
                if OnboardingManager.shared.hasCompletedOnboarding {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if !OnboardingManager.shared.hasSeenTooltip("addFilm") {
                            showAddFilmTooltip = true
                        }
                    }
                }
            }
            .onPreferenceChange(TooltipPreferenceKey.self) { preferences in
                tooltipPreferences = preferences
            }
            .overlay {
                // Global tooltip overlay
                if let activeTooltip = tooltipPreferences.first(where: { $0.isVisible }) {
                    GeometryReader { geometry in
                        ZStack {
                            // Background overlay
                            Color.black.opacity(0.3)
                                .ignoresSafeArea()
                                .onTapGesture {
                                    OnboardingManager.shared.markTooltipSeen(activeTooltip.id)
                                    if activeTooltip.id == "addFilm" {
                                        showAddFilmTooltip = false
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            if !OnboardingManager.shared.hasSeenTooltip("filter") {
                                                showFilterTooltip = true
                                            }
                                        }
                                    } else if activeTooltip.id == "filter" {
                                        showFilterTooltip = false
                                    }
                                }
                            
                            // Tooltip positioned relative to button with bounds checking
                            tooltipView(for: activeTooltip)
                                .position(
                                    x: tooltipPositionX(for: activeTooltip, in: geometry),
                                    y: tooltipPositionY(for: activeTooltip, in: geometry)
                                )
                        }
                    }
                }
            }
        }
    }
    
    private func tooltipPositionX(for tooltip: TooltipPreference, in geometry: GeometryProxy) -> CGFloat {
        let buttonFrame = tooltip.frame
        let tooltipWidth: CGFloat = 280
        let padding: CGFloat = 20
        let screenWidth = geometry.size.width
        
        let preferredX: CGFloat
        switch tooltip.anchor {
        case .leading:
            preferredX = buttonFrame.minX - tooltipWidth / 2 - padding
        case .trailing:
            preferredX = buttonFrame.maxX + tooltipWidth / 2 + padding
        case .top, .bottom:
            preferredX = buttonFrame.midX
        }
        
        // Clamp to screen bounds
        let minX = tooltipWidth / 2 + padding
        let maxX = screenWidth - tooltipWidth / 2 - padding
        return max(minX, min(maxX, preferredX))
    }
    
    private func tooltipPositionY(for tooltip: TooltipPreference, in geometry: GeometryProxy) -> CGFloat {
        let buttonFrame = tooltip.frame
        let tooltipHeight: CGFloat = 200 // Approximate height
        let padding: CGFloat = 20
        let screenHeight = geometry.size.height
        
        let preferredY: CGFloat
        switch tooltip.anchor {
        case .top:
            preferredY = buttonFrame.minY - tooltipHeight / 2 - padding
        case .bottom:
            preferredY = buttonFrame.maxY + tooltipHeight / 2 + padding
        case .leading, .trailing:
            preferredY = buttonFrame.midY
        }
        
        // Clamp to screen bounds
        let minY = tooltipHeight / 2 + padding
        let maxY = screenHeight - tooltipHeight / 2 - padding
        return max(minY, min(maxY, preferredY))
    }
    
    @ViewBuilder
    private func tooltipView(for tooltip: TooltipPreference) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(tooltip.title)
                    .font(.headline)
                
                // Show icon for filter tooltip
                if tooltip.id == "filter" {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.headline)
                        .foregroundColor(.accentColor)
                }
                
                // Show icon for add film tooltip
                if tooltip.id == "addFilm" {
                    Image(systemName: "plus")
                        .font(.headline)
                        .foregroundColor(.accentColor)
                }
            }
            
            Text(tooltip.message)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Spacer()
                Button {
                    OnboardingManager.shared.markTooltipSeen(tooltip.id)
                    if tooltip.id == "addFilm" {
                        showAddFilmTooltip = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            if !OnboardingManager.shared.hasSeenTooltip("filter") {
                                showFilterTooltip = true
                            }
                        }
                    } else if tooltip.id == "filter" {
                        showFilterTooltip = false
                    }
                } label: {
                    Text("Got it")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.accentColor)
                        .cornerRadius(8)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
        )
        .frame(maxWidth: 280)
        .transition(.scale.combined(with: .opacity))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: tooltip.isVisible)
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func listView(for group: GroupedFilm) -> some View {
        Button {
            navigationPath.append(group)
        } label: {
            FilmRowViewContent(groupedFilm: group)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                deleteFilm(group)
            } label: {
                Label("action.delete", systemImage: "trash")
            }
            
            Button {
                loadFilm(group)
            } label: {
                Label("action.load", systemImage: "camera")
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
        
        // Check if any of the films are currently loaded
        if let loadedFilm = filmsToDelete.first(where: { dataManager.isFilmLoaded($0) }) {
            deleteErrorMessage = String(format: NSLocalizedString("error.cannotDeleteLoaded", comment: ""), loadedFilm.name)
            showingDeleteError = true
            return
        }
        
        dataManager.deleteFilmStocks(filmsToDelete)
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

