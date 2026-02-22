//
//  LoadFilmView.swift
//  FilmStock
//
//  View for loading a film into a camera
//

import SwiftUI

struct LoadFilmView: View {
    let groupedFilm: GroupedFilm
    @EnvironmentObject var dataManager: FilmStockDataManager
    @Environment(\.dismiss) var dismiss
    var onLoadComplete: (() -> Void)?
    
    @State private var selectedFormat: FilmStock.FilmFormat?
    @State private var selectedRollId: String? // For roll formats: the specific MyFilm.id to load
    @State private var selectedCamera: String = ""
    @State private var errorMessage: String?
    @State private var sheetQuantity: Int = 1
    @State private var shotAtISO: Int = 0
    
    var availableFormats: [FilmStock.FilmFormat] {
        let formatsWithQuantity = groupedFilm.formats.filter { formatInfo in
            formatInfo.quantity > 0
        }
        return formatsWithQuantity.map { formatInfo in
            formatInfo.format
        }
    }
    
    var availableCameras: [Camera] {
        dataManager.getAllCameras()
    }
    
    var body: some View {
        NavigationStack {
            Form {
                formatSelectionSection
                rollPickerSection
                cameraSelectionSection
                isoSelectionSection
                quantitySelectionSection
                errorSection
            }
            .navigationTitle("load.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("action.cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("action.load") {
                        loadFilm()
                    }
                    .disabled(selectedFormat == nil || selectedCamera.isEmpty || (selectedFormat?.isRollFormat == true && selectedRollId == nil))
                }
            }
        }
        .onAppear {
            if availableFormats.count == 1 {
                selectedFormat = availableFormats.first

                // Auto-select roll if only one group (or one roll total) available
                if let fmt = selectedFormat, fmt.isRollFormat,
                   let info = groupedFilm.formats.first(where: { $0.format == fmt }) {
                    let groups = rollGroupsForFormat(info)
                    if groups.count == 1 {
                        selectedRollId = groups.first?.rollIds.first
                    }
                }
            }

            autoSelectCamera(for: selectedFormat)
            sheetQuantity = 1
            shotAtISO = groupedFilm.filmSpeed
        }
        .onChange(of: selectedFormat) { _, newValue in
            sheetQuantity = 1
            autoSelectCamera(for: newValue)
        }
    }
    
    private var formatSelectionSection: some View {
        Section("load.selectFormat") {
            if availableFormats.isEmpty {
                Text("load.noFormatsAvailable")
                    .foregroundColor(.secondary)
            } else {
                ForEach(availableFormats, id: \.self) { format in
                    formatRow(format: format)
                }
            }
        }
    }
    
    private func formatRow(format: FilmStock.FilmFormat) -> some View {
        let formatInfo = groupedFilm.formats.first { $0.format == format }
        let quantity = formatInfo?.quantity ?? 0
        let quantityUnit = format.quantityUnit
        let isSelected = selectedFormat == format
        let displayName = formatInfo?.formatDisplayName ?? format.displayName
        
        return HStack {
            Text(displayName)
            Spacer()
            Text("\(quantity) \(quantityUnit)")
                .foregroundColor(.secondary)
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.accentColor)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedFormat = format
            // For roll formats with only one group, auto-select it
            if format.isRollFormat, let info = formatInfo {
                let groups = rollGroupsForFormat(info)
                if groups.count == 1 {
                    selectedRollId = groups.first?.rollIds.first
                } else {
                    selectedRollId = nil
                }
            }
        }
    }
    
    private var rollPickerSection: some View {
        Group {
            if let format = selectedFormat, format.isRollFormat,
               let formatInfo = groupedFilm.formats.first(where: { $0.format == format }) {
                let groups = rollGroupsForFormat(formatInfo)
                if groups.count > 1 {
                    Section("load.selectRoll") {
                        ForEach(groups) { group in
                            rollGroupPickerRow(group)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func rollGroupPickerRow(_ group: RollGroupItem) -> some View {
        let isSelected = group.rollIds.contains(selectedRollId ?? "")
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(
                        group.count == 1
                            ? String(format: NSLocalizedString("film.rollCount", comment: ""), group.count)
                            : String(format: NSLocalizedString("film.rollsCount", comment: ""), group.count)
                    )
                    .font(.body)

                    if let expiry = group.expireDate, !expiry.isEmpty {
                        Text("(\(FilmStock.formatExpireDate(expiry)))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("film.noExpiry")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    if let exp = group.exposures, exp > 0 {
                        Text("· \(exp)exp")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if group.isFrozen || group.isExpired {
                    HStack(spacing: 5) {
                        if group.isFrozen {
                            rollChip(NSLocalizedString("film.frozen", comment: ""), color: .blue)
                        }
                        if group.isExpired {
                            rollChip(NSLocalizedString("film.expired", comment: ""), color: .red)
                        }
                    }
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.accentColor)
                    .fontWeight(.semibold)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedRollId = group.rollIds.first
        }
    }

    @ViewBuilder
    private func rollChip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(color, lineWidth: 1))
    }

    private func rollsForFormat(_ formatInfo: GroupedFilm.FormatInfo) -> [FilmStock] {
        dataManager.filmStocks.filter { stock in
            formatInfo.rollIds.contains(stock.id) && stock.quantity > 0
        }
    }

    private func rollGroupsForFormat(_ formatInfo: GroupedFilm.FormatInfo) -> [RollGroupItem] {
        let rolls = rollsForFormat(formatInfo)
        var buckets: [String: RollGroupItem] = [:]
        for roll in rolls {
            let expiry = roll.expireDate?.first
            let key = "\(expiry ?? "")|\(roll.isFrozen)|\(roll.exposures ?? -99)"
            if var existing = buckets[key] {
                existing.rollIds.append(roll.id)
                buckets[key] = existing
            } else {
                buckets[key] = RollGroupItem(
                    format: roll.format,
                    customFormatName: roll.customFormatName,
                    expireDate: expiry,
                    isFrozen: roll.isFrozen,
                    exposures: roll.exposures,
                    comments: roll.comments,
                    rollIds: [roll.id]
                )
            }
        }
        return buckets.values.sorted { lhs, rhs in
            if let ld = lhs.expireDate, let rd = rhs.expireDate { return ld < rd }
            if lhs.expireDate != nil { return true }
            if rhs.expireDate != nil { return false }
            return !lhs.isFrozen && rhs.isFrozen
        }
    }
    
    private var cameraSelectionSection: some View {
        Section("load.selectCamera") {
            NavigationLink {
                CameraPickerView(selectedCamera: $selectedCamera, filmFormat: selectedFormat)
                    .environmentObject(dataManager)
            } label: {
                HStack {
                    Text("camera.name")
                    Spacer()
                    if selectedCamera.isEmpty {
                        Text("load.selectCamera")
                            .foregroundColor(.secondary)
                    } else {
                        Text(selectedCamera)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
    }
    
    private var isoSelectionSection: some View {
        Section {
            HStack {
                Text("load.shotAtISO")
                Spacer()
                TextField("ISO", value: $shotAtISO, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }
        } footer: {
            if shotAtISO != groupedFilm.filmSpeed {
                Text("load.shotAtISO.hint")
                    .foregroundColor(.orange)
            }
        }
        .onChange(of: shotAtISO) { oldValue, newValue in
            // Clamp value between 1 and 12800
            if newValue < 1 {
                shotAtISO = 1
            } else if newValue > 12800 {
                shotAtISO = 12800
            }
        }
    }
    
    private var quantitySelectionSection: some View {
        Group {
            if let format = selectedFormat, isSheetFormat(format) {
                Section("load.quantityToLoad") {
                    Stepper(String(format: NSLocalizedString("Sheets: %d", comment: ""), sheetQuantity), value: $sheetQuantity, in: 1...maxSheetQuantity)
                }
            }
        }
    }
    
    private func isSheetFormat(_ format: FilmStock.FilmFormat) -> Bool {
        format == .fourByFive || format == .fiveBySeven || format == .eightByTen
    }
    
    private var maxSheetQuantity: Int {
        guard let format = selectedFormat,
              let formatInfo = groupedFilm.formats.first(where: { $0.format == format }) else {
            return 1
        }
        return formatInfo.quantity
    }
    
    private var errorSection: some View {
        Group {
            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                }
            }
        }
    }
                
    
    /// Picks a camera automatically when there is an unambiguous best match for the film format.
    /// Only sets selectedCamera if it is currently empty or if exactly one camera matches the new format.
    private func autoSelectCamera(for format: FilmStock.FilmFormat?) {
        let cameras = availableCameras
        guard !cameras.isEmpty else { return }

        if let format {
            let matching = cameras.filter { $0.format == format.rawValue }
            if matching.count == 1 {
                selectedCamera = matching[0].name
                return
            }
            // Multiple matches: don't auto-select, let the user choose (they'll be grouped on top)
            if matching.count > 1 { return }
        }

        // No format set or no camera has a matching format: fall back to single-camera auto-select
        if cameras.count == 1 {
            selectedCamera = cameras[0].name
        }
    }

    private func loadFilm() {
        guard let format = selectedFormat,
              !selectedCamera.isEmpty else {
            return
        }
        
        guard let formatInfo = groupedFilm.formats.first(where: { $0.format == format }),
              formatInfo.quantity > 0 else {
            errorMessage = NSLocalizedString("load.error.noRolls", comment: "")
            return
        }
        
        // For roll formats: use the specific selected roll ID
        // For sheet formats: use the formatInfo.filmId and sheet quantity
        let filmStockId: String
        let quantityToLoad: Int
        
        if format.isRollFormat {
            guard let rollId = selectedRollId else {
                errorMessage = NSLocalizedString("load.error.noRolls", comment: "")
                return
            }
            filmStockId = rollId
            quantityToLoad = 1
        } else {
            filmStockId = formatInfo.filmId
            quantityToLoad = isSheetFormat(format) ? sheetQuantity : 1
        }
        
        let isoToPass = shotAtISO != groupedFilm.filmSpeed ? shotAtISO : nil
        if dataManager.loadFilm(filmStockId: filmStockId, format: format, cameraName: selectedCamera, quantity: quantityToLoad, shotAtISO: isoToPass) {
            dismiss()
            onLoadComplete?()
        } else {
            let unit = isSheetFormat(format) ? "sheets" : "rolls"
            errorMessage = String(format: NSLocalizedString("load.error.failed", comment: ""), quantityToLoad, unit)
        }
    }
}

struct CameraPickerView: View {
    @Binding var selectedCamera: String
    var filmFormat: FilmStock.FilmFormat? = nil
    @EnvironmentObject var dataManager: FilmStockDataManager
    @Environment(\.dismiss) var dismiss
    @State private var searchText: String = ""
    @State private var showingAddCamera = false
    @State private var showDeleteError = false
    @State private var showingCameraInfo = false

    var allCameras: [Camera] {
        dataManager.getAllCameras()
    }

    var hasNoCameras: Bool { allCameras.isEmpty }

    var searchTextTrimmed: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canAddFromSearch: Bool {
        !searchTextTrimmed.isEmpty &&
        !allCameras.contains(where: {
            $0.name.localizedCaseInsensitiveCompare(searchTextTrimmed) == .orderedSame
        })
    }

    /// Cameras whose stored format matches the film being loaded.
    private var matchingCameras: [Camera] {
        guard let filmFormat else { return [] }
        return allCameras.filter { $0.format == filmFormat.rawValue }
    }

    /// All remaining cameras (no format set, or a different format).
    private var otherCameras: [Camera] {
        let matchingNames = Set(matchingCameras.map { $0.name })
        return allCameras.filter { !matchingNames.contains($0.name) }
    }

    private var filteredCameras: [Camera] {
        guard !searchText.isEmpty else { return [] }
        return allCameras.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List {
            // Empty state
            if hasNoCameras && searchText.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "camera")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("cameras.empty")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button {
                            showingAddCamera = true
                        } label: {
                            Label("camera.addFirst", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }

            // Quick-add from search text (format can be set later in Manage Cameras)
            if canAddFromSearch {
                Section {
                    Button {
                        let newCamera = dataManager.addCamera(name: searchTextTrimmed)
                        selectedCamera = newCamera.name
                        dismiss()
                    } label: {
                        Label(
                            String(format: NSLocalizedString("action.addNew", comment: ""), searchTextTrimmed),
                            systemImage: "plus.circle"
                        )
                    }
                }
            }

            if !searchText.isEmpty {
                // Search results: flat list
                ForEach(filteredCameras, id: \.name) { camera in
                    cameraRow(camera)
                }
            } else if !matchingCameras.isEmpty {
                // Grouped: matching format cameras on top
                Section(header: Text("load.suggestedCameras")) {
                    ForEach(matchingCameras, id: \.name) { camera in
                        cameraRow(camera)
                    }
                }
                if !otherCameras.isEmpty {
                    Section(header: Text("load.otherCameras")) {
                        ForEach(otherCameras, id: \.name) { camera in
                            cameraRow(camera)
                        }
                    }
                }
            } else {
                // No format context or no matches: flat list
                ForEach(allCameras, id: \.name) { camera in
                    cameraRow(camera)
                }
            }
        }
        .searchable(text: $searchText, prompt: Text("camera.search"))
        .navigationTitle("load.selectCamera")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !hasNoCameras {
                    Button { showingCameraInfo = true } label: {
                        Image(systemName: "questionmark.circle")
                    }
                } else {
                    Button { showingAddCamera = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddCamera) {
            AddCameraSheet { newCamera in
                selectedCamera = newCamera.name
                dismiss()
            }
            .environmentObject(dataManager)
        }
        .alert("cameras.info.title", isPresented: $showingCameraInfo) {
            Button("action.ok", role: .cancel) { }
        } message: {
            Text("cameras.info.message")
        }
        .alert("camera.deleteError", isPresented: $showDeleteError) {
            Button("action.ok", role: .cancel) { }
        } message: {
            Text("camera.deleteErrorMessage")
        }
    }

    @ViewBuilder
    private func cameraRow(_ camera: Camera) -> some View {
        Button {
            selectedCamera = camera.name
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(camera.name)
                        .foregroundColor(.primary)
                    if !camera.formatDisplayName.isEmpty {
                        Text(camera.formatDisplayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                if selectedCamera == camera.name {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                if !dataManager.deleteCamera(camera) {
                    showDeleteError = true
                }
            } label: {
                Label("action.delete", systemImage: "trash")
            }
        }
    }
}

