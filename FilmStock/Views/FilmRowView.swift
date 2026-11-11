//
//  FilmRowView.swift
//  FilmStock
//
//  Table row view (iOS List style)
//

import SwiftUI

// MARK: - Browse table columns (built-in format names + Settings custom formats)

private func normalizeFormatForBrowseTable(_ format: FilmStock.FilmFormat) -> FilmStock.FilmFormat {
    switch format {
    case .oneTwenty, .oneTwentySeven: return .oneTwenty
    default: return format
    }
}

/// Stock count for one column label (`FilmFormat.displayName` or a name from `SettingsManager.customFormats`).
private func quantityForBrowseFormatColumn(
    title: String,
    formats: [GroupedFilm.FormatInfo],
    settings: SettingsManager
) -> Int {
    if settings.isCustomFormat(title) {
        return formats
            .filter { $0.format == .other && $0.customFormatName == title }
            .reduce(0) { $0 + $1.quantity }
    }
    guard let builtIn = FilmStock.FilmFormat.allCases.first(where: { $0.displayName == title }) else {
        return 0
    }
    if builtIn == .other {
        return formats
            .filter { info in
                guard info.format == .other else { return false }
                guard let name = info.customFormatName, !name.isEmpty else { return true }
                return !settings.isCustomFormat(name)
            }
            .reduce(0) { $0 + $1.quantity }
    }
    return formats
        .filter { normalizeFormatForBrowseTable($0.format) == normalizeFormatForBrowseTable(builtIn) }
        .reduce(0) { $0 + $1.quantity }
}

@ViewBuilder
private func browseFormatColumn(title: String, formats: [GroupedFilm.FormatInfo], settings: SettingsManager) -> some View {
    let qty = quantityForBrowseFormatColumn(title: title, formats: formats, settings: settings)
    VStack(spacing: 2) {
        Text(title)
            .font(.caption2)
            .foregroundColor(.secondary)
            .lineLimit(2)
            .minimumScaleFactor(0.75)
            .multilineTextAlignment(.center)
        Text(qty > 0 ? "\(qty)" : "-")
            .font(.subheadline)
            .fontWeight(.medium)
    }
    .frame(minWidth: 36, maxWidth: 56)
    .multilineTextAlignment(.center)
}

struct FilmRowViewContent: View {
    let groupedFilm: GroupedFilm
    @EnvironmentObject var dataManager: FilmStockDataManager
    @ObservedObject private var settingsManager = SettingsManager.shared
    @State private var image: UIImage?
    
    private var formatColumnTitles: [String] {
        settingsManager.formatsToShow
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Logo (small)
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 20, height: 20)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(groupedFilm.name)
                    .font(.body)
                
                Text(groupedFilm.manufacturer)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Format quantities (scrollable horizontally)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(formatColumnTitles, id: \.self) { title in
                        browseFormatColumn(title: title, formats: groupedFilm.formats, settings: settingsManager)
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(width: 160)
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.trailing, 16)
        }
        .padding(.leading, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            loadImage()
        }
        .onChange(of: groupedFilm.imageSource) { _, _ in
            loadImage()
        }
        .onChange(of: groupedFilm.imageName) { oldValue, newValue in
            loadImage()
        }
        .onChange(of: groupedFilm.name) { oldValue, newValue in
            loadImage()
        }
        .onChange(of: groupedFilm.manufacturer) { oldValue, newValue in
            loadImage()
        }
    }
    
    private func loadImage() {
        self.image = ImageStorage.shared.resolveFilmImage(
            imageSourceRawValue: groupedFilm.imageSource,
            imageName: groupedFilm.imageName,
            filmName: groupedFilm.name,
            manufacturer: groupedFilm.manufacturer
        )
    }
}
