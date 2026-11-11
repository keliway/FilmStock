//
//  FilmRowView.swift
//  FilmStock
//
//  Compact table row view for films
//

import SwiftUI
import UIKit

/// Format column order for the compact browse table (only includes formats enabled in Settings).
enum BrowseTableFormats {
    static let orderedCandidates: [FilmStock.FilmFormat] = [
        .thirtyFive,
        .oneTwenty,
        .oneTwentySeven,
        .oneTen,
        .twoTwenty,
        .fourByFive,
        .fiveBySeven,
        .eightByTen,
    ]

    static func visibleFormats(using settings: SettingsManager) -> [FilmStock.FilmFormat] {
        orderedCandidates.filter { settings.isFormatEnabled($0.displayName) }
    }
}

private func normalizeFormatForBrowseTable(_ format: FilmStock.FilmFormat) -> FilmStock.FilmFormat {
    if format == .oneTwentySeven {
        return .oneTwenty
    }
    return format
}

private struct BrowseFormatRollCell: View {
    let formatName: String
    let count: Int

    var body: some View {
        VStack(spacing: 4) {
            Text(formatName)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text("\(count)")
                .font(.subheadline)
                .fontWeight(count > 0 ? .semibold : .regular)
                .foregroundColor(count > 0 ? .primary : .secondary)
        }
        .frame(width: 44)
    }
}

private var browseTableFormatSeparator: some View {
    Rectangle()
        .fill(Color.secondary.opacity(0.2))
        .frame(width: 1, height: 30)
}

// Content-only version for use in List with swipeActions
struct FilmRowViewContent: View {
    let groupedFilm: GroupedFilm
    @ObservedObject private var settingsManager = SettingsManager.shared
    @State private var image: UIImage?
    
    // Group formats by normalized format type
    private var formatCounts: [FilmStock.FilmFormat: Int] {
        var counts: [FilmStock.FilmFormat: Int] = [:]
        for formatInfo in groupedFilm.formats {
            let normalizedFormat = normalizeFormatForBrowseTable(formatInfo.format)
            counts[normalizedFormat, default: 0] += formatInfo.quantity
        }
        return counts
    }

    private var visibleTableFormats: [FilmStock.FilmFormat] {
        BrowseTableFormats.visibleFormats(using: settingsManager)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Film reminder image (smaller version)
            Group {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        Color(.systemGray5)
                        Text(String(groupedFilm.manufacturer.prefix(1)))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Film name and details
            VStack(alignment: .leading, spacing: 2) {
                Text("\(groupedFilm.manufacturer) \(groupedFilm.name)")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                HStack(spacing: 6) {
                    Text(groupedFilm.type.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("ISO \(groupedFilm.filmSpeed)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Format counts in columns (only formats enabled in Settings → Manage Formats)
            if !visibleTableFormats.isEmpty {
                HStack(spacing: 0) {
                    ForEach(Array(visibleTableFormats.enumerated()), id: \.element) { index, fmt in
                        if index > 0 {
                            browseTableFormatSeparator
                        }
                        BrowseFormatRollCell(
                            formatName: fmt.displayName,
                            count: formatCounts[fmt] ?? 0
                        )
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .onAppear {
            loadImage()
        }
        .onChange(of: groupedFilm.imageSource) { _, _ in
            loadImage()
        }
        .onChange(of: groupedFilm.imageName) { _, _ in
            loadImage()
        }
        .onChange(of: groupedFilm.name) { _, _ in
            loadImage()
        }
        .onChange(of: groupedFilm.manufacturer) { _, _ in
            loadImage()
        }
    }
    
    private func loadImage() {
        image = ImageStorage.shared.resolveFilmImage(
            imageSourceRawValue: groupedFilm.imageSource,
            imageName: groupedFilm.imageName,
            filmName: groupedFilm.name,
            manufacturer: groupedFilm.manufacturer
        )
    }
}
