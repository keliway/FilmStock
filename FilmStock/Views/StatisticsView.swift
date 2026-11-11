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
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        List {
            // Summary Section
            Section("stats.summary") {
                StatRow(label: "stats.totalRolls", value: "\(totalRolls)")
                StatRow(label: "stats.totalSheets", value: "\(totalSheets)")
                StatRow(label: "stats.uniqueFilms", value: "\(uniqueFilmCount)")
                StatRow(label: "stats.finishedFilms", value: "\(finishedFilmsCount)")
                StatRow(label: "stats.expiredFilms", value: "\(expiredFilmsCount)")
                StatRow(label: "stats.frozenFilms", value: "\(frozenFilmsCount)")
                if settingsManager.enableFridge {
                    StatRow(label: "stats.fridgeFilms", value: "\(fridgeFilmsCount)")
                }
            }
            
            // By Type Section
            Section("stats.byType") {
                ForEach(FilmStock.FilmType.allCases, id: \.self) { type in
                    let count = rollsByType(type)
                    if count > 0 {
                        StatRow(label: type.displayName, value: "\(count)")
                    }
                }
                if rollsByType(.bw) == 0 && rollsByType(.color) == 0 && 
                   rollsByType(.slide) == 0 && rollsByType(.instant) == 0 {
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
                        StatRow(label: format.displayName, value: "\(count)")
                    }
                }
                
                // Large format sheets
                let sheetCount = totalSheets
                if sheetCount > 0 {
                    StatRow(label: NSLocalizedString("stats.largeFormat", comment: ""), value: "\(sheetCount)")
                }
                
                // Custom formats
                ForEach(customFormatsWithCounts, id: \.name) { formatData in
                    StatRow(label: formatData.name, value: "\(formatData.count)")
                }
                
                if totalRolls == 0 && totalSheets == 0 && customFormatsWithCounts.isEmpty {
                    Text("stats.noData")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("stats.title")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // Roll formats (excludes large format)
    private var rollFormats: [FilmStock.FilmFormat] {
        [.thirtyFive, .oneTwenty, .oneTen, .oneTwentySeven, .twoTwenty]
    }
    
    // Sheet formats (large format)
    private var sheetFormats: [FilmStock.FilmFormat] {
        [.fourByFive, .fiveBySeven, .eightByTen]
    }
    
    private var inStockFilms: [FilmStock] {
        dataManager.filmStocks.filter { $0.quantity > 0 }
    }
    
    private var totalRolls: Int {
        inStockFilms
            .filter { !sheetFormats.contains($0.format) }
            .reduce(0) { $0 + $1.quantity }
    }
    
    private var totalSheets: Int {
        inStockFilms
            .filter { sheetFormats.contains($0.format) }
            .reduce(0) { $0 + $1.quantity }
    }
    
    private var uniqueFilmCount: Int {
        let uniqueFilms = Set(inStockFilms.map { "\($0.manufacturer)_\($0.name)" })
        return uniqueFilms.count
    }
    
    private var finishedFilmsCount: Int {
        dataManager.getFinishedFilmsCount()
    }
    
    private var expiredFilmsCount: Int {
        let today = Date()
        return inStockFilms.filter { film in
            guard let expireDates = film.expireDate, !expireDates.isEmpty else { return false }
            return expireDates.contains { dateString in
                guard let expireDate = FilmStock.parseExpireDate(dateString) else { return false }
                return expireDate < today
            }
        }.count
    }
    
    private var frozenFilmsCount: Int {
        inStockFilms.filter { $0.isFrozen }.count
    }
    
    private var fridgeFilmsCount: Int {
        inStockFilms.filter { !$0.isFrozen && $0.isFridge }.count
    }
    
    private func rollsByType(_ type: FilmStock.FilmType) -> Int {
        inStockFilms
            .filter { $0.type == type && !sheetFormats.contains($0.format) }
            .reduce(0) { $0 + $1.quantity }
    }
    
    private func rollsByFormat(_ format: FilmStock.FilmFormat) -> Int {
        inStockFilms
            .filter { $0.format == format && $0.customFormatName == nil }
            .reduce(0) { $0 + $1.quantity }
    }
    
    // Custom formats with their counts
    private var customFormatsWithCounts: [(name: String, count: Int)] {
        // Get all unique custom format names from the film stocks
        let customFormatFilms = inStockFilms.filter { 
            $0.format == .other && $0.customFormatName != nil && !$0.customFormatName!.isEmpty 
        }
        
        // Group by custom format name
        var formatCounts: [String: Int] = [:]
        for film in customFormatFilms {
            if let name = film.customFormatName {
                formatCounts[name, default: 0] += film.quantity
            }
        }
        
        // Return sorted by name, only those with count > 0
        return formatCounts
            .filter { $0.value > 0 }
            .map { (name: $0.key, count: $0.value) }
            .sorted { $0.name < $1.name }
    }
}

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(LocalizedStringKey(label))
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
