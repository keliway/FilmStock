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

    /// Buckets individual roll entries by identical metadata and sorts them consistently
    /// (earliest expiry first, rolls with expiry before rolls without, room-temp before fridge/frozen, fewer exposures first).
    static func grouped(from rolls: [FilmStock]) -> [RollGroupItem] {
        var buckets: [String: RollGroupItem] = [:]
        for roll in rolls {
            let expiry = roll.expireDate?.first
            let key = "\(roll.format.rawValue)|\(expiry ?? "")|\(roll.isFrozen)|\(roll.isFridge)|\(roll.exposures ?? -99)|\(roll.customFormatName ?? "")|\(roll.comments ?? "")"
            if var existing = buckets[key] {
                existing.rollIds.append(roll.id)
                buckets[key] = existing
            } else {
                buckets[key] = RollGroupItem(
                    format: roll.format,
                    customFormatName: roll.customFormatName,
                    expireDate: expiry,
                    isFrozen: roll.isFrozen,
                    isFridge: roll.isFridge,
                    exposures: roll.exposures,
                    comments: roll.comments,
                    rollIds: [roll.id]
                )
            }
        }
        return buckets.values.sorted { lhs, rhs in
            if let ld = lhs.expireDate.flatMap({ FilmStock.parseExpireDate($0) }),
               let rd = rhs.expireDate.flatMap({ FilmStock.parseExpireDate($0) }) {
                if ld != rd { return ld < rd }
            } else if lhs.expireDate != nil {
                return true
            } else if rhs.expireDate != nil {
                return false
            }
            if lhs.isFrozen != rhs.isFrozen { return !lhs.isFrozen }
            if lhs.isFridge != rhs.isFridge { return !lhs.isFridge }
            let le = lhs.exposures ?? Int.max
            let re = rhs.exposures ?? Int.max
            if le != re { return le < re }
            return lhs.id < rhs.id
        }
    }
}

// MARK: - Film Detail View

