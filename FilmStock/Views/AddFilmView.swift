//
//  AddFilmView.swift
//  FilmStock
//

import SwiftUI

// MARK: - Roll Batch Model

struct RollBatch: Identifiable {
    let id: UUID
    var format: FilmStock.FilmFormat
    var customFormatName: String?
    var quantity: Int
    var expireDate: String    // formatted: "12/2026" or "2026" or ""
    var isFrozen: Bool
    var exposures: Int?       // nil = unspecified, -1 = custom picker tag, else the value
    var customExposures: String

    var comments: String

    init(
        id: UUID = UUID(),
        format: FilmStock.FilmFormat = .thirtyFive,
        customFormatName: String? = nil,
        quantity: Int = 1,
        expireDate: String = "",
        isFrozen: Bool = false,
        exposures: Int? = nil,
        customExposures: String = "",
        comments: String = ""
    ) {
        self.id = id
        self.format = format
        self.customFormatName = customFormatName
        self.quantity = quantity
        self.expireDate = expireDate
        self.isFrozen = isFrozen
        self.exposures = exposures ?? format.defaultExposures
        self.customExposures = customExposures
        self.comments = comments
    }

    var resolvedExposures: Int? {
        if exposures == -1, let n = Int(customExposures), n > 0 { return n }
        if let e = exposures, e > 0 { return e }
        return nil
    }

    var formatDisplayName: String {
        if format == .other, let name = customFormatName, !name.isEmpty { return name }
        return format.displayName
    }

    var isExpired: Bool {
        let digits = expireDate.filter { $0.isNumber }
        guard !digits.isEmpty, let date = FilmStock.parseExpireDate(digits) else { return false }
        return date < Date()
    }
}

// MARK: - Add Film View

