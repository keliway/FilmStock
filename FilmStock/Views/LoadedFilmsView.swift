//
//  LoadedFilmsView.swift
//  FilmStock
//
//  View showing all currently loaded and finished films
//

import SwiftUI
import SwiftData

private enum LoadedFilmsDisplay {
    private static let exactDateTime: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .short
        return f
    }()

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()

    static func exactDate(_ date: Date) -> String {
        exactDateTime.string(from: date)
    }

    static func relativeDate(_ date: Date) -> String {
        relativeDateFormatter.localizedString(for: date, relativeTo: Date())
    }

    static func formatDisplayName(rawFormat: String, customFormatName: String?) -> String {
        if let customName = customFormatName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !customName.isEmpty {
            return customName
        }
        return FilmStock.FilmFormat(rawValue: rawFormat)?.displayName ?? rawFormat
    }

    static func resolveImage(for film: Film?) -> UIImage? {
        guard let film else { return nil }
        return ImageStorage.shared.resolveFilmImage(
            imageSourceRawValue: film.imageSource,
            imageName: film.imageName,
            filmName: film.name,
            manufacturer: film.manufacturer?.name ?? ""
        )
    }
}

enum FinishedFilmStatus: String, CaseIterable {
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

    var color: Color {
        switch self {
        case .toDevelop: return .gray
        case .inDevelopment: return .yellow
        case .developed: return .green
        }
    }
}

private struct FinishedFormatFilterOption: Hashable {
    let format: FilmStock.FilmFormat
    let customName: String?

    var displayName: String {
        if format == .other, let customName, !customName.isEmpty {
            return customName
        }
        return format.displayName
    }

    static func from(_ film: FinishedFilm) -> FinishedFormatFilterOption? {
        guard let format = FilmStock.FilmFormat(rawValue: film.format) else { return nil }
        let rawCustom = film.myFilm?.customFormatName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let custom = (format == .other && rawCustom?.isEmpty == false) ? rawCustom : nil
        return FinishedFormatFilterOption(format: format, customName: custom)
    }
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
    @State private var selectedFormats: Set<FinishedFormatFilterOption> = []
    @State private var selectedCameras: Set<String> = []
    @State private var sortField: FinishedFilmSortField = .finishedDate
    @State private var sortAscending: Bool = false
    @State private var pendingFilmsRefresh = false

