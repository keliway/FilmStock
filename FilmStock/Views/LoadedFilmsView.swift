//
//  LoadedFilmsView.swift
//  FilmStock
//
//  View showing all currently loaded films
//

import SwiftUI
import SwiftData

private enum LoadedFilmsFormatters {
    static let exactDateTime: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .short
        return f
    }()

    static let relativeDate: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()
}

struct LoadedFilmsView: View {
    @EnvironmentObject var dataManager: FilmStockDataManager
    @Binding var selectedFilmId: String?
    @State private var loadedFilms: [LoadedFilm] = []
    @State private var finishedFilms: [FinishedFilm] = []
    @State private var selectedTab = 0
    @State private var showingHelp = false
    @State private var showingManageCameras = false
    @State private var showingDatePicker = false
    @State private var filmToEditDate: LoadedFilm?
    @State private var selectedDate = Date()
    @State private var selectedLoadedFilm: LoadedFilm?
    @State private var selectedFinishedFilm: FinishedFilm?
    
    init(selectedFilmId: Binding<String?> = .constant(nil)) {
        self._selectedFilmId = selectedFilmId
    }
    
    // Filters and sorting for finished films
    @State private var showingFilters = false
    @State private var searchText = ""
    @State private var selectedTypes: Set<FilmStock.FilmType> = []
    @State private var selectedStatuses: Set<FinishedFilmStatus> = []
    @State private var selectedFormats: Set<FilmStock.FilmFormat> = []
    @State private var selectedCameras: Set<String> = []
    @State private var sortField: FinishedFilmSortField = .finishedDate
    @State private var sortAscending: Bool = false
    @State private var pendingFilmsRefresh = false
    
    /// Snapshot filter options when the sheet opens so section counts stay stable while the sheet is visible.
    @State private var filterSheetTypes: [FilmStock.FilmType] = []
    @State private var filterSheetFormats: [FilmStock.FilmFormat] = []
    @State private var filterSheetCameras: [String] = []
    
    private var isSheetBlockingRefresh: Bool {
        showingManageCameras || showingFilters || showingDatePicker || showingHelp
            || selectedLoadedFilm != nil || selectedFinishedFilm != nil
    }
    
    enum FinishedFilmSortField: String, CaseIterable {
        case manufacturer = "manufacturer"
        case filmName = "filmName"
        case finishedDate = "finishedDate"
        case iso = "iso"
        
        var displayName: String {
            switch self {
            case .manufacturer: return NSLocalizedString("sort.manufacturer", comment: "")
            case .filmName: return NSLocalizedString("sort.filmName", comment: "")
            case .finishedDate: return NSLocalizedString("sort.finishedDate", comment: "")
            case .iso: return NSLocalizedString("sort.iso", comment: "")
            }
        }
    }
    
    var filteredAndSortedFinishedFilms: [FinishedFilm] {
        var filtered = finishedFilms
        
        // Search filter (manufacturer + film name)
        if !searchText.isEmpty {
            filtered = filtered.filter { film in
                let resolvedFilm = film.film ?? film.myFilm?.film
                let manufacturer = resolvedFilm?.manufacturer?.name ?? ""
                let filmName = resolvedFilm?.name ?? ""
                let searchLower = searchText.lowercased()
                return manufacturer.lowercased().contains(searchLower) || filmName.lowercased().contains(searchLower)
            }
        }
        
        // Film type filter
        if !selectedTypes.isEmpty {
            filtered = filtered.filter { film in
                guard let filmType = (film.film ?? film.myFilm?.film)?.type,
                      let type = FilmStock.FilmType(rawValue: filmType) else { return false }
                return selectedTypes.contains(type)
            }
        }
        
        // Status filter
        if !selectedStatuses.isEmpty {
            filtered = filtered.filter { film in
                let status = FinishedFilmStatus(rawValue: film.status ?? "") ?? .toDevelop
                return selectedStatuses.contains(status)
            }
        }
        
        // Format filter
        if !selectedFormats.isEmpty {
            filtered = filtered.filter { film in
                guard let format = FilmStock.FilmFormat(rawValue: film.format) else { return false }
                return selectedFormats.contains(format)
            }
        }
        
        // Camera filter
        if !selectedCameras.isEmpty {
            filtered = filtered.filter { film in
                guard let cameraName = film.cameraName else { return false }
                return selectedCameras.contains(cameraName)
            }
        }
        
        // Sorting
        return filtered.sorted { film1, film2 in
            let ascending = sortAscending
            switch sortField {
            case .manufacturer:
                let m1 = (film1.film ?? film1.myFilm?.film)?.manufacturer?.name ?? ""
                let m2 = (film2.film ?? film2.myFilm?.film)?.manufacturer?.name ?? ""
                let cmp = m1.localizedCaseInsensitiveCompare(m2)
                if cmp == .orderedSame {
                    let n1 = (film1.film ?? film1.myFilm?.film)?.name ?? ""
                    let n2 = (film2.film ?? film2.myFilm?.film)?.name ?? ""
                    let nameCmp = n1.localizedCaseInsensitiveCompare(n2)
                    if nameCmp == .orderedSame {
                        return ascending ? film1.finishedAt < film2.finishedAt : film1.finishedAt > film2.finishedAt
                    }
                    return ascending ? (nameCmp == .orderedAscending) : (nameCmp == .orderedDescending)
                }
                return ascending ? (cmp == .orderedAscending) : (cmp == .orderedDescending)
            case .filmName:
                let n1 = (film1.film ?? film1.myFilm?.film)?.name ?? ""
                let n2 = (film2.film ?? film2.myFilm?.film)?.name ?? ""
                let cmp = n1.localizedCaseInsensitiveCompare(n2)
                if cmp == .orderedSame {
                    return ascending ? film1.finishedAt < film2.finishedAt : film1.finishedAt > film2.finishedAt
                }
                return ascending ? (cmp == .orderedAscending) : (cmp == .orderedDescending)
            case .finishedDate:
                return ascending ? film1.finishedAt < film2.finishedAt : film1.finishedAt > film2.finishedAt
            case .iso:
                if film1.effectiveISO == film2.effectiveISO {
                    return ascending ? film1.finishedAt < film2.finishedAt : film1.finishedAt > film2.finishedAt
                }
                return ascending ? film1.effectiveISO < film2.effectiveISO : film1.effectiveISO > film2.effectiveISO
            }
        }
    }
    