struct AddFilmView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataManager: FilmStockDataManager
    @ObservedObject private var settingsManager = SettingsManager.shared

    // Film info
    @State private var name = ""
    @State private var manufacturer = ""
    @State private var type: FilmStock.FilmType = .bw
    @State private var filmSpeed = 400
    private let isoValues = [1, 2, 4, 5, 8, 10, 12, 16, 20, 25, 32, 40, 50, 64, 80, 100, 125,
                              160, 200, 250, 320, 400, 500, 640, 800, 1000, 1250, 1600, 2000,
                              2500, 3200, 6400]

    // Image
    @State private var selectedImage: UIImage?
    @State private var defaultImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingImageCatalog = false
    @State private var rawSelectedImage: UIImage?
    @State private var selectedCatalogFilename: String?
    @State private var imageSource: ImageSource = .autoDetected
    @State private var catalogSelectedSource: ImageSource?
    @State private var hasAutoPopulatedMetadata = false

    // Roll batches
    @State private var rollBatches: [RollBatch] = []
    @State private var showingAddBatch = false
    @State private var batchToEdit: RollBatch?

    // Validation
    @State private var nameError: String?

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Film Information
                Section("film.filmInformation") {
                    NavigationLink {
                        ManufacturerPickerView(selectedManufacturer: $manufacturer)
                            .environmentObject(dataManager)
                    } label: {
                        if manufacturer.isEmpty {
                            Text("film.selectManufacturer").foregroundColor(.secondary)
                        } else {
                            Text(manufacturer).foregroundColor(.primary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        TextField("film.name", text: $name)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .onSubmit {
                                UIApplication.shared.sendAction(
                                    #selector(UIResponder.resignFirstResponder),
                                    to: nil, from: nil, for: nil
                                )
                            }
                            .onChange(of: name) { _, _ in nameError = nil }
                        if let error = nameError {
                            Text(error).font(.caption).foregroundColor(.red)
                        }
                    }

                    Picker("film.type", selection: $type) {
                        ForEach(FilmStock.FilmType.allCases, id: \.self) { t in
                            Text(t.displayName).tag(t)
                        }
                    }

                    Picker("film.speed", selection: $filmSpeed) {
                        ForEach(isoValues, id: \.self) { iso in
                            Text("ISO \(iso)").tag(iso)
                        }
                    }
                    .pickerStyle(.wheel)

                    // Film reminder image
                    VStack(alignment: .leading, spacing: 12) {
                        Text("film.filmReminder")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        if selectedImage == nil {
                            HStack(spacing: 12) {
                                Button { showingImagePicker = true } label: {
                                    HStack {
                                        Image(systemName: "camera.fill")
                                        Text("image.takePhoto")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.accentColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)

                                Button { showingImageCatalog = true } label: {
                                    HStack {
                                        Image(systemName: "photo.on.rectangle")
                                        Text("image.openCatalog")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemGray5))
                                    .foregroundColor(.primary)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if selectedImage != nil || defaultImage != nil {
                            HStack(spacing: 12) {
                                if let img = selectedImage {
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: img)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 100, height: 100)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(
                                                        imageSource == .custom || imageSource == .catalog
                                                            ? Color.accentColor : Color.clear,
                                                        lineWidth: 3
                                                    )
                                            )
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                imageSource = selectedCatalogFilename != nil ? .catalog : .custom
                                            }

                                        Button {
                                            selectedImage = nil
                                            selectedCatalogFilename = nil
                                            imageSource = defaultImage != nil ? .autoDetected : .none
                                        } label: {
                                            ZStack {
                                                Circle().fill(Color.black.opacity(0.6))
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.white)
                                                    .font(.system(size: 20))
                                            }
                                            .frame(width: 24, height: 24)
                                        }
                                        .buttonStyle(.plain)
                                        .offset(x: 4, y: -4)
                                        .zIndex(1)
                                    }
                                    .frame(width: 100, height: 100)
                                }

                                if let defImg = defaultImage {
                                    Image(uiImage: defImg)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 100, height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(
                                                    imageSource == .autoDetected ? Color.accentColor : Color.clear,
                                                    lineWidth: 3
                                                )
                                        )
                                        .contentShape(Rectangle())
                                        .onTapGesture { imageSource = .autoDetected }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // MARK: Rolls
                Section {
                    ForEach(rollBatches) { batch in
                        batchRow(batch)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    rollBatches.removeAll { $0.id == batch.id }
                                } label: {
                                    Label("action.delete", systemImage: "trash")
                                }
                            }
                    }

                    Button {
                        batchToEdit = nil
                        showingAddBatch = true
                    } label: {
                        Label("add.rolls", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("add.rolls.section")
                } footer: {
                    if rollBatches.isEmpty {
                        Text("add.rolls.hint")
                    }
                }
            }
            .navigationTitle("film.addFilm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("action.save") {
                        if validateAndSave() { dismiss() }
                    }
                    .fontWeight(.semibold)
                    .disabled(name.isEmpty || manufacturer.isEmpty || rollBatches.isEmpty)
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImageSourcePicker(finalImage: $rawSelectedImage, isPresented: $showingImagePicker)
            }
            .sheet(isPresented: $showingImageCatalog) {
                ImageCatalogView(
                    selectedImage: $selectedImage,
                    selectedImageFilename: $selectedCatalogFilename,
                    selectedImageSource: $catalogSelectedSource
                )
            }
            .sheet(isPresented: $showingAddBatch) {
                RollBatchSheet(existingBatch: batchToEdit) { saved in
                    if let editing = batchToEdit,
                       let idx = rollBatches.firstIndex(where: { $0.id == editing.id }) {
                        rollBatches[idx] = saved
                    } else {
                        rollBatches.append(saved)
                    }
                    batchToEdit = nil
                }
            }
            .onChange(of: rawSelectedImage) { _, newValue in
                if let img = newValue {
                    selectedImage = img
                    imageSource = .custom
                    selectedCatalogFilename = nil
                    catalogSelectedSource = nil
                }
            }
            .onChange(of: catalogSelectedSource) { _, newValue in
                if let source = newValue { imageSource = source }
            }
            .onChange(of: selectedImage) { _, newValue in
                if newValue == nil {
                    selectedCatalogFilename = nil
                    imageSource = defaultImage != nil ? .autoDetected : .none
                }
            }
            .onChange(of: manufacturer) { _, newValue in
                refreshMetadata(name: name, manufacturer: newValue)
            }
            .onChange(of: name) { _, newValue in
                refreshMetadata(name: newValue, manufacturer: manufacturer)
            }
            .onAppear {
                refreshMetadata(name: name, manufacturer: manufacturer)
            }
        }
    }

    // MARK: - Batch Row

    @ViewBuilder
    private func batchRow(_ batch: RollBatch) -> some View {
        Button {
            batchToEdit = batch
            showingAddBatch = true
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(batchCountLabel(batch))
                            .font(.body)
                            .foregroundColor(.primary)

                        if !batch.expireDate.isEmpty {
                            Text("(\(FilmStock.formatExpireDate(batch.expireDate.filter { $0.isNumber })))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        if let exp = batch.resolvedExposures {
                            Text("· \(exp)exp")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if batch.isFrozen || batch.isExpired {
                        HStack(spacing: 5) {
                            if batch.isFrozen {
                                batchChip(NSLocalizedString("film.frozen", comment: ""), color: .blue)
                            }
                            if batch.isExpired {
                                batchChip(NSLocalizedString("film.expired", comment: ""), color: .red)
                            }
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 2)
        }
    }

    private func batchCountLabel(_ batch: RollBatch) -> String {
        let unit = batch.format.quantityUnit
        if unit == "Rolls" {
            return batch.quantity == 1
                ? String(format: NSLocalizedString("film.rollCount", comment: ""), batch.quantity)
                    + " " + batch.formatDisplayName
                : String(format: NSLocalizedString("film.rollsCount", comment: ""), batch.quantity)
                    + " " + batch.formatDisplayName
        } else {
            return "\(batch.quantity)× \(batch.formatDisplayName)"
        }
    }

    @ViewBuilder
    private func batchChip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(color, lineWidth: 1))
    }

    // MARK: - Helpers

    private func refreshMetadata(name: String, manufacturer: String) {
        guard !name.isEmpty, !manufacturer.isEmpty else {
            defaultImage = nil
            return
        }
        let metadata = ImageStorage.shared.detectFilmMetadata(filmName: name, manufacturer: manufacturer)
        defaultImage = metadata.hasImage
            ? ImageStorage.shared.loadDefaultImage(filmName: name, manufacturer: manufacturer)
            : nil
        if !hasAutoPopulatedMetadata {
            if let speed = metadata.filmSpeed { filmSpeed = speed; hasAutoPopulatedMetadata = true }
            if let typeStr = metadata.type {
                switch typeStr {
                case "BW":    type = .bw
                case "Color": type = .color
                case "Slide": type = .slide
                default: break
                }
                hasAutoPopulatedMetadata = true
            }
        }
        if defaultImage != nil, imageSource == .none {
            imageSource = .autoDetected
        }
    }

    // MARK: - Save

    @discardableResult
    private func validateAndSave() -> Bool {
        nameError = nil
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            nameError = NSLocalizedString("error.nameEmpty", comment: "")
            return false
        }
        guard !rollBatches.isEmpty else { return false }

        // Resolve image
        var imageName: String? = nil
        let finalImageSource = imageSource
        switch finalImageSource {
        case .custom:
            if let catalogFilename = selectedCatalogFilename {
                imageName = catalogFilename
            } else if let img = selectedImage {
                imageName = ImageStorage.shared.saveImage(img, forManufacturer: manufacturer, filmName: name)
            }
        case .catalog:
            imageName = selectedCatalogFilename
        case .autoDetected, .none:
            imageName = nil
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let now = ISO8601DateFormatter().string(from: Date())

        for (index, batch) in rollBatches.enumerated() {
            let dateDigits = batch.expireDate.filter { $0.isNumber }
            let trimmedComments = batch.comments.trimmingCharacters(in: .whitespacesAndNewlines)
            let film = FilmStock(
                id: UUID().uuidString,
                name: trimmedName,
                manufacturer: manufacturer,
                type: type,
                filmSpeed: filmSpeed,
                format: batch.format,
                customFormatName: batch.customFormatName,
                quantity: batch.quantity,
                expireDate: dateDigits.isEmpty ? nil : [dateDigits],
                comments: trimmedComments.isEmpty ? nil : trimmedComments,
                isFrozen: batch.isFrozen,
                exposures: batch.resolvedExposures,
                createdAt: now,
                updatedAt: nil
            )
            _ = dataManager.addFilmStock(
                film,
                imageName: index == 0 ? imageName : nil,
                imageSource: index == 0 ? finalImageSource.rawValue : ImageSource.autoDetected.rawValue
            )
        }

        return true
    }
}

