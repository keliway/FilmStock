//
//  StatisticsView.swift
//  FilmStock
//
//  Statistics view showing film collection insights
//

import SwiftUI
import SwiftData

struct StatisticsView: View {
    @EnvironmentObject var dataManager: FilmStockDataManager
    @ObservedObject private var settingsManager = SettingsManager.shared
    
    var body: some View {
        List {
            // Summary Section
            Section("stats.summary") {
                StatRow("stats.totalRolls", value: "\(totalRolls)")
                StatRow("stats.totalSheets", value: "\(totalSheets)")
                StatRow("stats.uniqueFilms", value: "\(uniqueFilmCount)")
                StatRow("stats.finishedFilms", value: "\(finishedFilmsCount)")
                StatRow("stats.expiredFilms", value: "\(expiredFilmsCount)")
                StatRow("stats.frozenFilms", value: "\(frozenFilmsCount)")
                if settingsManager.enableFridge {
                    StatRow("stats.fridgeFilms", value: "\(fridgeFilmsCount)")
                }
            }
            
            // By Type Section
            Section("stats.byType") {
                ForEach(FilmStock.FilmType.allCases, id: \.self) { type in
                    let count = rollsByType(type)
                    if count > 0 {
                        StatRow(verbatim: type.displayName, value: "\(count)")
                    }
                }
                if FilmStock.FilmType.allCases.allSatisfy({ rollsByType($0) == 0 }) {
                    Text("stats.noData")
                        .foregroundColor(.secondary)
                }
            }
            
            // By Format Section
            Section("stats.byFormat") {
                // Built-in roll formats
                ForEach(rollFormats, id: \.self) { format in
                    let count = rollsByFormat(format)
                    if count > 0 {
                        StatRow(verbatim: format.displayName, value: "\(count)")
                    }
                }
                
                // Large format sheets
                let sheetCount = totalSheets
                if sheetCount > 0 {
                    StatRow("stats.largeFormat", value: "\(sheetCount)")
                }
                
                // Unnamed "Other" format rolls
                let unnamedOtherCount = unnamedOtherRollsCount
                if unnamedOtherCount > 0 {
                    StatRow(verbatim: FilmStock.FilmFormat.other.displayName, value: "\(unnamedOtherCount)")
                }
                
                // Custom formats
                ForEach(customFormatsWithCounts, id: \.name) { formatData in
                    StatRow(verbatim: formatData.name, value: "\(formatData.count)")
                }
                
                if totalRolls == 0 && totalSheets == 0 {
                    Text("stats.noData")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("stats.title")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // Built-in roll formats (excludes large format and Other)
    private var rollFormats: [FilmStock.FilmFormat] {
        FilmStock.FilmFormat.allCases.filter { !$0.isSheetFormat && $0 != .other }
    }
    
    private var inStockFilms: [FilmStock] {
        dataManager.filmStocks.filter { $0.quantity > 0 }
    }
    
    private func unitCount(for film: FilmStock) -> Int {
        film.format.isSheetFormat ? 1 : film.quantity
    }
    
    private var totalRolls: Int {
        inStockFilms
            .filter { !$0.format.isSheetFormat }
            .reduce(0) { $0 + $1.quantity }
    }
    
    private var totalSheets: Int {
        inStockFilms
            .filter { $0.format.isSheetFormat }
            .reduce(0) { $0 + $1.quantity }
    }
    
    private var uniqueFilmCount: Int {
        Set(inStockFilms.map {
            "\($0.manufacturer.lowercased())\u{1F}\($0.name.lowercased())\u{1F}\($0.type.rawValue)\u{1F}\($0.filmSpeed)"
        }).count
    }
    
    private var finishedFilmsCount: Int {
        dataManager.getFinishedFilmsCount()
    }
    
    private var expiredFilmsCount: Int {
        let today = Date()
        return inStockFilms.reduce(0) { sum, film in
            guard let expireDates = film.expireDate, !expireDates.isEmpty else { return sum }
            let isExpired = expireDates.contains { dateString in
                guard let expireDate = FilmStock.parseExpireDate(dateString) else { return false }
                return expireDate < today
            }
            return isExpired ? sum + unitCount(for: film) : sum
        }
    }
    
    private var frozenFilmsCount: Int {
        inStockFilms
            .filter { $0.isFrozen }
            .reduce(0) { $0 + unitCount(for: $1) }
    }
    
    private var fridgeFilmsCount: Int {
        inStockFilms
            .filter { !$0.isFrozen && $0.isFridge }
            .reduce(0) { $0 + unitCount(for: $1) }
    }
    
    private func rollsByType(_ type: FilmStock.FilmType) -> Int {
        inStockFilms
            .filter { $0.type == type && !$0.format.isSheetFormat }
            .reduce(0) { $0 + $1.quantity }
    }
    
    private func rollsByFormat(_ format: FilmStock.FilmFormat) -> Int {
        inStockFilms
            .filter { $0.format == format && $0.customFormatName == nil }
            .reduce(0) { $0 + $1.quantity }
    }
    
    private var unnamedOtherRollsCount: Int {
        inStockFilms
            .filter { $0.format == .other && ($0.customFormatName?.isEmpty != false) }
            .reduce(0) { $0 + $1.quantity }
    }
    
    // Custom formats with their counts (case-insensitive grouping)
    private var customFormatsWithCounts: [(name: String, count: Int)] {
        var canonicalNames: [String: String] = [:]
        var formatCounts: [String: Int] = [:]
        for film in inStockFilms where film.format == .other {
            guard let rawName = film.customFormatName, !rawName.isEmpty else { continue }
            let key = rawName.lowercased()
            if canonicalNames[key] == nil {
                canonicalNames[key] = rawName
            }
            formatCounts[key, default: 0] += film.quantity
        }
        
        return formatCounts
            .filter { $0.value > 0 }
            .compactMap { key, count in
                guard let name = canonicalNames[key] else { return nil }
                return (name: name, count: count)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

struct StatRow: View {
    private let titleKey: LocalizedStringKey?
    private let verbatimTitle: String?
    let value: String
    
    init(_ titleKey: LocalizedStringKey, value: String) {
        self.titleKey = titleKey
        self.verbatimTitle = nil
        self.value = value
    }
    
    init(verbatim title: String, value: String) {
        self.titleKey = nil
        self.verbatimTitle = title
        self.value = value
    }
    
    var body: some View {
        HStack {
            if let verbatimTitle {
                Text(verbatim: verbatimTitle)
            } else if let titleKey {
                Text(titleKey)
            }
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    NavigationStack {
        StatisticsView()
    }
}
