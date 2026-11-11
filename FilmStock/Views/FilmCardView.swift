//
//  FilmCardView.swift
//  FilmStock
//
//  Modern card-based film display matching reference design
//

import SwiftUI
import UIKit

struct FilmCardView: View {
    let groupedFilm: GroupedFilm
    @EnvironmentObject var dataManager: FilmStockDataManager
    @ObservedObject private var settingsManager = SettingsManager.shared
    @State private var filmImage: UIImage? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            // Left: Square Image / Reminder
            ZStack {
                if let image = filmImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    // Default reminder aesthetic matching detail view
                    ZStack {
                        LinearGradient(
                            colors: [
                                Color(.systemGray5),
                                Color(.systemGray6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        
                        VStack(spacing: 4) {
                            Text(groupedFilm.manufacturer.uppercased())
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                                .tracking(1)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            
                            Text(groupedFilm.name)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.6)
                                .padding(.horizontal, 4)
                            
                            if groupedFilm.filmSpeed > 0 {
                                Text("ISO \(groupedFilm.filmSpeed)")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.accentColor)
                                    .padding(.top, 2)
                            }
                        }
                        .padding(4)
                    }
                }
            }
            .frame(width: 90, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
            
            // Right: Film Information
            VStack(alignment: .leading, spacing: 6) {
                // Header: Manufacturer & Status Chips
                HStack(alignment: .center, spacing: 6) {
                    Text(groupedFilm.manufacturer)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    Spacer()
                    
                    // Status chips
                    HStack(spacing: 4) {
                        if hasFrozenFilm {
                            Text("film.frozen")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.blue)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.blue, lineWidth: 1)
                                )
                        }
                        
                        if hasFridgeFilm {
                            Text("film.fridge")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.blue)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.blue, lineWidth: 1)
                                )
                        }
                        
                        if isExpired {
                            Text("film.expired")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.red)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.red, lineWidth: 1)
                                )
                        }
                    }
                }
                
                // Film Name
                Text(groupedFilm.name)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                // Film Type, ISO, and Expiry Dates
                HStack(spacing: 6) {
                    Text(groupedFilm.type.displayName)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(typeColor(for: groupedFilm.type).opacity(0.2))
                        .foregroundColor(typeColor(for: groupedFilm.type))
                        .clipShape(Capsule())
                    
                    if groupedFilm.filmSpeed > 0 {
                        Text("ISO \(groupedFilm.filmSpeed)")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Expiry Dates (aligned right)
                    if !allExpiryChips.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "calendar")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            
                            Text(allExpiryChips.map { $0.text }.joined(separator: ", "))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(allExpiryChips.contains(where: { $0.isExpired }) ? .red : .secondary)
                                .lineLimit(1)
                        }
                    }
                }
                
                Spacer(minLength: 2)
                
                // Formats and quantities
                if groupedFilm.formats.filter({ $0.quantity > 0 }).isEmpty {
                    Text("card.noStock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(consolidatedFormats, id: \.formatDisplayName) { formatInfo in
                                HStack(spacing: 3) {
                                    Text("\(formatInfo.quantity)×")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                    Text(formatInfo.formatDisplayName)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
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
        filmImage = ImageStorage.shared.resolveFilmImage(
            imageSourceRawValue: groupedFilm.imageSource,
            imageName: groupedFilm.imageName,
            filmName: groupedFilm.name,
            manufacturer: groupedFilm.manufacturer
        )
    }

    private var activeFormats: [GroupedFilm.FormatInfo] {
        let nonZero = groupedFilm.formats.filter { $0.quantity > 0 }
        return nonZero.isEmpty ? groupedFilm.formats : nonZero
    }
    
    // Consolidate formats by display name, summing quantities
    private var consolidatedFormats: [ConsolidatedFormatInfo] {
        var formatDict: [String: Int] = [:]
        var formatOrder: [String] = []
        
        for formatInfo in groupedFilm.formats where formatInfo.quantity > 0 {
            let displayName = formatInfo.formatDisplayName
            if formatDict[displayName] == nil {
                formatOrder.append(displayName)
                formatDict[displayName] = 0
            }
            formatDict[displayName]! += formatInfo.quantity
        }
        
        return formatOrder.map { displayName in
            ConsolidatedFormatInfo(formatDisplayName: displayName, quantity: formatDict[displayName]!)
        }
    }
    
    private struct ConsolidatedFormatInfo {
        let formatDisplayName: String
        let quantity: Int
    }
    
    private struct ExpiryChip: Hashable {
        let text: String
        let isExpired: Bool
        let sortDate: Date
    }
    
    private var allExpiryChips: [ExpiryChip] {
        var chipsDict: [String: ExpiryChip] = [:]
        let today = Date()
        
        for formatInfo in activeFormats {
            guard let expireDates = formatInfo.expireDate else { continue }
            for dateStr in expireDates where !dateStr.isEmpty {
                let formatted = FilmStock.formatExpireDate(dateStr)
                if let expiryDate = FilmStock.parseExpireDate(dateStr) {
                    chipsDict[formatted] = ExpiryChip(text: formatted, isExpired: expiryDate < today, sortDate: expiryDate)
                } else {
                    chipsDict[formatted] = ExpiryChip(text: formatted, isExpired: false, sortDate: .distantFuture)
                }
            }
        }
        
        return Array(chipsDict.values).sorted { $0.sortDate < $1.sortDate }
    }
    
    private var hasFrozenFilm: Bool {
        activeFormats.contains { $0.isFrozen }
    }
    
    private var hasFridgeFilm: Bool {
        guard settingsManager.enableFridge else { return false }
        return activeFormats.contains { $0.isFridge }
    }
    
    private var isExpired: Bool {
        activeFormats.contains { $0.expiredCount > 0 }
    }
    
    private func typeColor(for type: FilmStock.FilmType) -> Color {
        switch type {
        case .bw:
            return .gray
        case .color:
            return .orange
        case .slide:
            return .purple
        case .instant:
            return .blue
        }
    }
}
