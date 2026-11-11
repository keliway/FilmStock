//
//  FilmDetailView.swift
//  FilmStock
//

import SwiftUI

// MARK: - Roll Group Model

struct RollGroupItem: Identifiable, Hashable {
    let format: FilmStock.FilmFormat
    let customFormatName: String?
    let expireDate: String?       // single shared date for all rolls in this group
    let isFrozen: Bool
    var isFridge: Bool = false
    let exposures: Int?           // from first roll; applied to all on edit
    let comments: String?         // from first roll; applied to all on edit
    var rollIds: [String]         // individual MyFilm IDs in this group

    var count: Int { rollIds.count }

    /// Includes exposures and comments so distinct groups do not collapse into one row.
    var id: String { "\(format.rawValue)|\(expireDate ?? "")|\(isFrozen)|\(isFridge)|\(exposures ?? -99)|\(customFormatName ?? "")|\(comments ?? "")" }

    var isExpired: Bool {
        guard let ds = expireDate, let date = FilmStock.parseExpireDate(ds) else { return false }
        return date < Date()
    }

    var formatDisplayName: String {
        if format == .other, let name = customFormatName, !name.isEmpty { return name }
        return format.displayName
    }

    static func == (lhs: RollGroupItem, rhs: RollGroupItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Film Detail View

struct FilmDetailView: View {
    let groupedFilm: GroupedFilm
    @EnvironmentObject var dataManager: FilmStockDataManager
    @ObservedObject private var settingsManager = SettingsManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var showingEditMeta = false
    @State private var showingLoadFilm = false
    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteError = false
    @State private var deleteErrorMessage = ""
    @State private var showingAddRollsSheet = false
    @State private var groupToEdit: RollGroupItem?
    @State private var sheetLineToEdit: FilmStock?
    @State private var relatedFilms: [FilmStock] = []
    @State private var navImage: UIImage?

    private var currentGroupedFilm: GroupedFilm? {
        if let byId = dataManager.cachedGroupedFilms.first(where: { $0.id == groupedFilm.id }) {
            return byId
        }
        return dataManager.cachedGroupedFilms.first {
            $0.name == groupedFilm.name &&
            $0.manufacturer == groupedFilm.manufacturer &&
            $0.type == groupedFilm.type &&
            $0.filmSpeed == groupedFilm.filmSpeed
        }
    }

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

            // Roll groups by format (each format as a section)
            ForEach(rollGroupsByFormat, id: \.format) { entry in
                Section(entry.displayName) {
                    ForEach(entry.groups) { group in
                        rollGroupRow(group)
                    }
                }
            }

            // Add Rolls inline button — shown below roll sections
            Section {
                Button {
                    showingAddRollsSheet = true
                } label: {
                    Label("add.rolls", systemImage: "plus.circle")
                        .fontWeight(.medium)
                }
            }

            // Sheet formats (4x5, 5x7, 8x10)
            if !largeFormatFilms.isEmpty {
                Section("detail.formats") {
                    ForEach(largeFormatFilms) { film in
                        sheetInventoryRow(film)
                    }
                }
            }

            // Other non-roll formats (e.g. Custom / Other)
            if !otherFormatFilms.isEmpty {
                Section("detail.otherFormats") {
                    ForEach(otherFormatFilms) { film in
                        sheetInventoryRow(film)
                    }
                }
            }

            // Comments (aggregated from all rolls)
            let allComments = Array(Set(relatedFilms.compactMap { $0.comments }.filter { !$0.isEmpty })).sorted()
            if !allComments.isEmpty {
                Section("film.comments") {
                    ForEach(allComments, id: \.self) { comment in
                        Text(comment).foregroundColor(.secondary)
                    }
                }
            }

            // Actions
            Section {
                Button {
                    showingLoadFilm = true
                } label: {
                    HStack {
                        Spacer()
                        Label("action.load", systemImage: "camera")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
                .disabled(!hasAvailableFormats)

                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    HStack {
                        Spacer()
                        Label("action.delete", systemImage: "trash")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle(displayGroupedFilm.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    if let img = navImage {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 30, height: 30)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    Button("action.edit") {
                        showingEditMeta = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditMeta) {
            EditFilmView(groupedFilm: displayGroupedFilm)
        }
        .sheet(item: $groupToEdit) { group in
            RollGroupEditSheet(group: group, filmTemplate: displayGroupedFilm)
                .environmentObject(dataManager)
        }
        .sheet(item: $sheetLineToEdit) { line in
            SheetStockEditSheet(filmStock: line)
                .environmentObject(dataManager)
        }
        .sheet(isPresented: $showingAddRollsSheet) {
            RollBatchSheet { batch in
                let dateDigits = batch.expireDate.filter { $0.isNumber }
                let trimmedComments = batch.comments.trimmingCharacters(in: .whitespacesAndNewlines)
                let newFilm = FilmStock(
                    id: UUID().uuidString,
                    name: displayGroupedFilm.name,
                    manufacturer: displayGroupedFilm.manufacturer,
                    type: displayGroupedFilm.type,
                    filmSpeed: displayGroupedFilm.filmSpeed,
                    format: batch.format,
                    customFormatName: batch.customFormatName,
                    quantity: batch.quantity,
                    expireDate: dateDigits.isEmpty ? nil : [dateDigits],
                    comments: trimmedComments.isEmpty ? nil : trimmedComments,
                    isFrozen: batch.isFrozen,
                    isFridge: batch.isFrozen ? false : batch.isFridge,
                    exposures: batch.resolvedExposures,
                    createdAt: ISO8601DateFormatter().string(from: Date()),
                    updatedAt: nil
                )
                _ = dataManager.addFilmStock(newFilm, imageName: nil, imageSource: ImageSource.autoDetected.rawValue)
                loadRelatedFilms()
            }
        }
        .sheet(isPresented: $showingLoadFilm) {
            LoadFilmView(groupedFilm: displayGroupedFilm)
                .environmentObject(dataManager)
        }
        .confirmationDialog("delete.confirm.title", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("action.delete", role: .destructive) {
                let allRelatedFilms = dataManager.filmStocks.filter { film in
                    film.name == displayGroupedFilm.name &&
                    film.manufacturer == displayGroupedFilm.manufacturer &&
                    film.type == displayGroupedFilm.type &&
                    film.filmSpeed == displayGroupedFilm.filmSpeed
                }
                if let loaded = allRelatedFilms.first(where: { dataManager.isFilmLoaded($0) }) {
                    deleteErrorMessage = String(format: NSLocalizedString("error.cannotDeleteLoaded", comment: ""), loaded.name)
                    showingDeleteError = true
                } else {
                    dataManager.deleteFilmStocks(allRelatedFilms)
                    dismiss()
                }
            }
            Button("action.cancel", role: .cancel) { }
        } message: {
            Text(String(format: NSLocalizedString("delete.confirm.message", comment: ""), displayGroupedFilm.name))
        }
        .alert("error.cannotDelete.title", isPresented: $showingDeleteError) {
            Button("action.ok", role: .cancel) { }
        } message: {
            Text(deleteErrorMessage)
        }
        .onAppear {
            loadRelatedFilms()
            loadNavImage()
        }
        .onChange(of: dataManager.filmStocks) { _, _ in
            loadRelatedFilms()
            loadNavImage()
        }
    }

    // MARK: - Roll Group Row

    @ViewBuilder
    private func sheetInventoryRow(_ film: FilmStock) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(film.formatDisplayName)
                        .font(.body)
                    if let dates = film.expireDate, !dates.isEmpty {
                        Text(dates.map { FilmStock.formatExpireDate($0) }.joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("film.noExpiry")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    let showFridgeChip = !film.isFrozen && film.isFridge && settingsManager.enableFridge
                    if film.isFrozen || showFridgeChip {
                        HStack(spacing: 5) {
                            if film.isFrozen {
                                tagChip(NSLocalizedString("film.frozen", comment: ""), color: .blue)
                            } else if showFridgeChip {
                                tagChip(NSLocalizedString("film.fridge", comment: ""), color: .blue)
                            }
                        }
                    }
                    if let c = film.comments, !c.isEmpty {
                        Text(c)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                }
                Spacer()
                Button {
                    sheetLineToEdit = film
                } label: {
                    Image(systemName: "pencil.circle")
                        .foregroundColor(.accentColor)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            HStack {
                Spacer(minLength: 0)
                QuantityControlView(film: film)
                    .environmentObject(dataManager)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func rollGroupRow(_ group: RollGroupItem) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
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
                    }

                    if let exp = group.exposures, exp > 0 || exp == kBulkRollExposures {
                        Text("· \(exposureDisplayLabel(exp))exp")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                let showFridgeChip = !group.isFrozen && group.isFridge && settingsManager.enableFridge
                if group.isFrozen || showFridgeChip || group.isExpired {
                    HStack(spacing: 5) {
                        if group.isFrozen {
                            tagChip(NSLocalizedString("film.frozen", comment: ""), color: .blue)
                        } else if showFridgeChip {
                            tagChip(NSLocalizedString("film.fridge", comment: ""), color: .blue)
                        }
                        if group.isExpired {
                            tagChip(NSLocalizedString("film.expired", comment: ""), color: .red)
                        }
                    }
                }
            }

            Spacer()

            Button {
                groupToEdit = group
            } label: {
                Image(systemName: "pencil.circle")
                    .foregroundColor(.accentColor)
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func tagChip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(color, lineWidth: 1))
    }

    // MARK: - Helpers

    private func loadNavImage() {
        let film = displayGroupedFilm
        navImage = ImageStorage.shared.resolveFilmImage(
            imageSourceRawValue: film.imageSource,
            imageName: film.imageName,
            filmName: film.name,
            manufacturer: film.manufacturer
        )
    }

    // MARK: - Computed

    private var hasAvailableFormats: Bool {
        displayGroupedFilm.formats.contains { $0.quantity > 0 }
    }

    private static let sheetFormats: Set<FilmStock.FilmFormat> = [.fourByFive, .fiveBySeven, .eightByTen]

    private var largeFormatFilms: [FilmStock] {
        relatedFilms.filter {
            Self.sheetFormats.contains($0.format) && $0.quantity > 0
        }
    }

    private var otherFormatFilms: [FilmStock] {
        relatedFilms.filter {
            !$0.format.isRollFormat &&
            !Self.sheetFormats.contains($0.format) &&
            $0.quantity > 0
        }
    }

    private var rollGroupsByFormat: [(format: FilmStock.FilmFormat, displayName: String, groups: [RollGroupItem])] {
        let rollFilms = relatedFilms.filter { $0.format.isRollFormat && $0.quantity > 0 }

        // Build buckets keyed by format, expiry, frozen, fridge, exposures, customFormatName, comments (matches LoadFilmView.rollGroupsForFormat)
        var buckets: [String: RollGroupItem] = [:]
        for film in rollFilms {
            let expiry = film.expireDate?.first
            let expKey = film.exposures ?? -99
            let otherKey = film.customFormatName ?? ""
            let commentKey = film.comments ?? ""
            let key = "\(film.format.rawValue)|\(expiry ?? "")|\(film.isFrozen)|\(film.isFridge)|\(expKey)|\(otherKey)|\(commentKey)"
            if var existing = buckets[key] {
                existing.rollIds.append(film.id)
                buckets[key] = existing
            } else {
                buckets[key] = RollGroupItem(
                    format: film.format,
                    customFormatName: film.customFormatName,
                    expireDate: expiry,
                    isFrozen: film.isFrozen,
                    isFridge: film.isFridge,
                    exposures: film.exposures,
                    comments: film.comments,
                    rollIds: [film.id]
                )
            }
        }

        // Group by format
        var byFormat: [FilmStock.FilmFormat: [RollGroupItem]] = [:]
        for (_, group) in buckets {
            byFormat[group.format, default: []].append(group)
        }

        let formatOrder: [FilmStock.FilmFormat] = [.thirtyFive, .oneTwenty, .oneTen, .oneTwentySeven, .twoTwenty]
        return formatOrder.compactMap { format in
            guard let groups = byFormat[format], !groups.isEmpty else { return nil }
            let sorted = groups.sorted { lhs, rhs in
                if let ld = lhs.expireDate.flatMap(FilmStock.parseExpireDate),
                   let rd = rhs.expireDate.flatMap(FilmStock.parseExpireDate) {
                    if ld != rd { return ld < rd }
                } else if lhs.expireDate != nil { return true }
                else if rhs.expireDate != nil { return false }
                if lhs.isFrozen != rhs.isFrozen { return !lhs.isFrozen }
                if lhs.isFridge != rhs.isFridge { return !lhs.isFridge }
                let le = lhs.exposures ?? Int.max
                let re = rhs.exposures ?? Int.max
                if le != re { return le < re }
                return lhs.id < rhs.id
            }
            let displayName = groups.compactMap { $0.customFormatName }.first ?? format.displayName
            return (format, displayName, sorted)
        }
    }

    private func loadRelatedFilms() {
        relatedFilms = dataManager.filmStocks.filter { film in
            film.quantity > 0 &&
            film.name == displayGroupedFilm.name &&
            film.manufacturer == displayGroupedFilm.manufacturer &&
            film.type == displayGroupedFilm.type &&
            film.filmSpeed == displayGroupedFilm.filmSpeed
        }
    }
}

// MARK: - Roll Group Edit Sheet

struct RollGroupEditSheet: View {
    let group: RollGroupItem
    let filmTemplate: GroupedFilm

    @EnvironmentObject var dataManager: FilmStockDataManager
    @ObservedObject private var settingsManager = SettingsManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var selectedFormatString: String
    @State private var format: FilmStock.FilmFormat
    @State private var customFormatName: String?
    @State private var quantity: Int
    @State private var expireDate: String
    @State private var isFrozen: Bool
    @State private var isFridge: Bool
    @State private var exposures: Int?
    @State private var customExposures: String
    @State private var comments: String
    @State private var expireDateError: String?
    @State private var deleteError: String?
    @State private var showingDeleteError = false

    init(group: RollGroupItem, filmTemplate: GroupedFilm) {
        self.group = group
        self.filmTemplate = filmTemplate
        let fmtDisplay = group.formatDisplayName
        _selectedFormatString = State(initialValue: fmtDisplay)
        _format          = State(initialValue: group.format)
        _customFormatName = State(initialValue: group.customFormatName)
        _quantity        = State(initialValue: group.count)
        let formattedExpiry = group.expireDate.map { FilmStock.formatExpireDate($0) } ?? ""
        _expireDate      = State(initialValue: formattedExpiry)
        _isFrozen        = State(initialValue: group.isFrozen)
        _isFridge        = State(initialValue: group.isFrozen ? false : group.isFridge)
        _comments        = State(initialValue: group.comments ?? "")
        // Map stored exposure to picker selection; use -1 tag for custom values
        let opts = group.format.exposureOptions
        if let exp = group.exposures {
            if opts.contains(exp) {
                _exposures       = State(initialValue: exp)
                _customExposures = State(initialValue: "")
            } else {
                _exposures       = State(initialValue: -1)
                _customExposures = State(initialValue: "\(exp)")
            }
        } else {
            _exposures       = State(initialValue: nil)
            _customExposures = State(initialValue: "")
        }
    }

    private var storageSelection: Binding<Int> {
        Binding(
            get: {
                if isFrozen { return 2 }
                if isFridge { return 1 }
                return 0
            },
            set: { newValue in
                switch newValue {
                case 1:
                    isFrozen = false
                    isFridge = true
                case 2:
                    isFrozen = true
                    isFridge = false
                default:
                    isFrozen = false
                    isFridge = false
                }
            }
        )
    }

    private var allEnabledFormats: [String] {
        var formats: [String] = []
        for builtIn in FilmStock.FilmFormat.allCases {
            if settingsManager.isFormatEnabled(builtIn.displayName) {
                formats.append(builtIn.displayName)
            }
        }
        for custom in settingsManager.customFormats {
            if settingsManager.isFormatEnabled(custom) {
                formats.append(custom)
            }
        }
        if !formats.contains(selectedFormatString) {
            formats.append(selectedFormatString)
        }
        return formats
    }

    private func formatFromString(_ str: String) -> FilmStock.FilmFormat {
        FilmStock.FilmFormat.allCases.first { $0.displayName == str } ?? .other
    }

    var body: some View {
        NavigationStack {
            Form {
                // Format
                Section {
                    Picker("film.format", selection: $selectedFormatString) {
                        ForEach(allEnabledFormats, id: \.self) { f in
                            Text(f).tag(f)
                        }
                    }
                    .onChange(of: selectedFormatString) { _, newValue in
                        let newFormat = formatFromString(newValue)
                        format = newFormat
                        customFormatName = newFormat == .other ? newValue : nil
                        exposures = newFormat.defaultExposures
                        customExposures = ""
                    }
                }

                // Quantity
                Section {
                    Stepper(
                        quantity == 1
                            ? String(format: NSLocalizedString("film.rollCount", comment: ""), quantity)
                            : String(format: NSLocalizedString("film.rollsCount", comment: ""), quantity),
                        value: $quantity,
                        in: 1...999
                    )
                }

                // Expiry Date
                Section("film.expiryDate") {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("film.expiryDateFormat", text: $expireDate)
                            .keyboardType(.numberPad)
                            .onChange(of: expireDate) { _, newValue in
                                let digits = newValue.filter { $0.isNumber }
                                let limited = String(digits.prefix(6))
                                if limited.count == 6 {
                                    expireDate = "\(limited.prefix(2))/\(limited.suffix(4))"
                                } else {
                                    expireDate = limited
                                }
                                expireDateError = nil
                            }
                        if let error = expireDateError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }

                // Frozen & Fridge
                if settingsManager.enableFridge {
                    Section("film.storage") {
                        Picker("film.storage", selection: storageSelection) {
                            Text("group.none").tag(0)
                            Text("loaded.detail.fridge").tag(1)
                            Text("loaded.detail.frozen").tag(2)
                        }
                        .pickerStyle(.segmented)
                    }
                } else {
                    Section {
                        Toggle("film.isFrozen", isOn: $isFrozen)
                            .onChange(of: isFrozen) { _, newValue in
                                if newValue { isFridge = false }
                            }
                    }
                }

                // Exposures (roll formats only, options vary by format)
                if format.isRollFormat && !format.exposureOptions.isEmpty {
                    Section("film.exposures") {
                        Picker("film.exposures", selection: $exposures) {
                            Text(LocalizedStringKey("film.exposures.unspecified")).tag(nil as Int?)
                            ForEach(format.exposureOptions, id: \.self) { opt in
                                Text(exposureDisplayLabel(opt)).tag(opt as Int?)
                            }
                            Text(LocalizedStringKey("film.exposures.custom")).tag(-1 as Int?)
                        }
                        if exposures == -1 {
                            TextField(
                                LocalizedStringKey("film.exposures.customCount"),
                                text: $customExposures
                            )
                            .keyboardType(.numberPad)
                        }
                    }
                }

                // Comments
                Section("film.comments") {
                    TextField("film.comments.placeholder", text: $comments, axis: .vertical)
                        .lineLimit(3...6)
                }

                // Delete this group
                Section {
                    Button(role: .destructive) {
                        deleteGroup()
                    } label: {
                        HStack {
                            Spacer()
                            Label("edit.rolls.delete", systemImage: "trash")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle(
                String(format: NSLocalizedString("edit.rolls.title", comment: ""), group.formatDisplayName)
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("action.save") {
                        if validate() {
                            saveChanges()
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("error.cannotDelete.title", isPresented: $showingDeleteError) {
                Button("action.ok", role: .cancel) { }
            } message: {
                Text(deleteError ?? "")
            }
        }
    }

    private func validate() -> Bool {
        expireDateError = nil
        guard !expireDate.isEmpty else { return true }
        let digits = expireDate.filter { $0.isNumber }
        if digits.count == 4 {
            guard let year = Int(digits), year >= 1950, year <= 2100 else {
                expireDateError = NSLocalizedString("error.invalidYear", comment: "")
                return false
            }
        } else if digits.count == 6 {
            let month = Int(String(digits.prefix(2))) ?? 0
            let year  = Int(String(digits.suffix(4))) ?? 0
            guard month >= 1, month <= 12 else {
                expireDateError = NSLocalizedString("error.invalidMonth", comment: "")
                return false
            }
            guard year >= 1950, year <= 2100 else {
                expireDateError = NSLocalizedString("error.invalidYear", comment: "")
                return false
            }
        } else {
            expireDateError = NSLocalizedString("error.invalidDateFormat", comment: "")
            return false
        }
        return true
    }

    private var resolvedExposures: Int? {
        if exposures == kBulkRollExposures { return kBulkRollExposures }
        if exposures == -1, let n = Int(customExposures), n > 0 { return n }
        if let e = exposures, e > 0 { return e }
        return nil
    }

    private func saveChanges() {
        let dateDigits = expireDate.filter { $0.isNumber }
        let newExpireDates: [String]? = dateDigits.isEmpty ? nil : [dateDigits]
        let newComments: String? = comments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? nil : comments.trimmingCharacters(in: .whitespacesAndNewlines)

        let existingRolls = dataManager.filmStocks.filter { group.rollIds.contains($0.id) }
        let currentCount = existingRolls.count
        let delta = quantity - currentCount

        // Determine the final customFormatName based on current format picker selection
        let savedCustomFormatName: String? = format == .other ? selectedFormatString : nil

        // Update all rolls that remain (up to min(quantity, currentCount))
        let toKeep = delta < 0 ? Array(existingRolls.prefix(quantity)) : existingRolls
        for roll in toKeep {
            let updated = FilmStock(
                id: roll.id,
                name: roll.name,
                manufacturer: roll.manufacturer,
                type: roll.type,
                filmSpeed: roll.filmSpeed,
                format: format,
                customFormatName: savedCustomFormatName,
                quantity: 1,
                expireDate: newExpireDates,
                comments: newComments,
                isFrozen: isFrozen,
                isFridge: isFrozen ? false : isFridge,
                exposures: format.isRollFormat ? resolvedExposures : nil,
                createdAt: roll.createdAt,
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )
            dataManager.updateFilmStock(updated, imageName: nil, imageSource: nil)
        }

        if delta > 0 {
            // Add extra rolls using addFilmStock (creates individual MyFilm rows)
            let newFilm = FilmStock(
                id: UUID().uuidString,
                name: filmTemplate.name,
                manufacturer: filmTemplate.manufacturer,
                type: filmTemplate.type,
                filmSpeed: filmTemplate.filmSpeed,
                format: format,
                customFormatName: savedCustomFormatName,
                quantity: delta,
                expireDate: newExpireDates,
                comments: newComments,
                isFrozen: isFrozen,
                isFridge: isFrozen ? false : isFridge,
                exposures: format.isRollFormat ? resolvedExposures : nil,
                createdAt: ISO8601DateFormatter().string(from: Date()),
                updatedAt: nil
            )
            _ = dataManager.addFilmStock(newFilm, imageName: nil, imageSource: ImageSource.autoDetected.rawValue)
        } else if delta < 0 {
            // Remove surplus rolls (unloaded ones first)
            let unloaded = existingRolls.filter { !dataManager.isFilmLoaded($0) }
            let toRemove = Array(unloaded.suffix(-delta))
            dataManager.deleteFilmStocks(toRemove)
        }

        dataManager.loadFilmStocks()
    }

    private func deleteGroup() {
        let existingRolls = dataManager.filmStocks.filter { group.rollIds.contains($0.id) }
        if let loaded = existingRolls.first(where: { dataManager.isFilmLoaded($0) }) {
            deleteError = String(format: NSLocalizedString("error.cannotDeleteLoaded", comment: ""), loaded.name)
            showingDeleteError = true
            return
        }
        dataManager.deleteFilmStocks(existingRolls)
        dataManager.loadFilmStocks()
        dismiss()
    }
}

// MARK: - Sheet / non-roll line edit (expiry, frozen, fridge, comments)

private struct SheetStockEditSheet: View {
    let filmStock: FilmStock
    @EnvironmentObject var dataManager: FilmStockDataManager
    @ObservedObject private var settingsManager = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var expireDate: String
    @State private var isFrozen: Bool
    @State private var isFridge: Bool
    @State private var comments: String
    @State private var expireDateError: String?

    init(filmStock: FilmStock) {
        self.filmStock = filmStock
        let raw = filmStock.expireDate?.first ?? ""
        let formatted = raw.isEmpty ? "" : FilmStock.formatExpireDate(raw)
        _expireDate = State(initialValue: formatted)
        _isFrozen = State(initialValue: filmStock.isFrozen)
        _isFridge = State(initialValue: filmStock.isFrozen ? false : filmStock.isFridge)
        _comments = State(initialValue: filmStock.comments ?? "")
    }

    private var storageSelection: Binding<Int> {
        Binding(
            get: {
                if isFrozen { return 2 }
                if isFridge { return 1 }
                return 0
            },
            set: { newValue in
                switch newValue {
                case 1:
                    isFrozen = false
                    isFridge = true
                case 2:
                    isFrozen = true
                    isFridge = false
                default:
                    isFrozen = false
                    isFridge = false
                }
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("film.expiryDate") {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("film.expiryDateFormat", text: $expireDate)
                            .keyboardType(.numberPad)
                            .onChange(of: expireDate) { _, newValue in
                                let digits = newValue.filter { $0.isNumber }
                                let limited = String(digits.prefix(6))
                                if limited.count == 6 {
                                    expireDate = "\(limited.prefix(2))/\(limited.suffix(4))"
                                } else {
                                    expireDate = limited
                                }
                                expireDateError = nil
                            }
                        if let error = expireDateError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }

                if settingsManager.enableFridge {
                    Section("film.storage") {
                        Picker("film.storage", selection: storageSelection) {
                            Text("group.none").tag(0)
                            Text("loaded.detail.fridge").tag(1)
                            Text("loaded.detail.frozen").tag(2)
                        }
                        .pickerStyle(.segmented)
                    }
                } else {
                    Section {
                        Toggle("film.isFrozen", isOn: $isFrozen)
                            .onChange(of: isFrozen) { _, newValue in
                                if newValue { isFridge = false }
                            }
                    }
                }

                Section("film.comments") {
                    TextField("film.comments.placeholder", text: $comments, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(
                String(format: NSLocalizedString("edit.rolls.title", comment: ""), filmStock.formatDisplayName)
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("action.save") {
                        if validate() {
                            save()
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func validate() -> Bool {
        expireDateError = nil
        guard !expireDate.isEmpty else { return true }
        let digits = expireDate.filter { $0.isNumber }
        if digits.count == 4 {
            guard let year = Int(digits), year >= 1950, year <= 2100 else {
                expireDateError = NSLocalizedString("error.invalidYear", comment: "")
                return false
            }
        } else if digits.count == 6 {
            let month = Int(String(digits.prefix(2))) ?? 0
            let year  = Int(String(digits.suffix(4))) ?? 0
            guard month >= 1, month <= 12 else {
                expireDateError = NSLocalizedString("error.invalidMonth", comment: "")
                return false
            }
            guard year >= 1950, year <= 2100 else {
                expireDateError = NSLocalizedString("error.invalidYear", comment: "")
                return false
            }
        } else {
            expireDateError = NSLocalizedString("error.invalidDateFormat", comment: "")
            return false
        }
        return true
    }

    private func save() {
        let current = dataManager.filmStocks.first { $0.id == filmStock.id } ?? filmStock
        let dateDigits = expireDate.filter { $0.isNumber }
        let newExpireDates: [String]? = dateDigits.isEmpty ? nil : [dateDigits]
        let trimmed = comments.trimmingCharacters(in: .whitespacesAndNewlines)
        let newComments: String? = trimmed.isEmpty ? nil : trimmed

        let updated = FilmStock(
            id: current.id,
            name: current.name,
            manufacturer: current.manufacturer,
            type: current.type,
            filmSpeed: current.filmSpeed,
            format: current.format,
            customFormatName: current.customFormatName,
            quantity: current.quantity,
            expireDate: newExpireDates,
            comments: newComments,
            isFrozen: isFrozen,
            isFridge: isFrozen ? false : isFridge,
            exposures: current.exposures,
            createdAt: current.createdAt,
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
        dataManager.updateFilmStock(updated, imageName: nil, imageSource: nil)
        dataManager.loadFilmStocks()
    }
}

// MARK: - Supporting Views

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

struct QuantityControlView: View {
    let film: FilmStock
    @EnvironmentObject var dataManager: FilmStockDataManager
    @State private var currentQuantity: Int = 0

    var body: some View {
        HStack(spacing: 8) {
            Button {
                updateQuantity(by: -1)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(currentQuantity > 0 ? .red : .gray)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .disabled(currentQuantity <= 0)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(currentQuantity)")
                    .font(.headline)
                    .frame(minWidth: 30)
                Text(film.format.quantityUnit)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Button {
                updateQuantity(by: 1)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.green)
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .onAppear {
            loadCurrentQuantity()
        }
        .onChange(of: dataManager.filmStocks) { _, _ in
            loadCurrentQuantity()
        }
    }

    private func loadCurrentQuantity() {
        if let updated = dataManager.filmStocks.first(where: { $0.id == film.id }) {
            currentQuantity = updated.quantity
        } else {
            currentQuantity = film.quantity
        }
    }

    private func updateQuantity(by delta: Int) {
        let newQuantity = max(0, currentQuantity + delta)
        guard let latest = dataManager.filmStocks.first(where: { $0.id == film.id }) else { return }

        if latest.format.isRollFormat {
            let groupFilms = dataManager.filmStocks.filter { f in
                f.name == latest.name &&
                f.manufacturer == latest.manufacturer &&
                f.type == latest.type &&
                f.filmSpeed == latest.filmSpeed &&
                f.format == latest.format &&
                f.customFormatName == latest.customFormatName
            }

            if delta > 0 {
                let newRoll = FilmStock(
                    id: UUID().uuidString,
                    name: latest.name,
                    manufacturer: latest.manufacturer,
                    type: latest.type,
                    filmSpeed: latest.filmSpeed,
                    format: latest.format,
                    customFormatName: latest.customFormatName,
                    quantity: 1,
                    expireDate: latest.expireDate,
                    comments: latest.comments,
                    isFrozen: latest.isFrozen,
                    isFridge: latest.isFridge,
                    exposures: latest.exposures,
                    createdAt: ISO8601DateFormatter().string(from: Date()),
                    updatedAt: nil
                )
                _ = dataManager.addFilmStock(newRoll, imageName: nil, imageSource: ImageSource.autoDetected.rawValue)
            } else if delta < 0, !groupFilms.isEmpty {
                let unloaded = groupFilms.filter { !dataManager.isFilmLoaded($0) }
                if let toDelete = unloaded.first {
                    dataManager.deleteFilmStock(toDelete)
                }
            }
            currentQuantity = max(0, groupFilms.count + delta)
        } else {
            let updated = FilmStock(
                id: latest.id,
                name: latest.name,
                manufacturer: latest.manufacturer,
                type: latest.type,
                filmSpeed: latest.filmSpeed,
                format: latest.format,
                customFormatName: latest.customFormatName,
                quantity: newQuantity,
                expireDate: latest.expireDate,
                comments: latest.comments,
                isFrozen: latest.isFrozen,
                isFridge: latest.isFridge,
                exposures: latest.exposures,
                createdAt: latest.createdAt,
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )
            dataManager.updateFilmStock(updated, imageName: nil, imageSource: nil)
            currentQuantity = newQuantity
        }
    }
}
