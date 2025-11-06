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
                    
                    // Format quantities
                    HStack(spacing: 8) {
                        ForEach(groupedFilm.formats) { formatInfo in
                            if formatInfo.quantity > 0 {
                                HStack(spacing: 2) {
                                    Text(formatInfo.format.displayName)
                                    Text(": ")
                                    Text("\(formatInfo.quantity)")
                                        .foregroundColor(.accentColor)
                                }
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            }
                            }
                        }
                    }
                    
                Spacer()
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                
            // Red "EXPIRED" chip in top right
            if isExpired {
                Text("EXPIRED")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                        .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.red, lineWidth: 1)
                        )
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
        // Try to load custom image first
        if let imageName = groupedFilm.imageName {
            if let image = ImageStorage.shared.loadImage(filename: imageName, manufacturer: groupedFilm.manufacturer) {
                filmImage = image
                return
        }
    }
    
        // Try to load default image
        if let defaultImage = ImageStorage.shared.loadDefaultImage(
            filmName: groupedFilm.name,
            manufacturer: groupedFilm.manufacturer
        ) {
            filmImage = defaultImage
        }
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