    /// Snapshot filter options when the sheet opens so section options stay stable while visible.
    @State private var filterSheetTypes: [FilmStock.FilmType] = []
    @State private var filterSheetFormats: [FinishedFormatFilterOption] = []
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
            let searchLower = searchText.lowercased()
            filtered = filtered.filter { film in
                let resolvedFilm = film.film ?? film.myFilm?.film
                let manufacturer = resolvedFilm?.manufacturer?.name ?? ""
                let filmName = resolvedFilm?.name ?? ""
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

        // Format filter (supports distinct custom format names)
        if !selectedFormats.isEmpty {
            filtered = filtered.filter { film in
                guard let option = FinishedFormatFilterOption.from(film) else { return false }
                return selectedFormats.contains(option)
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

    private var availableFormats: [FinishedFormatFilterOption] {
        let formats = finishedFilms.compactMap { FinishedFormatFilterOption.from($0) }
        return Array(Set(formats)).sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
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
                                            if FilmStock.FilmFormat.isSheetFormat(loadedFilm.format) && loadedFilm.quantity > 1 {
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
                                showingDatePicker = false
                                if let film = filmToEditDate {
                                    updateLoadedDate(film, newDate: selectedDate)
                                }
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
                    .environmentObject(dataManager)
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
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("LoadedFilmsChanged"))) { _ in
                refreshFilmsIfAllowed()
            }
            .onChange(of: showingFilters) { _, isShowing in
                if isShowing {
                    filterSheetTypes = availableTypes
                    filterSheetFormats = availableFormats
                    filterSheetCameras = availableCameras
                }
            }
            .onChange(of: isSheetBlockingRefresh) { _, isBlocking in
                if !isBlocking && pendingFilmsRefresh {
                    pendingFilmsRefresh = false
                    loadFilms()
                    loadFinishedFilms()
                }
            }
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

    private func setMembershipBinding<Element: Hashable>(_ set: Binding<Set<Element>>, element: Element) -> Binding<Bool> {
        Binding(
            get: { set.wrappedValue.contains(element) },
            set: { isOn in
                if isOn {
                    set.wrappedValue.insert(element)
                } else {
                    set.wrappedValue.remove(element)
                }
            }
        )
    }

    var finishedFilmsFilterSheet: some View {
        NavigationStack {
            Form {
                if !filterSheetTypes.isEmpty {
                    Section("filter.type") {
                        ForEach(filterSheetTypes, id: \.self) { type in
                            Toggle(type.displayName, isOn: setMembershipBinding($selectedTypes, element: type))
                        }
                    }
                }

                Section("finished.status") {
                    ForEach(FinishedFilmStatus.allCases, id: \.self) { status in
                        Toggle(LocalizedStringKey(status.labelKey), isOn: setMembershipBinding($selectedStatuses, element: status))
                    }
                }

                if !filterSheetFormats.isEmpty {
                    Section("filter.format") {
                        ForEach(filterSheetFormats, id: \.self) { formatOption in
                            Toggle(formatOption.displayName, isOn: setMembershipBinding($selectedFormats, element: formatOption))
                        }
                    }
                }

                if !filterSheetCameras.isEmpty {
                    Section("filter.camera") {
                        ForEach(filterSheetCameras, id: \.self) { camera in
                            Toggle(camera, isOn: setMembershipBinding($selectedCameras, element: camera))
                        }
                    }
                }

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
        dataManager.updateLoadedFilmDate(loadedFilm, loadedAt: newDate)
        loadFilms()
    }
}

// MARK: - Shared Row & Detail Components

private struct FilmRollThumbnail: View {
    let image: UIImage?
    let size: CGFloat
    let cornerRadius: CGFloat
    let placeholderIcon: String
    let placeholderBackground: Color
    var iconFont: Font? = nil
    var iconColor: Color = .secondary

    var body: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(placeholderBackground)
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: placeholderIcon)
                        .font(iconFont)
                        .foregroundColor(iconColor)
                )
        }
    }
}

private struct FilmOutlineBadge: View {
    let key: String
    let color: Color
    var cornerRadius: CGFloat = 3
    var horizontalPadding: CGFloat = 5
    var verticalPadding: CGFloat = 2
    var expandLeading: Bool = false

    var body: some View {
        let badge = Text(LocalizedStringKey(key))
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(color)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(color, lineWidth: 1))

        if expandLeading {
            badge.frame(maxWidth: .infinity, alignment: .leading)
        } else {
            badge
        }
    }
}

private struct FilmRollDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(LocalizedStringKey(label)).foregroundColor(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
    }
}

private struct FilmRollHeaderSection: View {
    let film: Film?
    let image: UIImage?
    let formatDisplayName: String
    var status: FinishedFilmStatus? = nil