    var availableTypes: [FilmStock.FilmType] {
        let types = finishedFilms.compactMap { film -> FilmStock.FilmType? in
            guard let filmType = (film.film ?? film.myFilm?.film)?.type else { return nil }
            return FilmStock.FilmType(rawValue: filmType)
        }
        return Array(Set(types)).sorted { $0.displayName < $1.displayName }
    }
    
    var availableFormats: [FilmStock.FilmFormat] {
        let formats = finishedFilms.compactMap { FilmStock.FilmFormat(rawValue: $0.format) }
        return Array(Set(formats)).sorted { $0.displayName < $1.displayName }
    }
    
    var availableCameras: [String] {
        let cameras = finishedFilms.compactMap { $0.cameraName }
        return Array(Set(cameras)).sorted()
    }
    
    var hasActiveFilters: Bool {
        !searchText.isEmpty || !selectedTypes.isEmpty || !selectedStatuses.isEmpty || 
        !selectedFormats.isEmpty || !selectedCameras.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("loaded.segment", selection: $selectedTab) {
                    Text("loaded.segment.loaded").tag(0)
                    Text("loaded.segment.finished").tag(1)
                }
                .pickerStyle(.segmented)
                .padding([.horizontal, .top])
                
                Group {
                    if selectedTab == 0 {
                        if loadedFilms.isEmpty {
                            ContentUnavailableView(
                                "empty.noLoadedFilms.title",
                                systemImage: "camera",
                                description: Text("empty.noLoadedFilms.message")
                            )
                        } else {
                            List {
                                ForEach(loadedFilms, id: \.persistentModelID) { loadedFilm in
                                    LoadedFilmRow(loadedFilm: loadedFilm)
                                        .contentShape(Rectangle())
                                        .onTapGesture { selectedLoadedFilm = loadedFilm }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            // Change loaded date
                                            Button {
                                                filmToEditDate = loadedFilm
                                                selectedDate = loadedFilm.loadedAt
                                                showingDatePicker = true
                                            } label: {
                                                Label("action.changeDate", systemImage: "calendar")
                                            }
                                            .tint(.orange)
                                            
                                            // Unload one sheet (for sheet films only)
                                            if isSheetFormat(loadedFilm.format) && loadedFilm.quantity > 1 {
                                                Button {
                                                    unloadOneSheet(loadedFilm)
                                                } label: {
                                                    Label("action.unloadOne", systemImage: "minus.circle")
                                                }
                                                .tint(.orange)
                                            }
                                            
                                            // Finish roll
                                            Button {
                                                unloadFilm(loadedFilm)
                                            } label: {
                                                Label("action.finishRoll", systemImage: "arrow.uturn.backward")
                                            }
                                            .tint(.green)
                                            
                                            // Remove roll (in case it was loaded accidentally)
                                            Button(role: .destructive) {
                                                removeLoadedFilm(loadedFilm)
                                            } label: {
                                                Label("action.remove", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                            .listStyle(.plain)
                        }
                    } else {
                        if finishedFilms.isEmpty {
                            ContentUnavailableView(
                                "empty.noFinishedFilms.title",
                                systemImage: "checkmark.seal",
                                description: Text("empty.noFinishedFilms.message")
                            )
                        } else {
                            VStack(spacing: 0) {
                                // Search bar and filter button
                                HStack(spacing: 12) {
                                    HStack {
                                        Image(systemName: "magnifyingglass")
                                            .foregroundColor(.secondary)
                                        TextField("search.placeholder", text: $searchText)
                                            .textFieldStyle(.plain)
                                    }
                                    .padding(8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                    
                                    Button {
                                        showingFilters = true
                                    } label: {
                                        Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                            .foregroundColor(hasActiveFilters ? .accentColor : .primary)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 8)
                                
                                if filteredAndSortedFinishedFilms.isEmpty {
                                    ContentUnavailableView(
                                        "search.noResults",
                                        systemImage: "magnifyingglass",
                                        description: Text("search.noResults.description")
                                    )
                                } else {
                                    List {
                                        ForEach(filteredAndSortedFinishedFilms, id: \.persistentModelID) { finishedFilm in
                                            FinishedFilmRow(finishedFilm: finishedFilm)
                                                .contentShape(Rectangle())
                                                .onTapGesture { selectedFinishedFilm = finishedFilm }
                                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                                    // Re-load film (move back to loaded films)
                                                    Button {
                                                        reloadFinishedFilm(finishedFilm)
                                                    } label: {
                                                        Label("action.reload", systemImage: "arrow.uturn.backward.circle")
                                                    }
                                                    .tint(.blue)
                                                }
                                        }
                                    }
                                    .listStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("tab.loadedFilms")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingManageCameras = true
                    } label: {
                        Image(systemName: "camera")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingHelp = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                }
            }
            .sheet(isPresented: $showingManageCameras) {
                ManageCamerasView()
                    .environmentObject(dataManager)
            }
            .sheet(isPresented: $showingDatePicker) {
                NavigationStack {
                    VStack(spacing: 20) {
                        DatePicker(
                            "loaded.changeDate.title",
                            selection: $selectedDate,
                            in: Date(timeIntervalSince1970: 0)...Date(),
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.graphical)
                        .padding()
                        
                        Spacer()
                    }
                    .navigationTitle("loaded.changeDate.title")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("action.cancel") {
                                showingDatePicker = false
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("action.save") {
                                if let film = filmToEditDate {
                                    updateLoadedDate(film, newDate: selectedDate)
                                }
                                showingDatePicker = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .alert("help.loadedFilms.title", isPresented: $showingHelp) {
                Button("action.done", role: .cancel) { }
            } message: {
                Text("help.loadedFilms.message")
            }
            .sheet(isPresented: $showingFilters) {
                finishedFilmsFilterSheet
            }
            .sheet(item: $selectedLoadedFilm) { film in
                LoadedFilmDetailSheet(loadedFilm: film)
            }
            .sheet(item: $selectedFinishedFilm) { film in
                FinishedFilmDetailSheet(finishedFilm: film)
                    .environmentObject(dataManager)
            }
            .onAppear {
                if dataManager.isMigrationComplete {
                    loadFilms()
                    loadFinishedFilms()
                    if let id = selectedFilmId {
                        handleSelectedFilmId(id)
                    }
                }
            }
            .onChange(of: dataManager.isMigrationComplete) { _, isComplete in
                if isComplete {
                    loadFilms()
                    loadFinishedFilms()
                    if let id = selectedFilmId {
                        handleSelectedFilmId(id)
                    }
                }
            }
            .onChange(of: selectedFilmId) { _, newId in
                if let newId = newId {
                    handleSelectedFilmId(newId)
                }
            }
            .onChange(of: selectedTab) { _, _ in
                refreshFilmsIfAllowed()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("LoadedFilmsChanged"))) { _ in
                refreshFilmsIfAllowed()
            }
            .onChange(of: showingManageCameras) { _, _ in refreshFilmsIfAllowed() }
            .onChange(of: showingFilters) { _, isShowing in
                if isShowing {
                    filterSheetTypes = availableTypes
                    filterSheetFormats = availableFormats
                    filterSheetCameras = availableCameras
                } else {
                    refreshFilmsIfAllowed()
                }
            }
            .onChange(of: showingDatePicker) { _, _ in refreshFilmsIfAllowed() }
            .onChange(of: showingHelp) { _, _ in refreshFilmsIfAllowed() }
            .onChange(of: selectedLoadedFilm) { _, _ in refreshFilmsIfAllowed() }
            .onChange(of: selectedFinishedFilm) { _, _ in refreshFilmsIfAllowed() }
        }
    }
    
    private func handleSelectedFilmId(_ filmId: String) {
        guard dataManager.isMigrationComplete else { return }
        
        if selectedTab != 0 {
            selectedTab = 0
        }
        
        showingManageCameras = false
        showingDatePicker = false
        showingFilters = false
        showingHelp = false
        selectedFinishedFilm = nil
        
        if selectedLoadedFilm?.id == filmId {
            selectedFilmId = nil
            return
        }
        
        if let film = loadedFilms.first(where: { $0.id == filmId }) {
            presentLoadedFilm(film)
            return
        }
        
        loadFilms()
        if let film = loadedFilms.first(where: { $0.id == filmId }) {
            presentLoadedFilm(film)
            return
        }
        
        selectedFilmId = nil
    }
    
    private func presentLoadedFilm(_ film: LoadedFilm) {
        if selectedLoadedFilm != nil {
            selectedLoadedFilm = nil
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 250_000_000)
                selectedLoadedFilm = film
                selectedFilmId = nil
            }
        } else {
            Task { @MainActor in
                selectedLoadedFilm = film
                selectedFilmId = nil
            }
        }
    }
    
    private func refreshFilmsIfAllowed() {
        guard dataManager.isMigrationComplete else { return }
        if isSheetBlockingRefresh {
            pendingFilmsRefresh = true
            return
        }
        pendingFilmsRefresh = false
        loadFilms()
        loadFinishedFilms()
    }
    
    var finishedFilmsFilterSheet: some View {
        NavigationStack {
            Form {
                // Film Type Filter
                if !filterSheetTypes.isEmpty {
                    Section("filter.type") {
                        ForEach(filterSheetTypes, id: \.self) { type in
                            Toggle(type.displayName, isOn: Binding(
                                get: { selectedTypes.contains(type) },
                                set: { isOn in
                                    if isOn {
                                        selectedTypes.insert(type)
                                    } else {
                                        selectedTypes.remove(type)
                                    }
                                }
                            ))
                        }
                    }
                }
                
                // Status Filter
                Section("finished.status") {
                    ForEach([FinishedFilmStatus.toDevelop, .inDevelopment, .developed], id: \.self) { status in
                        Toggle(LocalizedStringKey(status.labelKey), isOn: Binding(
                            get: { selectedStatuses.contains(status) },
                            set: { isOn in
                                if isOn {
                                    selectedStatuses.insert(status)
                                } else {
                                    selectedStatuses.remove(status)
                                }
                            }
                        ))
                    }
                }
                
                // Format Filter
                if !filterSheetFormats.isEmpty {
                    Section("filter.format") {
                        ForEach(filterSheetFormats, id: \.self) { format in
                            Toggle(format.displayName, isOn: Binding(
                                get: { selectedFormats.contains(format) },
                                set: { isOn in
                                    if isOn {
                                        selectedFormats.insert(format)
                                    } else {
                                        selectedFormats.remove(format)
                                    }
                                }
                            ))
                        }
                    }
                }
                
                // Camera Filter
                if !filterSheetCameras.isEmpty {
                    Section("filter.camera") {
                        ForEach(filterSheetCameras, id: \.self) { camera in
                            Toggle(camera, isOn: Binding(
                                get: { selectedCameras.contains(camera) },
                                set: { isOn in
                                    if isOn {
                                        selectedCameras.insert(camera)
                                    } else {
                                        selectedCameras.remove(camera)
                                    }
                                }
                            ))
                        }
                    }
                }
                
                // Sort Section
                Section("sort.title") {
                    HStack {
                        Picker("sort.field", selection: $sortField) {
                            ForEach(FinishedFilmSortField.allCases, id: \.self) { field in
                                Text(field.displayName).tag(field)
                            }
                        }
                        .labelsHidden()
                        
                        Spacer()
                        
                        Picker("sort.order", selection: $sortAscending) {
                            Image(systemName: "arrow.up").tag(true)
                            Image(systemName: "arrow.down").tag(false)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 100)
                    }
                }
                
                // Clear Filters
                if hasActiveFilters {
                    Section {
                        Button("filter.clearAll") {
                            searchText = ""
                            selectedTypes = []
                            selectedStatuses = []
                            selectedFormats = []
                            selectedCameras = []
                        }
                    }
                }
            }
            .navigationTitle("filter.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("action.done") {
                        showingFilters = false
                    }
                }
            }
        }
    }
    
    private func loadFilms() {
        loadedFilms = dataManager.getLoadedFilms()
    }
    
    private func loadFinishedFilms() {
        finishedFilms = dataManager.getFinishedFilms()
    }
    
    private func reloadFinishedFilm(_ finishedFilm: FinishedFilm) {
        dataManager.reloadFinishedFilm(finishedFilm)
        loadFilms()
        loadFinishedFilms()
    }
    
    private func unloadFilm(_ loadedFilm: LoadedFilm) {
        dataManager.unloadFilm(loadedFilm)
        loadFilms()
        loadFinishedFilms()
    }
    
    private func unloadOneSheet(_ loadedFilm: LoadedFilm) {
        dataManager.unloadFilm(loadedFilm, quantity: 1)
        loadFilms()
        loadFinishedFilms()
    }
    
    private func removeLoadedFilm(_ loadedFilm: LoadedFilm) {
        dataManager.deleteLoadedFilm(loadedFilm)
        loadFilms()
    }
    
    private func updateLoadedDate(_ loadedFilm: LoadedFilm, newDate: Date) {
        loadedFilm.loadedAt = newDate
        dataManager.saveContext()
        loadFilms()
    }
    
    private func isSheetFormat(_ format: String) -> Bool {
        guard let filmFormat = FilmStock.FilmFormat(rawValue: format) else {
            return false
        }
        return filmFormat == .fourByFive || filmFormat == .fiveBySeven || filmFormat == .eightByTen
    }
}

// MARK: - Loaded Film Detail Sheet

struct LoadedFilmDetailSheet: View {
    let loadedFilm: LoadedFilm
    @ObservedObject private var settingsManager = SettingsManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var filmImage: UIImage?

    private var resolvedFilm: Film? {
        loadedFilm.film ?? loadedFilm.myFilm?.film
    }

    var body: some View {
        NavigationStack {
            List {
                // Header: image + film name
                if let film = resolvedFilm {
                    Section {
                        HStack(spacing: 16) {
                            if let image = filmImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 72, height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            } else {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.systemGray5))
                                    .frame(width: 72, height: 72)
                                    .overlay(
                                        Image(systemName: "camera.fill")
                                            .font(.title2)
                                            .foregroundColor(.secondary)
                                    )
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(film.manufacturer?.name ?? "") \(film.name)")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                HStack(spacing: 6) {
                                    Text(FilmStock.FilmType(rawValue: film.type)?.displayName ?? film.type)
                                    Text("·")
                                    Text(formatDisplayName)
                                }
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } else {
                    Section {
                        HStack(spacing: 16) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.systemGray5))
                                .frame(width: 72, height: 72)
                                .overlay(
                                    Image(systemName: "camera.fill")
                                        .font(.title2)
                                        .foregroundColor(.secondary)
                                )
                            VStack(alignment: .leading, spacing: 4) {
                                Text(NSLocalizedString("finished.film.unavailable", comment: "Loaded roll with missing film catalog link"))
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                Text(formatDisplayName)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Roll info
                Section("loaded.detail.rollSection") {
                    if let cameraName = loadedFilm.cameraName {
                        detailRow(label: "camera.name", value: cameraName)
                    }
                    detailRow(label: "loaded.detail.loadedDate", value: exactDate(loadedFilm.loadedAt))
                    detailRow(label: "loaded.detail.daysOnCamera", value: daysOnCamera)
                }

                // Film properties
                Section("loaded.detail.filmSection") {
                    if let film = resolvedFilm {
                        if let shotISO = loadedFilm.shotAtISO, shotISO != film.filmSpeed {
                            HStack {
                                Text(LocalizedStringKey("load.shotAtISO"))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("ISO \(shotISO)")
                                    .fontWeight(.medium)
                                    .foregroundColor(.orange)
                                Text("(ISO \(film.filmSpeed))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            detailRow(label: "film.speed", value: "ISO \(film.filmSpeed)")
                        }
                    }
                    if let exposures = loadedFilm.myFilm?.exposures, exposures > 0 || exposures == kBulkRollExposures {
                        detailRow(label: "film.exposures", value: exposureDisplayLabel(exposures))
                    }
                    if let expireDates = loadedFilm.myFilm?.expireDateArray, !expireDates.isEmpty {
                        detailRow(
                            label: "film.expiryDate",
                            value: expireDates.map { FilmStock.formatExpireDate($0) }.joined(separator: ", ")
                        )
                    }
                    if loadedFilm.myFilm?.isFrozen == true {
                        frozenChip
                    }
                    if loadedFilm.myFilm?.isFridge == true && settingsManager.enableFridge {
                        fridgeChip
                    }
                }

                // Comments
                if let comments = loadedFilm.myFilm?.comments, !comments.isEmpty {
                    Section("film.comments") {
                        Text(comments).foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle("loaded.detail.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("action.done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear { loadImage() }
    }

    @ViewBuilder
    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(LocalizedStringKey(label)).foregroundColor(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
    }

    private var frozenChip: some View {
        Text(LocalizedStringKey("film.frozen"))
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.blue)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.blue, lineWidth: 1))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var fridgeChip: some View {
        Text(LocalizedStringKey("film.fridge"))
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.blue)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.blue, lineWidth: 1))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var formatDisplayName: String {
        if let customName = loadedFilm.myFilm?.customFormatName, !customName.isEmpty { return customName }
        return FilmStock.FilmFormat(rawValue: loadedFilm.format)?.displayName ?? loadedFilm.format
    }

    private var daysOnCamera: String {
        let days = max(0, Calendar.current.dateComponents([.day], from: loadedFilm.loadedAt, to: Date()).day ?? 0)
        switch days {
        case 0:  return NSLocalizedString("loaded.detail.today", comment: "")
        case 1:  return String(format: NSLocalizedString("loaded.detail.day", comment: ""), days)
        default: return String(format: NSLocalizedString("loaded.detail.days", comment: ""), days)
        }
    }

    private func exactDate(_ date: Date) -> String {
        LoadedFilmsFormatters.exactDateTime.string(from: date)
    }

    private func loadImage() {
        guard let film = resolvedFilm else {
            filmImage = nil
            return
        }
        filmImage = ImageStorage.shared.resolveFilmImage(
            imageSourceRawValue: film.imageSource,
            imageName: film.imageName,
            filmName: film.name,
            manufacturer: film.manufacturer?.name ?? ""
        )
    }
}

enum FinishedFilmStatus: String {
    case toDevelop
    case inDevelopment
    case developed
    
    var labelKey: String {
        switch self {
        case .toDevelop: return "finished.status.toDevelop"
        case .inDevelopment: return "finished.status.inDevelopment"
        case .developed: return "finished.status.developed"
        }
    }
}

struct LoadedFilmRow: View {
    let loadedFilm: LoadedFilm
    @State private var filmImage: UIImage?
    
    private var resolvedFilm: Film? {
        loadedFilm.film ?? loadedFilm.myFilm?.film
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
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
                    if let film = resolvedFilm {
                        Text("\(film.manufacturer?.name ?? "") \(film.name)")
                            .font(.headline)
                        
                        HStack(spacing: 4) {
                            // Show effective ISO (shot at ISO if different, otherwise native)
                            let iso = loadedFilm.shotAtISO ?? film.filmSpeed
                            if loadedFilm.shotAtISO != nil {
                                Text("ISO \(iso)")
                                    .foregroundColor(.orange)
                            } else {
                                Text("ISO \(iso)")
                            }
                            Text("•")
                            Text(formatDisplayName)
                            if isSheetFormat(loadedFilm.format) {
                                Text("•")
                                Text(loadedFilm.quantity == 1 
                                     ? String(format: NSLocalizedString("format.sheet.count", comment: ""), loadedFilm.quantity)
                                     : String(format: NSLocalizedString("format.sheets.count", comment: ""), loadedFilm.quantity))
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    } else {
                        Text(NSLocalizedString("finished.film.unavailable", comment: "Loaded roll with missing film catalog link"))
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text(formatDisplayName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let cameraName = loadedFilm.cameraName {
                        HStack(spacing: 4) {
                            Image(systemName: "camera.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(cameraName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text(String(format: NSLocalizedString("time.loadedAt", comment: ""), formatDate(loadedFilm.loadedAt)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
            
            // Red "EXPIRED" chip in top right
            if isExpired {
                Text("film.expired")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.red, lineWidth: 1)
                    )
                    .padding(.top, 4)
                    .padding(.trailing, 4)
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private var formatDisplayName: String {
        // Check for custom format name first
        if let customName = loadedFilm.myFilm?.customFormatName, !customName.isEmpty {
            return customName
        }
        guard let format = FilmStock.FilmFormat(rawValue: loadedFilm.format) else {
            return loadedFilm.format
        }
        return format.displayName
    }
    
    private func formatDate(_ date: Date) -> String {
        LoadedFilmsFormatters.relativeDate.localizedString(for: date, relativeTo: Date())
    }
    
    private func loadImage() {
        guard let film = resolvedFilm else {
            filmImage = nil
            return
        }
        filmImage = ImageStorage.shared.resolveFilmImage(
            imageSourceRawValue: film.imageSource,
            imageName: film.imageName,
            filmName: film.name,
            manufacturer: film.manufacturer?.name ?? ""
        )
    }
    
    private func isSheetFormat(_ format: String) -> Bool {
        guard let filmFormat = FilmStock.FilmFormat(rawValue: format) else {
            return false
        }
        return filmFormat == .fourByFive || filmFormat == .fiveBySeven || filmFormat == .eightByTen
    }
    
    private var isExpired: Bool {
        guard let expireDates = loadedFilm.myFilm?.expireDateArray, !expireDates.isEmpty else {
            return false
        }
        let today = Date()
        return expireDates.contains { dateString in
            guard let parsed = FilmStock.parseExpireDate(dateString) else { return false }
            return parsed < today
        }
    }
}

struct FinishedFilmRow: View {
    let finishedFilm: FinishedFilm
    @State private var filmImage: UIImage?
    @EnvironmentObject var dataManager: FilmStockDataManager
    
    private var resolvedFilm: Film? {
        finishedFilm.film ?? finishedFilm.myFilm?.film
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
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
                    if let film = resolvedFilm {
                        Text("\(film.manufacturer?.name ?? "") \(film.name)")
                            .font(.headline)
                        
                        HStack(spacing: 4) {
                            let iso = finishedFilm.shotAtISO ?? film.filmSpeed
                            if finishedFilm.shotAtISO != nil {
                                Text("ISO \(iso)")
                                    .foregroundColor(.orange)
                            } else {
                                Text("ISO \(iso)")
                            }
                            Text("•")
                            Text(formatDisplayName)
                            if isSheetFormat(finishedFilm.format) {
                                Text("•")
                                Text(finishedFilm.quantity == 1
                                     ? String(format: NSLocalizedString("format.sheet.count", comment: ""), finishedFilm.quantity)
                                     : String(format: NSLocalizedString("format.sheets.count", comment: ""), finishedFilm.quantity))
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    } else {
                        Text(NSLocalizedString("finished.film.unavailable", comment: "Finished roll with missing film catalog link"))
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text(formatDisplayName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 6) {
                        // Use stored camera name (never access camera relationship to avoid crashes)
                        if let cameraName = finishedFilm.cameraName {
                            HStack(spacing: 4) {
                                Image(systemName: "camera.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(cameraName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Text(String(format: NSLocalizedString("time.loadedAt", comment: ""), formatDate(finishedFilm.loadedAt)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(String(format: NSLocalizedString("time.finishedAt", comment: ""), formatDate(finishedFilm.finishedAt)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
            
            statusChip
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if status != .inDevelopment {
                Button {
                    updateStatus(.inDevelopment)
                } label: {
                    Label("finished.status.inDevelopment", systemImage: "clock.arrow.circlepath")
                }
                .tint(.yellow)
            }
            
            if status != .developed {
                Button {
                    updateStatus(.developed)
                } label: {
                    Label("finished.status.developed", systemImage: "checkmark.circle.fill")
                }
                .tint(.green)
            }
            
            if status != .toDevelop {
                Button {
                    updateStatus(.toDevelop)
                } label: {
                    Label("finished.status.toDevelop", systemImage: "arrow.uturn.backward.circle")
                }
                .tint(.gray)
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private var status: FinishedFilmStatus {
        FinishedFilmStatus(rawValue: finishedFilm.status ?? "") ?? .toDevelop
    }
    
    private var statusChip: some View {
        Text(LocalizedStringKey(status.labelKey))
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(statusColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(statusColor, lineWidth: 1)
            )
            .padding(.top, 4)
            .padding(.trailing, 4)
    }
    
    private var statusColor: Color {
        switch status {
        case .toDevelop: return .gray
        case .inDevelopment: return .yellow
        case .developed: return .green
        }
    }
    
    private func updateStatus(_ newStatus: FinishedFilmStatus) {
        dataManager.updateFinishedFilmStatus(finishedFilm, status: newStatus)
    }
    
    private var formatDisplayName: String {
        if let customName = finishedFilm.myFilm?.customFormatName, !customName.isEmpty {
            return customName
        }
        guard let format = FilmStock.FilmFormat(rawValue: finishedFilm.format) else {
            return finishedFilm.format
        }
        return format.displayName
    }
    
    private func formatDate(_ date: Date) -> String {
        LoadedFilmsFormatters.relativeDate.localizedString(for: date, relativeTo: Date())
    }
    
    private func loadImage() {
        guard let film = resolvedFilm else {
            filmImage = nil
            return
        }
        filmImage = ImageStorage.shared.resolveFilmImage(
            imageSourceRawValue: film.imageSource,
            imageName: film.imageName,
            filmName: film.name,
            manufacturer: film.manufacturer?.name ?? ""
        )
    }
    
    private func isSheetFormat(_ format: String) -> Bool {
        guard let filmFormat = FilmStock.FilmFormat(rawValue: format) else {
            return false
        }
        return filmFormat == .fourByFive || filmFormat == .fiveBySeven || filmFormat == .eightByTen
    }
}


// MARK: - Finished Film Detail Sheet

struct FinishedFilmDetailSheet: View {
    let finishedFilm: FinishedFilm
    @EnvironmentObject var dataManager: FilmStockDataManager
    @ObservedObject private var settingsManager = SettingsManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var filmImage: UIImage?
    @State private var showFinishDateEditor = false
    @State private var draftFinishedAt = Date()

    private var resolvedFilm: Film? {
        finishedFilm.film ?? finishedFilm.myFilm?.film
    }

    private var status: FinishedFilmStatus {
        FinishedFilmStatus(rawValue: finishedFilm.status ?? "") ?? .toDevelop
    }

    var body: some View {
        NavigationStack {
            List {
                // Header: image + film name
                if let film = resolvedFilm {
                    Section {
                        HStack(spacing: 16) {
                            if let image = filmImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 72, height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            } else {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.systemGray5))
                                    .frame(width: 72, height: 72)
                                    .overlay(
                                        Image(systemName: "camera.fill")
                                            .font(.title2)
                                            .foregroundColor(.secondary)
                                    )
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(film.manufacturer?.name ?? "") \(film.name)")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                HStack(spacing: 6) {
                                    Text(FilmStock.FilmType(rawValue: film.type)?.displayName ?? film.type)
                                    Text("·")
                                    Text(formatDisplayName)
                                }
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                Text(LocalizedStringKey(status.labelKey))
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(statusColor)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(statusColor, lineWidth: 1))
                                    .padding(.top, 2)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } else {
                    Section {
                        HStack(spacing: 16) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.systemGray5))
                                .frame(width: 72, height: 72)
                                .overlay(
                                    Image(systemName: "camera.fill")
                                        .font(.title2)
                                        .foregroundColor(.secondary)
                                )
                            VStack(alignment: .leading, spacing: 4) {
                                Text(NSLocalizedString("finished.film.unavailable", comment: "Finished roll with missing film catalog link"))
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                Text(formatDisplayName)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(LocalizedStringKey(status.labelKey))
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(statusColor)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(statusColor, lineWidth: 1))
                                    .padding(.top, 2)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Timeline
                Section("loaded.detail.rollSection") {
                    if let cameraName = finishedFilm.cameraName {
                        detailRow(label: "camera.name", value: cameraName)
                    }
                    detailRow(label: "loaded.detail.loadedDate", value: exactDate(finishedFilm.loadedAt))
                    finishedDateRow
                    if let developedAt = finishedFilm.developedAt {
                        detailRow(label: "finished.detail.developedDate", value: exactDate(developedAt))
                    }
                    detailRow(label: "finished.detail.daysOnRoll", value: daysOnRoll)
                }

                // Film properties
                Section("loaded.detail.filmSection") {
                    if let film = resolvedFilm {
                        if let shotISO = finishedFilm.shotAtISO, shotISO != film.filmSpeed {
                            HStack {
                                Text(LocalizedStringKey("load.shotAtISO"))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("ISO \(shotISO)")
                                    .fontWeight(.medium)
                                    .foregroundColor(.orange)
                                Text("(ISO \(film.filmSpeed))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            detailRow(label: "film.speed", value: "ISO \(film.filmSpeed)")
                        }
                    }
                    if let exposures = finishedFilm.myFilm?.exposures, exposures > 0 || exposures == kBulkRollExposures {
                        detailRow(label: "film.exposures", value: exposureDisplayLabel(exposures))
                    }
                    if let expireDates = finishedFilm.myFilm?.expireDateArray, !expireDates.isEmpty {
                        detailRow(
                            label: "film.expiryDate",
                            value: expireDates.map { FilmStock.formatExpireDate($0) }.joined(separator: ", ")
                        )
                    }
                    if finishedFilm.myFilm?.isFrozen == true {
                        frozenChip
                    }
                    if finishedFilm.myFilm?.isFridge == true && settingsManager.enableFridge {
                        fridgeChip
                    }
                }

                if let comments = finishedFilm.myFilm?.comments, !comments.isEmpty {
                    Section("film.comments") {
                        Text(comments).foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle("finished.detail.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("action.done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear { loadImage() }
        .sheet(isPresented: $showFinishDateEditor) {
            NavigationStack {
                Form {
                    DatePicker(
                        "finished.detail.finishedDate",
                        selection: $draftFinishedAt,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
                .navigationTitle("finished.editFinishedDate.title")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("action.cancel") {
                            showFinishDateEditor = false
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("action.save") {
                            dataManager.updateFinishedFilmFinishedAt(finishedFilm, finishedAt: draftFinishedAt)
                            showFinishDateEditor = false
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .presentationDetents([.medium])
            .onAppear {
                draftFinishedAt = finishedFilm.finishedAt
            }
        }
    }

    private var finishedDateRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(LocalizedStringKey("finished.detail.finishedDate"))
                .foregroundColor(.secondary)
            Spacer()
            Text(exactDate(finishedFilm.finishedAt))
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
            Button {
                draftFinishedAt = finishedFilm.finishedAt
                showFinishDateEditor = true
            } label: {
                Image(systemName: "pencil.circle")
                    .font(.body)
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(Text(LocalizedStringKey("finished.editFinishedDate.a11y")))
        }
    }

    @ViewBuilder
    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(LocalizedStringKey(label)).foregroundColor(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
    }

    private var frozenChip: some View {
        Text(LocalizedStringKey("film.frozen"))
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.blue)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.blue, lineWidth: 1))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var fridgeChip: some View {
        Text(LocalizedStringKey("film.fridge"))
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.blue)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.blue, lineWidth: 1))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var formatDisplayName: String {
        if let customName = finishedFilm.myFilm?.customFormatName, !customName.isEmpty { return customName }
        return FilmStock.FilmFormat(rawValue: finishedFilm.format)?.displayName ?? finishedFilm.format
    }

    private var daysOnRoll: String {
        let days = max(1, Calendar.current.dateComponents([.day], from: finishedFilm.loadedAt, to: finishedFilm.finishedAt).day ?? 1)
        switch days {
        case 1:  return String(format: NSLocalizedString("loaded.detail.day", comment: ""), days)
        default: return String(format: NSLocalizedString("loaded.detail.days", comment: ""), days)
        }
    }

    private var statusColor: Color {
        switch status {
        case .toDevelop:     return .gray
        case .inDevelopment: return .yellow
        case .developed:     return .green
        }
    }

    private func exactDate(_ date: Date) -> String {
        LoadedFilmsFormatters.exactDateTime.string(from: date)
    }

    private func loadImage() {
        guard let film = resolvedFilm else {
            filmImage = nil
            return
        }
        filmImage = ImageStorage.shared.resolveFilmImage(
            imageSourceRawValue: film.imageSource,
            imageName: film.imageName,
            filmName: film.name,
            manufacturer: film.manufacturer?.name ?? ""
        )
    }
}