// MARK: - Roll Batch Sheet

struct RollBatchSheet: View {
    let existingBatch: RollBatch?
    let onSave: (RollBatch) -> Void

    @ObservedObject private var settingsManager = SettingsManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var selectedFormatString: String
    @State private var format: FilmStock.FilmFormat
    @State private var customFormatName: String?
    @State private var quantity: Int
    @State private var expireDate: String
    @State private var isFrozen: Bool
    @State private var exposures: Int?
    @State private var customExposures: String
    @State private var comments: String
    @State private var expireDateError: String?

    init(existingBatch: RollBatch? = nil, onSave: @escaping (RollBatch) -> Void) {
        self.existingBatch = existingBatch
        self.onSave = onSave

        let batch = existingBatch ?? RollBatch()
        _selectedFormatString = State(initialValue: batch.formatDisplayName)
        _format               = State(initialValue: batch.format)
        _customFormatName     = State(initialValue: batch.customFormatName)
        _quantity             = State(initialValue: batch.quantity)
        _expireDate           = State(initialValue: batch.expireDate)
        _isFrozen             = State(initialValue: batch.isFrozen)
        _comments             = State(initialValue: batch.comments)
        _customExposures      = State(initialValue: batch.customExposures)
        // Map exposure to a valid picker tag for the format
        if let exp = batch.exposures {
            if batch.format.exposureOptions.contains(exp) {
                _exposures = State(initialValue: exp)
            } else {
                _exposures       = State(initialValue: -1)
                _customExposures = State(initialValue: "\(exp)")
            }
        } else {
            _exposures = State(initialValue: batch.format.defaultExposures)
        }
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
                        // Reset exposures to the new format's default
                        exposures = newFormat.defaultExposures
                        customExposures = ""
                    }
                }

                // Quantity
                Section {
                    Stepper(
                        quantityLabel,
                        value: $quantity,
                        in: 1...999
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

                // Frozen (roll formats only)
                if format.isRollFormat {
                    Section {
                        Toggle("film.isFrozen", isOn: $isFrozen)
                    }
                }

                // Exposures (roll formats only, options vary by format)
                if format.isRollFormat && !format.exposureOptions.isEmpty {
                    Section("film.exposures") {
                        Picker("film.exposures", selection: $exposures) {
                            Text(LocalizedStringKey("film.exposures.unspecified")).tag(nil as Int?)
                            ForEach(format.exposureOptions, id: \.self) { opt in
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
            .navigationTitle(existingBatch == nil
                ? NSLocalizedString("add.rolls", comment: "")
                : String(format: NSLocalizedString("edit.rolls.title", comment: ""), format.displayName)
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("action.save") {
                        if validate() { commit() }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var quantityLabel: String {
        let unit = format.quantityUnit
        if unit == "Rolls" {
            return quantity == 1
                ? String(format: NSLocalizedString("film.rollCount", comment: ""), quantity)
                : String(format: NSLocalizedString("film.rollsCount", comment: ""), quantity)
        } else if unit == "Sheets" {
            return String(format: NSLocalizedString("Sheets: %d", comment: ""), quantity)
        }
        return "\(quantity) \(unit)"
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

    private func commit() {
        let savedCustomFormatName: String? = format == .other ? selectedFormatString : nil
        let saved = RollBatch(
            id: existingBatch?.id ?? UUID(),
            format: format,
            customFormatName: savedCustomFormatName,
            quantity: quantity,
            expireDate: expireDate,
            isFrozen: isFrozen,
            exposures: exposures,
            customExposures: customExposures,
            comments: comments
        )
        onSave(saved)
        dismiss()
    }
}

// MARK: - Manufacturer Picker

struct ManufacturerPickerView: View {
    @EnvironmentObject var dataManager: FilmStockDataManager
    @Binding var selectedManufacturer: String
    @Environment(\.dismiss) var dismiss
    var allowAddingManufacturer: Bool = true
    @State private var searchText = ""
    @State private var showingAddManufacturer = false
    @State private var newManufacturerName = ""
    @State private var showDuplicateError = false
    @State private var showDeleteError = false

    var manufacturers: [Manufacturer] {
        dataManager.getAllManufacturers()
    }

    var filteredManufacturers: [Manufacturer] {
        if searchText.isEmpty { return manufacturers }
        return manufacturers.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var isDuplicate: Bool {
        let trimmed = newManufacturerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return manufacturers.contains { $0.name.localizedCaseInsensitiveEquals(trimmed) }
    }

    var body: some View {
        List {
            ForEach(filteredManufacturers, id: \.persistentModelID) { manufacturer in
                Button {
                    selectedManufacturer = manufacturer.name
                    dismiss()
                } label: {
                    HStack {
                        Text(manufacturer.name)
                        Spacer()
                        if selectedManufacturer == manufacturer.name {
                            Image(systemName: "checkmark").foregroundColor(.accentColor)
                        }
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if manufacturer.isCustom {
                        Button(role: .destructive) {
                            if !dataManager.deleteManufacturer(manufacturer) {
                                showDeleteError = true
                            }
                        } label: {
                            Label("action.delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: Text("film.searchManufacturer"))
        .navigationTitle("film.selectManufacturer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if allowAddingManufacturer {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { newManufacturerName = ""; showingAddManufacturer = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .alert("manufacturer.add", isPresented: $showingAddManufacturer) {
            TextField("manufacturer.name", text: $newManufacturerName).autocorrectionDisabled()
            Button("action.cancel", role: .cancel) { newManufacturerName = "" }
            Button("action.add") {
                let trimmed = newManufacturerName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty && !isDuplicate {
                    let mfr = dataManager.addManufacturer(name: trimmed)
                    selectedManufacturer = mfr.name
                    dismiss()
                } else if isDuplicate {
                    showDuplicateError = true
                }
                newManufacturerName = ""
            }
            .disabled(
                newManufacturerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isDuplicate
            )
        } message: {
            if isDuplicate { Text("manufacturer.duplicateError") }
            else { Text("manufacturer.addMessage") }
        }
        .alert("manufacturer.duplicateTitle", isPresented: $showDuplicateError) {
            Button("action.ok", role: .cancel) { }
        } message: {
            Text("manufacturer.duplicateMessage")
        }
        .alert("manufacturer.deleteError", isPresented: $showDeleteError) {
            Button("action.ok", role: .cancel) { }
        } message: {
            Text("manufacturer.deleteErrorMessage")
        }
    }
}

extension String {
    func localizedCaseInsensitiveEquals(_ other: String) -> Bool {
        self.localizedCaseInsensitiveCompare(other) == .orderedSame
    }
}
