//
//  FilmFormComponents.swift
//  FilmStock
//
//  Shared UI components and validation helpers for Add / Edit / Detail film forms.
//

import SwiftUI

extension FilmStock {
    static let standardISOValues = [
        1, 2, 4, 5, 8, 10, 12, 16, 20, 25, 32, 40, 50, 64, 80, 100, 125,
        160, 200, 250, 320, 400, 500, 640, 800, 1000, 1250, 1600, 2000,
        2500, 3200, 6400
    ]

    /// Formats user-typed digits into `MM/YYYY` once 6 digits are entered, capping at 6 digits.
    static func formatExpiryInput(_ raw: String) -> String {
        let digits = raw.filter(\.isNumber)
        let limited = String(digits.prefix(6))
        if limited.count == 6 {
            return "\(limited.prefix(2))/\(limited.suffix(4))"
        }
        return limited
    }

    /// Validates a user-entered expiry date string (`YYYY` or `MM/YYYY` / `MMYYYY`).
    /// Returns a localized error message when invalid, or `nil` when empty or valid.
    static func validateExpiryInput(_ raw: String) -> String? {
        let digits = raw.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }
        if digits.count == 4 {
            guard let year = Int(digits), (1950...2100).contains(year) else {
                return NSLocalizedString("error.invalidYear", comment: "")
            }
            return nil
        }
        if digits.count == 6 {
            let month = Int(digits.prefix(2)) ?? 0
            let year = Int(digits.suffix(4)) ?? 0
            guard (1...12).contains(month) else {
                return NSLocalizedString("error.invalidMonth", comment: "")
            }
            guard (1950...2100).contains(year) else {
                return NSLocalizedString("error.invalidYear", comment: "")
            }
            return nil
        }
        return NSLocalizedString("error.invalidDateFormat", comment: "")
    }

    /// Localized sheet count label (e.g. "1 sheet", "4 sheets").
    static func localizedSheetCount(_ count: Int) -> String {
        let key = count == 1 ? "format.sheet.count" : "format.sheets.count"
        return String(format: NSLocalizedString(key, comment: ""), count)
    }

    /// Localized roll / sheet quantity label (e.g. "1 Roll", "3 Rolls", "10 Sheets").
    static func localizedQuantityLabel(quantity: Int, format: FilmFormat) -> String {
        let unit = format.quantityUnit
        if unit == "Rolls" {
            return quantity == 1
                ? String(format: NSLocalizedString("film.rollCount", comment: ""), quantity)
                : String(format: NSLocalizedString("film.rollsCount", comment: ""), quantity)
        }
        if unit == "Sheets" {
            return String(format: NSLocalizedString("Sheets: %d", comment: ""), quantity)
        }
        return "\(quantity) \(unit)"
    }
}

// MARK: - Film Storage Section (None / Fridge / Frozen)

struct FilmStorageSection: View {
    @Binding var isFrozen: Bool
    @Binding var isFridge: Bool
    @ObservedObject private var settingsManager = SettingsManager.shared

    private var selection: Binding<Int> {
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
        if settingsManager.enableFridge {
            Section("film.storage") {
                Picker("film.storage", selection: selection) {
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
    }
}

// MARK: - Film Reminder Image Picker + Preview

struct FilmReminderImageEditor: View {
    @Binding var selectedImage: UIImage?
    let defaultImage: UIImage?
    @Binding var selectedCatalogFilename: String?
    @Binding var imageSource: ImageSource
    var onCustomPhotoPicked: (() -> Void)? = nil

    @State private var showingImagePicker = false
    @State private var showingImageCatalog = false
    @State private var rawSelectedImage: UIImage?
    @State private var catalogSelectedSource: ImageSource?

    var body: some View {
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
                                    if imageSource != .catalog && imageSource != .custom {
                                        imageSource = selectedCatalogFilename != nil && !selectedCatalogFilename!.contains("/")
                                            ? .catalog : .custom
                                    }
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
        .onChange(of: rawSelectedImage) { _, newValue in
            if let img = newValue {
                selectedImage = img
                imageSource = .custom
                selectedCatalogFilename = nil
                catalogSelectedSource = nil
                onCustomPhotoPicked?()
                rawSelectedImage = nil
            }
        }
        .onChange(of: catalogSelectedSource) { _, newValue in
            if let source = newValue {
                imageSource = source
                catalogSelectedSource = nil
            }
        }
        .onChange(of: selectedImage) { _, newValue in
            if newValue == nil {
                selectedCatalogFilename = nil
                imageSource = defaultImage != nil ? .autoDetected : .none
            }
        }
    }
}