struct FilmDetailView: View {
    let groupedFilm: GroupedFilm
    @EnvironmentObject var dataManager: FilmStockDataManager
    @ObservedObject private var settingsManager = SettingsManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var relatedFilms: [FilmStock] = []
    @State private var showingEditSheet = false
    @State private var showingLoadSheet = false
    @State private var shouldDismissAfterLoad = false
    @State private var groupToEdit: RollGroupItem?
    @State private var showingAddRollsSheet = false
    @State private var sheetLineToEdit: FilmStock?
    @State private var navImage: UIImage? = nil

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
                        .foregroundColor(.accentColor)
                }
            }

            // 4x5 / 5x7 / 8x10 sheet formats (per-line expiry, frozen, edit like rolls)
            let largeFormats = largeFormatFilms
            if !largeFormats.isEmpty {
                Section("detail.sheets") {
                    ForEach(largeFormats) { film in
                        nonRollInventoryRow(film)
                    }
                }
            }

            // Other / custom non-roll formats
            let otherFormats = otherFormatFilms
            if !otherFormats.isEmpty {
                Section("detail.other") {
                    ForEach(otherFormats) { film in
                        nonRollInventoryRow(film)
                    }
                }
            }

            // Comments (roll / sheet lines that still use a single shared comments section on the film)
            if let comment = relatedFilms.compactMap({ $0.comments }).first(where: { !$0.isEmpty }) {
                Section("film.comments") {
                    Text(comment).foregroundColor(.primary)
                }
            }
        }
        .navigationTitle("\(displayGroupedFilm.manufacturer) \(displayGroupedFilm.name)")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if let img = navImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingEditSheet = true
                    } label: {
                        Label("film.editFilm", systemImage: "pencil")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityIdentifier("filmDetail.moreMenu")
            }
        }
        .safeAreaInset(edge: .bottom) {
            if hasAvailableFormats {
                Button {
                    showingLoadSheet = true
                } label: {
                    Text("load.title")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .onAppear {
            loadRelatedFilms()
            loadNavImage()
        }
        .onChange(of: dataManager.filmStocks) { _, _ in loadRelatedFilms() }
        .sheet(isPresented: $showingEditSheet) {
            EditFilmView(groupedFilm: displayGroupedFilm)
                .environmentObject(dataManager)
        }
        .onChange(of: showingEditSheet) { _, newValue in
            if !newValue {
                loadRelatedFilms()
                loadNavImage()
            }
        }
        .sheet(isPresented: $showingLoadSheet) {
            LoadFilmView(groupedFilm: displayGroupedFilm, onLoadComplete: {
                shouldDismissAfterLoad = true
            })
            .environmentObject(dataManager)
        }
        .onChange(of: shouldDismissAfterLoad) { _, newValue in
            if newValue { dismiss() }
        }
        .sheet(item: $groupToEdit) { group in
            RollGroupEditSheet(group: group)
                .environmentObject(dataManager)
        }
        .sheet(item: $sheetLineToEdit) { line in
            SheetGroupEditSheet(film: line)
                .environmentObject(dataManager)
        }
        .sheet(isPresented: $showingAddRollsSheet) {
            RollBatchSheet { batch in
                let dateDigits = batch.expireDate.filter { $0.isNumber }
                let trimmedComments = batch.comments.trimmingCharacters(in: .whitespacesAndNewlines)
                let film = FilmStock(
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
                _ = dataManager.addFilmStock(film)
            }
            .environmentObject(dataManager)
        }
    }

    // MARK: - Row Builder

    @ViewBuilder
    private func nonRollInventoryRow(_ film: FilmStock) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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
                .accessibilityIdentifier("filmDetail.editSheetButton")
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
                        Text("· \(exposureShortLabel(exp))")
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
            .accessibilityIdentifier("filmDetail.editRollGroupButton")
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

    private var largeFormatFilms: [FilmStock] {
        relatedFilms.filter {
            $0.format.isSheetFormat && $0.quantity > 0
        }
    }

    private var otherFormatFilms: [FilmStock] {
        relatedFilms.filter {
            !$0.format.isRollFormat &&
            !$0.format.isSheetFormat &&
            $0.quantity > 0
        }
    }

    private var rollGroupsByFormat: [(format: FilmStock.FilmFormat, displayName: String, groups: [RollGroupItem])] {
        let rollFilms = relatedFilms.filter { $0.format.isRollFormat && $0.quantity > 0 }
        let sortedGroups = RollGroupItem.grouped(from: rollFilms)

        var byFormat: [FilmStock.FilmFormat: [RollGroupItem]] = [:]
        for group in sortedGroups {
            byFormat[group.format, default: []].append(group)
        }

        let formatOrder: [FilmStock.FilmFormat] = [.thirtyFive, .oneTwenty, .oneTen, .oneTwentySeven, .twoTwenty]
        return formatOrder.compactMap { format in
            guard let groups = byFormat[format], !groups.isEmpty else { return nil }
            let displayName = groups.compactMap { $0.customFormatName }.first ?? format.displayName
            return (format, displayName, groups)
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
    @EnvironmentObject var dataManager: FilmStockDataManager
    @Environment(\.dismiss) var dismiss

    @State private var count: Int
    @State private var expireDate: String
    @State private var isFrozen: Bool
    @State private var isFridge: Bool
    @State private var exposures: Int?
    @State private var customExposures: String
    @State private var comments: String
    @State private var expireDateError: String?

    init(group: RollGroupItem) {
        self.group = group
        _count       = State(initialValue: group.count)
        let normalizedExpiry: String = {
            guard let raw = group.expireDate, !raw.isEmpty else { return "" }
            return FilmStock.formatExpireDate(raw)
        }()
        _expireDate  = State(initialValue: normalizedExpiry)
        _isFrozen    = State(initialValue: group.isFrozen)
        _isFridge    = State(initialValue: group.isFrozen ? false : group.isFridge)
        _comments    = State(initialValue: group.comments ?? "")
        // Map exposures to picker tags: valid option → direct, unknown → -1 (custom), nil → nil (unspecified)
        if let exp = group.exposures {
            if group.format.exposureOptions.contains(exp) {
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

    var body: some View {
        NavigationStack {
            Form {
                // Count
                Section {
                    Stepper(
                        FilmStock.localizedQuantityLabel(quantity: count, format: group.format),
                        value: $count,
                        in: 0...999
                    )
                }

                // Expiry date
                Section("film.expiryDate") {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("film.expiryDateFormat", text: $expireDate)
                            .keyboardType(.numberPad)
                            .onChange(of: expireDate) { _, newValue in
                                expireDate = FilmStock.formatExpiryInput(newValue)
                                expireDateError = nil
                            }
                        if let error = expireDateError {
                            Text(error).font(.caption).foregroundColor(.red)
                        }
                    }
                }

                // Frozen & Fridge
                FilmStorageSection(isFrozen: $isFrozen, isFridge: $isFridge)

                // Exposures (options vary by format)
                if !group.format.exposureOptions.isEmpty {
                    Section("film.exposures") {
                        Picker("film.exposures", selection: $exposures) {
                            Text(LocalizedStringKey("film.exposures.unspecified")).tag(nil as Int?)
                            ForEach(group.format.exposureOptions, id: \.self) { opt in
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
            }
            .navigationTitle(
                String(
                    format: NSLocalizedString("edit.rolls.title", comment: ""),
                    group.formatDisplayName
                )
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("action.save") {
                        if validate() { save() }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Validation

    private func validate() -> Bool {
        expireDateError = FilmStock.validateExpiryInput(expireDate)
        return expireDateError == nil
    }

    // MARK: - Save

    private func save() {
        let cleanDate: String? = expireDate.isEmpty ? nil : expireDate.filter { $0.isNumber }
        let resolvedExposures: Int? = {
            if exposures == kBulkRollExposures { return kBulkRollExposures }
            if exposures == -1, let n = Int(customExposures), n > 0 { return n }
            if let e = exposures, e > 0 { return e }
            return nil
        }()

        let delta = count - group.count
        let effectiveFridge = isFrozen ? false : isFridge

        let cleanComments: String? = comments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? nil : comments.trimmingCharacters(in: .whitespacesAndNewlines)

        if count == 0 {
            dataManager.deleteRollsById(group.rollIds)
        } else if delta > 0 {
            dataManager.updateRolls(
                ids: group.rollIds,
                expireDate: cleanDate,
                isFrozen: isFrozen,
                isFridge: effectiveFridge,
                exposures: resolvedExposures,
                comments: cleanComments
            )
            _ = dataManager.addRolls(
                count: delta,
                matchingFilmStockId: group.rollIds.first!,
                expireDate: cleanDate,
                isFrozen: isFrozen,
                isFridge: effectiveFridge,
                exposures: resolvedExposures,
                comments: cleanComments
            )
        } else if delta < 0 {
            let toRemove = Array(group.rollIds.suffix(-delta))
            let toKeep   = Array(group.rollIds.prefix(count))
            dataManager.deleteRollsById(toRemove)
            dataManager.updateRolls(
                ids: toKeep,
                expireDate: cleanDate,
                isFrozen: isFrozen,
                isFridge: effectiveFridge,
                exposures: resolvedExposures,
                comments: cleanComments
            )
        } else {
            dataManager.updateRolls(
                ids: group.rollIds,
                expireDate: cleanDate,
                isFrozen: isFrozen,
                isFridge: effectiveFridge,
                exposures: resolvedExposures,
                comments: cleanComments
            )
        }

        dismiss()
    }
}

// MARK: - Sheet / other non-roll inventory edit

private struct MutableExpiryRow: Identifiable {
    let id: UUID
    var text: String
    init(id: UUID = UUID(), text: String) {
        self.id = id
        self.text = text
    }
}

/// Edit quantity, frozen, fridge, multiple expiry rows, and comments for one `MyFilm` line (sheets & other non-roll).
struct SheetGroupEditSheet: View {
    let film: FilmStock
    @EnvironmentObject var dataManager: FilmStockDataManager
    @Environment(\.dismiss) var dismiss

    @State private var quantity: Int
    @State private var isFrozen: Bool
    @State private var isFridge: Bool
    @State private var comments: String
    @State private var expiryRows: [MutableExpiryRow]
    @State private var rowErrors: [UUID: String] = [:]

    init(film: FilmStock) {
        self.film = film
        _quantity = State(initialValue: film.quantity)
        _isFrozen = State(initialValue: film.isFrozen)
        _isFridge = State(initialValue: film.isFrozen ? false : film.isFridge)
        _comments = State(initialValue: film.comments ?? "")
        let initialDates = film.expireDate ?? []
        if initialDates.isEmpty {
            _expiryRows = State(initialValue: [MutableExpiryRow(text: "")])
        } else {
            _expiryRows = State(initialValue: initialDates.map { MutableExpiryRow(text: FilmStock.formatExpireDate($0)) })
        }
    }

    private func expiryTextBinding(for rowId: UUID) -> Binding<String> {
        Binding(
            get: { expiryRows.first(where: { $0.id == rowId })?.text ?? "" },
            set: { newValue in
                guard let idx = expiryRows.firstIndex(where: { $0.id == rowId }) else { return }
                let formatted = FilmStock.formatExpiryInput(newValue)
                if expiryRows[idx].text != formatted {
                    expiryRows[idx].text = formatted
                }
                rowErrors[rowId] = nil
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(
                        FilmStock.localizedQuantityLabel(quantity: quantity, format: film.format),
                        value: $quantity,
                        in: 0...999
                    )
                }

                Section("film.expiryDate") {
                    ForEach(expiryRows) { row in
                        let rowId = row.id
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("film.expiryDateFormat", text: expiryTextBinding(for: rowId))
                                .keyboardType(.numberPad)
                            if let err = rowErrors[rowId] {
                                Text(err).font(.caption).foregroundColor(.red)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if expiryRows.count > 1 {
                                Button(role: .destructive) {
                                    expiryRows.removeAll { $0.id == rowId }
                                    rowErrors[rowId] = nil
                                } label: {
                                    Label("action.delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    Button {
                        expiryRows.append(MutableExpiryRow(text: ""))
                    } label: {
                        Label("film.expiryDate.addRow", systemImage: "plus.circle")
                    }
                }

                FilmStorageSection(isFrozen: $isFrozen, isFridge: $isFridge)

                Section("film.comments") {
                    TextField("film.comments.placeholder", text: $comments, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("edit.inventoryLine.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("action.save") {
                        if validateExpiryRows() { save() }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func validateExpiryRows() -> Bool {
        rowErrors = [:]
        for row in expiryRows {
            if let error = FilmStock.validateExpiryInput(row.text) {
                rowErrors[row.id] = error
            }
        }
        return rowErrors.isEmpty
    }

    private func save() {
        let rawDates = expiryRows
            .map { $0.text.filter { $0.isNumber } }
            .filter { !$0.isEmpty }

        if quantity == 0 {
            dataManager.deleteRollsById([film.id])
        } else {
            var updated = film
            updated.quantity = quantity
            updated.expireDate = rawDates.isEmpty ? nil : rawDates
            updated.isFrozen = isFrozen
            updated.isFridge = isFrozen ? false : isFridge
            let trimmed = comments.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.comments = trimmed.isEmpty ? nil : trimmed
            dataManager.updateFilmStock(updated)
        }
        dismiss()
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
    @State private var quantity: Int

    init(film: FilmStock) {
        self.film = film
        _quantity = State(initialValue: film.quantity)
    }

    var body: some View {
        if film.format.isRollFormat {
            Text(quantityText).foregroundColor(.secondary)
        } else {
            Stepper(value: $quantity, in: 0...999) {
                Text(quantityText)
            }
            .onAppear { quantity = film.quantity }
            .onChange(of: film.quantity) { _, newVal in quantity = newVal }
            .onChange(of: quantity) { _, newValue in
                if newValue == 0 {
                    dataManager.deleteRollsById([film.id])
                } else {
                    var updated = film
                    updated.quantity = newValue
                    dataManager.updateFilmStock(updated)
                }
            }
        }
    }

    private var quantityText: String {
        FilmStock.localizedQuantityLabel(quantity: quantity, format: film.format)
    }
}
