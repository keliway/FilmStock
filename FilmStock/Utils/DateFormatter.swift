//
//  DateFormatter.swift
//  FilmStock
//
//  Date formatting utilities
//

import Foundation

extension FilmStock {
    private static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/yyyy"
        return formatter
    }()

    static func parseExpireDate(_ dateString: String) -> Date? {
        let trimmed = dateString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let calendar = Calendar.current

        // Handle YYYY (expires at the end of Dec 31 of that year)
        if trimmed.count == 4, trimmed.allSatisfy(\.isNumber), let year = Int(trimmed) {
            return calendar.date(from: DateComponents(year: year, month: 12, day: 31, hour: 23, minute: 59, second: 59))
        }

        // Handle MMYYYY (6 digits, no slash — from migrated/stored data)
        if trimmed.count == 6, trimmed.allSatisfy(\.isNumber),
           let month = Int(trimmed.prefix(2)),
           let year  = Int(trimmed.suffix(4)) {
            return endOfMonthDate(month: month, year: year, calendar: calendar)
        }

        // Handle MM/YYYY or MM/DD/YYYY
        let parts = trimmed.split(separator: "/")
        if parts.count == 2,
           let month = Int(parts[0]),
           let year = Int(parts[1]) {
            return endOfMonthDate(month: month, year: year, calendar: calendar)
        }

        if parts.count == 3,
           let month = Int(parts[0]),
           let day = Int(parts[1]),
           let year = Int(parts[2]),
           (1...12).contains(month),
           let firstOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
           let daysRange = calendar.range(of: .day, in: .month, for: firstOfMonth),
           daysRange.contains(day) {
            return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 23, minute: 59, second: 59))
        }

        return nil
    }

    private static func endOfMonthDate(month: Int, year: Int, calendar: Calendar) -> Date? {
        guard (1...12).contains(month),
              let firstOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let daysInMonth = calendar.range(of: .day, in: .month, for: firstOfMonth)?.count else {
            return nil
        }
        return calendar.date(from: DateComponents(year: year, month: month, day: daysInMonth, hour: 23, minute: 59, second: 59))
    }

    static func formatExpireDate(_ dateString: String) -> String {
        let trimmed = dateString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Unknown" }

        // YYYY-only — keep as is
        if trimmed.count == 4, trimmed.allSatisfy(\.isNumber) {
            return trimmed
        }

        // 6-digit MMYYYY (migrated/stored data) — reformat with slash
        if trimmed.count == 6, trimmed.allSatisfy(\.isNumber) {
            let mm   = String(trimmed.prefix(2))
            let yyyy = String(trimmed.suffix(4))
            return "\(mm)/\(yyyy)"
        }

        // M/YYYY or MM/YYYY — normalize with zero-padded month
        let parts = trimmed.split(separator: "/")
        if parts.count == 2,
           let month = Int(parts[0]),
           (1...12).contains(month),
           parts[1].count == 4,
           parts[1].allSatisfy(\.isNumber) {
            return String(format: "%02d/%@", month, String(parts[1]))
        }

        // Fallback: parse and reformat
        if let date = parseExpireDate(trimmed) {
            return monthYearFormatter.string(from: date)
        }

        return trimmed
    }
}
