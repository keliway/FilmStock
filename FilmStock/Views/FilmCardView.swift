//
//  FilmCardView.swift
//  FilmStock
//
//  Card view for film stock (iOS HIG style)
//

import SwiftUI

struct FilmCardView: View {
    let groupedFilm: GroupedFilm
    @State private var filmImage: UIImage?
    @ObservedObject private var settingsManager = SettingsManager.shared
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 12) {
                // Film image
                if let image = filmImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "camera")
                                .foregroundColor(.gray)
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(groupedFilm.manufacturer) \(groupedFilm.name)")
                        .font(.headline)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack(spacing: 4) {
                        Text("ISO \(groupedFilm.filmSpeed)")
                        Text("•")
                        HStack(spacing: 4) {
                            Text(groupedFilm.type.displayName)
                            // Type indicator ball
                            if groupedFilm.type == .color {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                .red, .orange, .yellow, .green, .blue, .purple
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 10, height: 10)
                            } else if groupedFilm.type == .slide {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                .red, .orange, .yellow, .green, .blue, .purple
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 10, height: 10)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.black, lineWidth: 1.5)
                                    )
                                
                            } else if groupedFilm.type == .instant {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 10, height: 10)
                            } else {
                                Circle()
                                    .fill(Color.gray)
                                    .frame(width: 10, height: 10)
                            }
                        }
                    }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Format quantities (max 2, then show +X)
                    HStack(spacing: 8) {
                        let visibleFormats = Array(groupedFilm.formats.filter { $0.quantity > 0 }.prefix(2))
                        let remainingCount = groupedFilm.formats.filter { $0.quantity > 0 }.count - visibleFormats.count
                        
                        ForEach(visibleFormats) { formatInfo in
                            HStack(spacing: 2) {
                                Text(formatInfo.formatDisplayName)
                                Text(": ")
                                Text("\(formatInfo.quantity)")
                                    .foregroundColor(.accentColor)
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        }
                        
                        if remainingCount > 0 {
                            Text("+\(remainingCount)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        // Comment indicator
                        if hasComments {
                            Image(systemName: "text.bubble")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                    
                Spacer()
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 16)
            .padding(.trailing, showAnyChip ? 70 : 0)
            .frame(maxWidth: .infinity, alignment: .leading)
                
            // Status chips in top right
            if showAnyChip {
                VStack(spacing: 4) {
                    if showExpiryChip {
                        if settingsManager.showExpiryDateInChip {
                            let chips = allExpiryChips
                            let maxVisible = 3
                            let visible = Array(chips.prefix(maxVisible))
                            let overflow = chips.count - maxVisible

                            ForEach(visible, id: \.text) { chip in
                                expiryChipView(chip)
                            }
                            if overflow > 0 {
                                Text("+\(overflow)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .frame(minWidth: 62)
                                    .fixedSize()
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color.secondary, lineWidth: 1)
                                    )
                            }
                        } else {
                            // Setting off — show plain EXPIRED chip
                            Text("film.expired")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .frame(minWidth: 62)
                                .fixedSize()
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.red, lineWidth: 1)
                                )
                        }
                    }

                    // Blue "FROZEN" chip
                    if isFrozen {
                        Text("film.frozen")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .frame(minWidth: 62)
                            .fixedSize()
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                    }

                    // Blue "FRIDGE" chip
                    if isFridge {
                        Text("film.fridge")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .frame(minWidth: 62)
                            .fixedSize()
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                    }
                }
                .padding(.top, 4)
                .padding(.trailing, 4)
            }
        }
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
        filmImage = ImageStorage.shared.resolveFilmImage(
            imageSourceRawValue: groupedFilm.imageSource,
            imageName: groupedFilm.imageName,
            filmName: groupedFilm.name,
            manufacturer: groupedFilm.manufacturer
        )
    }
    
    private var isFrozen: Bool {
        // Check if any format is frozen
        return groupedFilm.formats.contains { $0.isFrozen }
    }
    
    private var isFridge: Bool {
        // Check if any format is stored in fridge (only when enabled in settings)
        return settingsManager.enableFridge && groupedFilm.formats.contains { $0.isFridge }
    }
    
    private var hasComments: Bool {
        // Check if any format has comments
        return groupedFilm.formats.contains { 
            if let comments = $0.comments, !comments.isEmpty {
                return true
            }
            return false
        }
    }
    
    // Whether to show any chip (expiry, frozen, or fridge)
    private var showAnyChip: Bool {
        return showExpiryChip || isFrozen || isFridge
    }
    
    // Whether to show the expiry chip
    private var showExpiryChip: Bool {
        // If setting is ON, show chip if there's any expiry date
        if settingsManager.showExpiryDateInChip {
            return hasAnyExpiryDate
        }
        // If setting is OFF, only show if expired
        return isExpired
    }
    
    // Check if film has any expiry date set
    private var hasAnyExpiryDate: Bool {
        for formatInfo in groupedFilm.formats {
            if let expireDates = formatInfo.expireDate, !expireDates.isEmpty {
                for dateString in expireDates where !dateString.isEmpty {
                    return true
                }
            }
        }
        return false
    }
    
    @ViewBuilder
    private func expiryChipView(_ chip: (text: String, isExpired: Bool)) -> some View {
        Text(chip.text)
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(chip.isExpired ? .red : .primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .frame(minWidth: 62)
            .fixedSize()
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(chip.isExpired ? Color.red : Color.primary, lineWidth: 1)
            )
    }

    // All unique expiry dates as formatted chip entries, sorted chronologically.
    private var allExpiryChips: [(text: String, isExpired: Bool)] {
        let today = Date()

        // Collect unique raw date strings across all formats
        var seen = Set<String>()
        var entries: [(sortDate: Date, text: String, isExpired: Bool)] = []

        for formatInfo in groupedFilm.formats {
            guard let expireDates = formatInfo.expireDate else { continue }
            for raw in expireDates where !raw.isEmpty {
                let normalised = FilmStock.formatExpireDate(raw) // normalise MMYYYY → MM/YYYY etc.
                guard !seen.contains(normalised) else { continue }
                seen.insert(normalised)

                guard let parsed = FilmStock.parseExpireDate(raw) else { continue }
                let expired = parsed < today

                entries.append((sortDate: parsed, text: formatExpiryDateForChip(raw), isExpired: expired))
            }
        }

        return entries
            .sorted { $0.sortDate < $1.sortDate }
            .map { (text: $0.text, isExpired: $0.isExpired) }
    }
    
    // Formats expiry date for chip display: "03/95" for MM/YYYY, "2001" for YYYY
    private func formatExpiryDateForChip(_ dateString: String) -> String {
        // Normalise MMYYYY (6 raw digits, migrated data) → MM/YYYY before formatting
        let normalised: String
        if dateString.count == 6 && dateString.allSatisfy(\.isNumber) {
            normalised = "\(dateString.prefix(2))/\(dateString.suffix(4))"
        } else {
            normalised = dateString
        }

        let parts = normalised.split(separator: "/")

        if parts.count == 2 {
            // MM/YYYY format - convert to MM/YY
            let month = String(parts[0])
            let year = String(parts[1])
            let shortYear = year.count == 4 ? String(year.suffix(2)) : year
            return "\(month)/\(shortYear)"
        } else if normalised.count == 4 {
            // YYYY format - keep as is
            return normalised
        }
        
        // For other formats, return as-is
        return dateString
    }
    
    private var isExpired: Bool {
        let today = Date()
        
        // Check if any format has expired dates
        for formatInfo in groupedFilm.formats {
            guard let expireDates = formatInfo.expireDate, !expireDates.isEmpty else {
                continue
            }
            
            // Check if any expire date has passed
            for dateString in expireDates {
                if let expireDate = FilmStock.parseExpireDate(dateString), expireDate < today {
                    return true
                }
            }
        }
        
        return false
    }
}
