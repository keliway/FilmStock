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
    let exposures: Int?           // from first roll; applied to all on edit
    let comments: String?         // from first roll; applied to all on edit
    var rollIds: [String]         // individual MyFilm IDs in this group

    var count: Int { rollIds.count }

    var id: String { "\(format.rawValue)|\(expireDate ?? "")|\(isFrozen)" }

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
    @Environment(\.dismiss) var dismiss

    @State private var relatedFilms: [FilmStock] = []
    @State private var showingEditSheet = false
    @State private var showingLoadSheet = false
    @State private var shouldDismissAfterLoad = false
    @State private var groupToEdit: RollGroupItem?
    @State private var showingAddRollsSheet = false
    @State private var navImage: UIImage? = nil

    private var currentGroupedFilm: GroupedFilm? {
        dataManager.cachedGroupedFilms.first { $0.id == groupedFilm.id }
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

            // 4x5 / 5x7 / 8x10 sheet formats
            let largeFormats = largeFormatFilms
            if !largeFormats.isEmpty {
                Section("detail.sheets") {
                    ForEach(largeFormats) { film in
                        HStack {
                            Text(film.formatDisplayName)
                            Spacer()
                            QuantityControlView(film: film)
                                .environmentObject(dataManager)
                        }
                    }
                }
            }

            // Other / custom formats
            let otherFormats = otherFormatFilms
            if !otherFormats.isEmpty {
                Section("detail.other") {
                    ForEach(otherFormats) { film in
                        HStack {
                            Text(film.formatDisplayName)
                            Spacer()
                            QuantityControlView(film: film)
                                .environmentObject(dataManager)
                        }
                    }
                }
            }

            // Comments
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
        .sheet(isPresented: $showingAddRollsSheet) {
            RollBatchSheet { batch in
                let dateDigits = batch.expireDate.filter { $0.isNumber }
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
                    comments: nil,
                    isFrozen: batch.isFrozen,
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

                    if let exp = group.exposures, exp > 0 {
                        Text("· \(exp)exp")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if group.isFrozen || group.isExpired {
                    HStack(spacing: 5) {
                        if group.isFrozen {
                            tagChip(NSLocalizedString("film.frozen", comment: ""), color: .blue)
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
        let src = ImageSource(rawValue: film.imageSource) ?? .autoDetected
        let mfr = film.manufacturer
        switch src {
        case .custom:
            if let name = film.imageName {
                let parts = name.split(separator: "/", maxSplits: 1).map(String.init)
                let (m, filename) = parts.count == 2 ? (parts[0], parts[1]) : (mfr, name)
                navImage = ImageStorage.shared.loadImage(filename: filename, manufacturer: m)
            }
        case .catalog:
            if let name = film.imageName {
                navImage = ImageStorage.shared.loadCatalogImage(filename: name)
            }
        case .autoDetected:
            navImage = ImageStorage.shared.loadDefaultImage(filmName: film.name, manufacturer: mfr)
        case .none:
            navImage = nil
        }
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

        // Build buckets keyed by (format, expireDate, isFrozen)
        var buckets: [String: RollGroupItem] = [:]
        for film in rollFilms {
            let expiry = film.expireDate?.first
            let key = "\(film.format.rawValue)|\(expiry ?? "")|\(film.isFrozen)"
            if var existing = buckets[key] {
                existing.rollIds.append(film.id)
                buckets[key] = existing
            } else {
                buckets[key] = RollGroupItem(
                    format: film.format,
                    customFormatName: film.customFormatName,
                    expireDate: expiry,
                    isFrozen: film.isFrozen,
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
                return false
            }
            let displayName = groups.compactMap { $0.customFormatName }.first ?? format.displayName
            return (format, displayName, sorted)
        }
    }

    private func loadRelatedFilms() {
        relatedFilms = dataManager.filmStocks.filter { film in
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
    @State private var exposures: Int?
    @State private var customExposures: String
    @State private var comments: String
    @State private var expireDateError: String?

    init(group: RollGroupItem) {
        self.group = group
        _count       = State(initialValue: group.count)
        _expireDate  = State(initialValue: group.expireDate ?? "")
        _isFrozen    = State(initialValue: group.isFrozen)
        _comments    = State(initialValue: group.comments ?? "")
        // Map exposures to picker tags: valid option → direct, unknown → -1 (custom), nil → default
        if let exp = group.exposures {
            if group.format.exposureOptions.contains(exp) {
                _exposures       = State(initialValue: exp)
                _customExposures = State(initialValue: "")
            } else {
                _exposures       = State(initialValue: -1)
                _customExposures = State(initialValue: "\(exp)")
            }
        } else if let def = group.format.defaultExposures {
            _exposures       = State(initialValue: def)
            _customExposures = State(initialValue: "")
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
                        count == 1
                            ? String(format: NSLocalizedString("film.rollCount", comment: ""), count)
                            : String(format: NSLocalizedString("film.rollsCount", comment: ""), count),
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
                            Text(error).font(.caption).foregroundColor(.red)
                        }
                    }
                }

                // Frozen
                Section {
                    Toggle("film.isFrozen", isOn: $isFrozen)
                }

                // Exposures (options vary by format)
                if !group.format.exposureOptions.isEmpty {
                    Section("film.exposures") {
                        Picker("film.exposures", selection: $exposures) {
                            Text(LocalizedStringKey("film.exposures.unspecified")).tag(nil as Int?)
                            ForEach(group.format.exposureOptions, id: \.self) { opt in
                                Text("\(opt)").tag(opt as Int?)
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

    // MARK: - Save

    private func save() {
        let cleanDate: String? = expireDate.isEmpty ? nil : expireDate.filter { $0.isNumber }
        let resolvedExposures: Int? = {
            if exposures == -1, let n = Int(customExposures), n > 0 { return n }
            if let e = exposures, e > 0 { return e }
            return nil
        }()

        let delta = count - group.count

        let cleanComments: String? = comments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? nil : comments.trimmingCharacters(in: .whitespacesAndNewlines)

        if count == 0 {
            dataManager.deleteRollsById(group.rollIds)
        } else if delta > 0 {
            dataManager.updateRolls(
                ids: group.rollIds,
                expireDate: cleanDate,
                isFrozen: isFrozen,
                exposures: resolvedExposures,
                comments: cleanComments
            )
            _ = dataManager.addRolls(
                count: delta,
                matchingFilmStockId: group.rollIds.first!,
                expireDate: cleanDate,
                isFrozen: isFrozen,
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
                exposures: resolvedExposures,
                comments: cleanComments
            )
        } else {
            dataManager.updateRolls(
                ids: group.rollIds,
                expireDate: cleanDate,
                isFrozen: isFrozen,
                exposures: resolvedExposures,
                comments: cleanComments
            )
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
            .onChange(of: quantity) { _, newValue in
                var updated = film
                updated.quantity = newValue
                dataManager.updateFilmStock(updated)
            }
        }
    }

    private var quantityText: String {
        let unit = film.format.quantityUnit
        if unit == "Rolls" {
            return quantity == 1
                ? String(format: NSLocalizedString("film.rollCount", comment: ""), quantity)
                : String(format: NSLocalizedString("film.rollsCount", comment: ""), quantity)
        } else if unit == "Sheets" {
            return String(format: NSLocalizedString("Sheets: %d", comment: ""), quantity)
        }
        return "\(quantity) \(unit)"
    }
}
