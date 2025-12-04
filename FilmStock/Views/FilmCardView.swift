//
//  FilmCardView.swift
//  FilmStock
//
//  Card view for film stock (iOS HIG style)
//

import SwiftUI

// Helper function to parse custom image name
// Returns (manufacturer, filename) tuple
private func parseCustomImageName(_ imageName: String, defaultManufacturer: String) -> (String, String) {
    if imageName.contains("/") {
        let components = imageName.split(separator: "/", maxSplits: 1)
        if components.count == 2 {
            return (String(components[0]), String(components[1]))
        }
    }
    return (defaultManufacturer, imageName)
}

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
                    // Expiry chip: shows "EXPIRED" or date depending on setting
                    if showExpiryChip {
                        Text(expiryChipText)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(expiryChipColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .frame(minWidth: 62)
                            .fixedSize()
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(expiryChipColor, lineWidth: 1)
                            )
                    }
                    
                    // Blue "FROZEN" chip
                    if isFrozen {
                        Text("FROZEN")
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
        let imageSource = ImageSource(rawValue: groupedFilm.imageSource) ?? .autoDetected
        
        switch imageSource {
        case .custom:
            // Load user-taken photo
            if let customImageName = groupedFilm.imageName {
                // Handle manufacturer/filename format (for catalog-selected photos)
                let (manufacturer, filename) = parseCustomImageName(customImageName, defaultManufacturer: groupedFilm.manufacturer)
                if let userImage = ImageStorage.shared.loadImage(filename: filename, manufacturer: manufacturer) {
                    filmImage = userImage
                    return
                }
            }
            
        case .catalog:
            // Load catalog image by exact filename
            if let catalogImageName = groupedFilm.imageName {
                if let catalogImage = ImageStorage.shared.loadCatalogImage(filename: catalogImageName) {
                    filmImage = catalogImage
                    return
                }
            }
            
        case .autoDetected:
            // Auto-detect default image based on manufacturer + film name
            if let defaultImage = ImageStorage.shared.loadDefaultImage(filmName: groupedFilm.name, manufacturer: groupedFilm.manufacturer) {
                filmImage = defaultImage
                return
            }
            
        case .none:
            // No image
            filmImage = nil
            return
        }
    }
    
    private var isFrozen: Bool {
        // Check if any format is frozen
        return groupedFilm.formats.contains { $0.isFrozen }
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
    
    // Whether to show any chip (expiry or frozen)
    private var showAnyChip: Bool {
        return showExpiryChip || isFrozen
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
    
    // Returns the text to display in the expiry chip
    private var expiryChipText: String {
        // If setting is disabled, show "EXPIRED"
        guard settingsManager.showExpiryDateInChip else {
            return "EXPIRED"
        }
        
        // Find the date closest to current date to display
        if let expiryDateString = closestExpiryDateString {
            return expiryDateString
        }
        
        return "EXPIRED"
    }
    
    // Returns the color for the expiry chip (red if expired, black if not)
    private var expiryChipColor: Color {
        if settingsManager.showExpiryDateInChip {
            return isExpired ? .red : .primary
        }
        return .red
    }
    
    // Returns the formatted expiry date string closest to current date (e.g., "03/95" or "2001")
    private var closestExpiryDateString: String? {
        let today = Date()
        let calendar = Calendar.current
        var closestDate: (date: Date, original: String, distance: TimeInterval)? = nil
        
        for formatInfo in groupedFilm.formats {
            guard let expireDates = formatInfo.expireDate, !expireDates.isEmpty else {
                continue
            }
            
            for dateString in expireDates {
                guard !dateString.isEmpty else { continue }
                
                if let expireDate = FilmStock.parseExpireDate(dateString) {
                    var compareDate = expireDate
                    
                    // For YYYY format, use end of year
                    if dateString.count == 4 {
                        let year = calendar.component(.year, from: expireDate)
                        if let endOfYear = calendar.date(from: DateComponents(year: year, month: 12, day: 31)) {
                            compareDate = endOfYear
                        }
                    } else if dateString.split(separator: "/").count == 2 {
                        // For MM/YYYY format, use end of month
                        let components = calendar.dateComponents([.year, .month], from: expireDate)
                        if let year = components.year,
                           let month = components.month,
                           let daysInMonth = calendar.range(of: .day, in: .month, for: expireDate)?.count,
                           let endOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: daysInMonth)) {
                            compareDate = endOfMonth
                        }
                    }
                    
                    // Calculate absolute distance from today
                    let distance = abs(compareDate.timeIntervalSince(today))
                    
                    // Keep track of the closest date to today
                    if closestDate == nil || distance < closestDate!.distance {
                        closestDate = (expireDate, dateString, distance)
                    }
                }
            }
        }
        
        // Format the closest date
        if let (_, originalString, _) = closestDate {
            return formatExpiryDateForChip(originalString)
        }
        
        return nil
    }
    
    // Formats expiry date for chip display: "03/95" for MM/YYYY, "2001" for YYYY
    private func formatExpiryDateForChip(_ dateString: String) -> String {
        let parts = dateString.split(separator: "/")
        
        if parts.count == 2 {
            // MM/YYYY format - convert to MM/YY
            let month = String(parts[0])
            let year = String(parts[1])
            let shortYear = year.count == 4 ? String(year.suffix(2)) : year
            return "\(month)/\(shortYear)"
        } else if dateString.count == 4 {
            // YYYY format - keep as is
            return dateString
        }
        
        // For other formats, return as-is
        return dateString
    }
    
    private var isExpired: Bool {
        let today = Date()
        let calendar = Calendar.current
        
        // Check if any format has expired dates
        for formatInfo in groupedFilm.formats {
            guard let expireDates = formatInfo.expireDate, !expireDates.isEmpty else {
                continue
            }
            
            // Check if any expire date has passed
            for dateString in expireDates {
                if let expireDate = FilmStock.parseExpireDate(dateString) {
                    var compareDate = expireDate
                    
                    // For YYYY format, compare to end of year (Dec 31)
                    if dateString.count == 4 {
                        let year = calendar.component(.year, from: expireDate)
                        if let endOfYear = calendar.date(from: DateComponents(year: year, month: 12, day: 31)) {
                            compareDate = endOfYear
                        }
                    } else if dateString.split(separator: "/").count == 2 {
                        // For MM/YYYY format, compare to end of month
                        let components = calendar.dateComponents([.year, .month], from: expireDate)
                        if let year = components.year,
                           let month = components.month,
                           let daysInMonth = calendar.range(of: .day, in: .month, for: expireDate)?.count,
                           let endOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: daysInMonth)) {
                            compareDate = endOfMonth
                        }
                    }
                    // For MM/DD/YYYY format, compare directly (already set)
                    
                    // Compare dates (ignore time)
                    if let todayStart = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: today),
                       let compareStart = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: compareDate) {
                        if todayStart > compareStart {
                            return true
            }
        }
                }
            }
        }
        
        return false
    }
}