    var body: some View {
        Section {
            HStack(spacing: 16) {
                FilmRollThumbnail(
                    image: image,
                    size: 72,
                    cornerRadius: 10,
                    placeholderIcon: "camera.fill",
                    placeholderBackground: Color(.systemGray5),
                    iconFont: .title2,
                    iconColor: .secondary
                )

                VStack(alignment: .leading, spacing: 4) {
                    if let film {
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
                    } else {
                        Text(NSLocalizedString("finished.film.unavailable", comment: "Roll with missing film catalog link"))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        Text(formatDisplayName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    if let status {
                        FilmOutlineBadge(key: status.labelKey, color: status.color)
                            .padding(.top, 2)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

private struct FilmRollPropertiesSection: View {
    let film: Film?
    let shotAtISO: Int?
    let myFilm: MyFilm?
    let enableFridge: Bool

    var body: some View {
        Section("loaded.detail.filmSection") {
            if let film {
                if let shotAtISO, shotAtISO != film.filmSpeed {
                    HStack {
                        Text(LocalizedStringKey("load.shotAtISO"))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("ISO \(shotAtISO)")
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                        Text("(ISO \(film.filmSpeed))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    FilmRollDetailRow(label: "film.speed", value: "ISO \(film.filmSpeed)")
                }
            }
            if let exposures = myFilm?.exposures, exposures > 0 || exposures == kBulkRollExposures {
                FilmRollDetailRow(label: "film.exposures", value: exposureDisplayLabel(exposures))
            }
            if let expireDates = myFilm?.expireDateArray, !expireDates.isEmpty {
                FilmRollDetailRow(
                    label: "film.expiryDate",
                    value: expireDates.map { FilmStock.formatExpireDate($0) }.joined(separator: ", ")
                )
            }
            if myFilm?.isFrozen == true {
                FilmOutlineBadge(key: "film.frozen", color: .blue, expandLeading: true)
            }
            if myFilm?.isFridge == true && enableFridge {
                FilmOutlineBadge(key: "film.fridge", color: .blue, expandLeading: true)
            }
        }
    }
}

private struct FilmRollSubtitleMetadata: View {
    let film: Film
    let shotAtISO: Int?
    let rawFormat: String
    let formatDisplayName: String
    let quantity: Int

    var body: some View {
        HStack(spacing: 4) {
            let iso = shotAtISO ?? film.filmSpeed
            Text("ISO \(iso)")
                .foregroundColor(shotAtISO != nil ? .orange : .secondary)
            Text("•")
            Text(formatDisplayName)
            if FilmStock.FilmFormat.isSheetFormat(rawFormat) {
                Text("•")
                Text(FilmStock.localizedSheetCount(quantity))
                    .foregroundColor(.accentColor)
            }
        }
        .font(.subheadline)
        .foregroundColor(.secondary)
    }
}

// MARK: - Loaded Film Detail Sheet

struct LoadedFilmDetailSheet: View {
    let loadedFilm: LoadedFilm
    @EnvironmentObject var dataManager: FilmStockDataManager
    @ObservedObject private var settingsManager = SettingsManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var filmImage: UIImage?
    @State private var commentsText: String = ""

    private var resolvedFilm: Film? {
        loadedFilm.film ?? loadedFilm.myFilm?.film
    }

    private var formatDisplayName: String {
        LoadedFilmsDisplay.formatDisplayName(
            rawFormat: loadedFilm.format,
            customFormatName: loadedFilm.myFilm?.customFormatName
        )
    }

    var body: some View {
        NavigationStack {
            List {
                FilmRollHeaderSection(
                    film: resolvedFilm,
                    image: filmImage,
                    formatDisplayName: formatDisplayName
                )

                Section("loaded.detail.rollSection") {
                    if let cameraName = loadedFilm.cameraName {
                        FilmRollDetailRow(label: "camera.name", value: cameraName)
                    }
                    if FilmStock.FilmFormat.isSheetFormat(loadedFilm.format) {
                        FilmRollDetailRow(label: "detail.sheets", value: "\(loadedFilm.quantity)")
                    }
                    FilmRollDetailRow(label: "loaded.detail.loadedDate", value: LoadedFilmsDisplay.exactDate(loadedFilm.loadedAt))
                    FilmRollDetailRow(label: "loaded.detail.daysOnCamera", value: daysOnCamera)
                }

                FilmRollPropertiesSection(
                    film: resolvedFilm,
                    shotAtISO: loadedFilm.shotAtISO,
                    myFilm: loadedFilm.myFilm,
                    enableFridge: settingsManager.enableFridge
                )

                Section("film.comments") {
                    TextField("film.comments.placeholder", text: $commentsText, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("loaded.detail.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("action.done") {
                        commitCommentsIfChanged()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            filmImage = LoadedFilmsDisplay.resolveImage(for: resolvedFilm)
            commentsText = loadedFilm.effectiveComments ?? ""
        }
        .onDisappear {
            commitCommentsIfChanged()
        }
    }

    private func commitCommentsIfChanged() {
        dataManager.updateLoadedFilmComments(loadedFilm, comments: commentsText)
    }

    private var daysOnCamera: String {
        let days = max(0, Calendar.current.dateComponents([.day], from: loadedFilm.loadedAt, to: Date()).day ?? 0)
        switch days {
        case 0:  return NSLocalizedString("loaded.detail.today", comment: "")
        case 1:  return String(format: NSLocalizedString("loaded.detail.day", comment: ""), days)
        default: return String(format: NSLocalizedString("loaded.detail.days", comment: ""), days)
        }
    }
}

// MARK: - Rows

struct LoadedFilmRow: View {
    let loadedFilm: LoadedFilm
    @State private var filmImage: UIImage?

    private var resolvedFilm: Film? {
        loadedFilm.film ?? loadedFilm.myFilm?.film
    }

    private var formatDisplayName: String {
        LoadedFilmsDisplay.formatDisplayName(
            rawFormat: loadedFilm.format,
            customFormatName: loadedFilm.myFilm?.customFormatName
        )
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 12) {
                FilmRollThumbnail(
                    image: filmImage,
                    size: 60,
                    cornerRadius: 8,
                    placeholderIcon: "camera",
                    placeholderBackground: Color.gray.opacity(0.3),
                    iconColor: .gray
                )

                VStack(alignment: .leading, spacing: 4) {
                    if let film = resolvedFilm {
                        Text("\(film.manufacturer?.name ?? "") \(film.name)")
                            .font(.headline)

                        FilmRollSubtitleMetadata(
                            film: film,
                            shotAtISO: loadedFilm.shotAtISO,
                            rawFormat: loadedFilm.format,
                            formatDisplayName: formatDisplayName,
                            quantity: loadedFilm.quantity
                        )
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

                    Text(String(format: NSLocalizedString("time.loadedAt", comment: ""), LoadedFilmsDisplay.relativeDate(loadedFilm.loadedAt)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, 4)

            if isExpired {
                FilmOutlineBadge(
                    key: "film.expired",
                    color: .red,
                    cornerRadius: 4,
                    horizontalPadding: 6,
                    verticalPadding: 3
                )
                .padding(.top, 4)
                .padding(.trailing, 4)
            }
        }
        .onAppear {
            filmImage = LoadedFilmsDisplay.resolveImage(for: resolvedFilm)
        }
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

    private var status: FinishedFilmStatus {
        FinishedFilmStatus(rawValue: finishedFilm.status ?? "") ?? .toDevelop
    }

    private var formatDisplayName: String {
        LoadedFilmsDisplay.formatDisplayName(
            rawFormat: finishedFilm.format,
            customFormatName: finishedFilm.myFilm?.customFormatName
        )
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 12) {
                FilmRollThumbnail(
                    image: filmImage,
                    size: 60,
                    cornerRadius: 8,
                    placeholderIcon: "camera",
                    placeholderBackground: Color.gray.opacity(0.3),
                    iconColor: .gray
                )

                VStack(alignment: .leading, spacing: 4) {
                    if let film = resolvedFilm {
                        Text("\(film.manufacturer?.name ?? "") \(film.name)")
                            .font(.headline)

                        FilmRollSubtitleMetadata(
                            film: film,
                            shotAtISO: finishedFilm.shotAtISO,
                            rawFormat: finishedFilm.format,
                            formatDisplayName: formatDisplayName,
                            quantity: finishedFilm.quantity
                        )
                    } else {
                        Text(NSLocalizedString("finished.film.unavailable", comment: "Finished roll with missing film catalog link"))
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text(formatDisplayName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 6) {
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

                        Text(String(format: NSLocalizedString("time.loadedAt", comment: ""), LoadedFilmsDisplay.relativeDate(finishedFilm.loadedAt)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text(String(format: NSLocalizedString("time.finishedAt", comment: ""), LoadedFilmsDisplay.relativeDate(finishedFilm.finishedAt)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, 4)

            FilmOutlineBadge(
                key: status.labelKey,
                color: status.color,
                cornerRadius: 4,
                horizontalPadding: 6,
                verticalPadding: 3
            )
            .padding(.top, 4)
            .padding(.trailing, 4)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if status != .inDevelopment {
                Button {
                    dataManager.updateFinishedFilmStatus(finishedFilm, status: .inDevelopment)
                } label: {
                    Label("finished.status.inDevelopment", systemImage: "clock.arrow.circlepath")
                }
                .tint(.yellow)
            }

            if status != .developed {
                Button {
                    dataManager.updateFinishedFilmStatus(finishedFilm, status: .developed)
                } label: {
                    Label("finished.status.developed", systemImage: "checkmark.circle.fill")
                }
                .tint(.green)
            }

            if status != .toDevelop {
                Button {
                    dataManager.updateFinishedFilmStatus(finishedFilm, status: .toDevelop)
                } label: {
                    Label("finished.status.toDevelop", systemImage: "arrow.uturn.backward.circle")
                }
                .tint(.gray)
            }
        }
        .onAppear {
            filmImage = LoadedFilmsDisplay.resolveImage(for: resolvedFilm)
        }
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

    private var formatDisplayName: String {
        LoadedFilmsDisplay.formatDisplayName(
            rawFormat: finishedFilm.format,
            customFormatName: finishedFilm.myFilm?.customFormatName
        )
    }

    var body: some View {
        NavigationStack {
            List {
                FilmRollHeaderSection(
                    film: resolvedFilm,
                    image: filmImage,
                    formatDisplayName: formatDisplayName,
                    status: status
                )

                Section("loaded.detail.rollSection") {
                    if let cameraName = finishedFilm.cameraName {
                        FilmRollDetailRow(label: "camera.name", value: cameraName)
                    }
                    if FilmStock.FilmFormat.isSheetFormat(finishedFilm.format) {
                        FilmRollDetailRow(label: "detail.sheets", value: "\(finishedFilm.quantity)")
                    }
                    FilmRollDetailRow(label: "loaded.detail.loadedDate", value: LoadedFilmsDisplay.exactDate(finishedFilm.loadedAt))
                    finishedDateRow
                    if let developedAt = finishedFilm.developedAt {
                        FilmRollDetailRow(label: "finished.detail.developedDate", value: LoadedFilmsDisplay.exactDate(developedAt))
                    }
                    FilmRollDetailRow(label: "finished.detail.daysOnRoll", value: daysOnRoll)
                }

                FilmRollPropertiesSection(
                    film: resolvedFilm,
                    shotAtISO: finishedFilm.shotAtISO,
                    myFilm: finishedFilm.myFilm,
                    enableFridge: settingsManager.enableFridge
                )

                if let comments = finishedFilm.effectiveComments, !comments.isEmpty {
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
        .onAppear {
            filmImage = LoadedFilmsDisplay.resolveImage(for: resolvedFilm)
        }
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
            Text(LoadedFilmsDisplay.exactDate(finishedFilm.finishedAt))
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

    private var daysOnRoll: String {
        let days = max(1, Calendar.current.dateComponents([.day], from: finishedFilm.loadedAt, to: finishedFilm.finishedAt).day ?? 1)
        switch days {
        case 1:  return String(format: NSLocalizedString("loaded.detail.day", comment: ""), days)
        default: return String(format: NSLocalizedString("loaded.detail.days", comment: ""), days)
        }
    }
}
