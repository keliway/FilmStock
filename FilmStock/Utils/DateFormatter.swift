//
//  DateFormatter.swift
//  FilmStock
//
//  Date formatting utilities
//

import Foundation

extension FilmStock {
    static func parseExpireDate(_ dateString: String) -> Date? {
        // Handle YYYY
        if dateString.count == 4, let year = Int(dateString) {
            var components = DateComponents()
            components.year = year
            components.month = 12
            components.day = 31
            return Calendar.current.date(from: components)
        }

        // Handle MMYYYY (6 digits, no slash — from migrated data)
        if dateString.count == 6, dateString.allSatisfy(\.isNumber),
           let month = Int(dateString.prefix(2)),
           let year  = Int(dateString.suffix(4)),
           (1...12).contains(month) {
            var components = DateComponents()
            components.year  = year
            components.month = month
            components.day   = 1
            return Calendar.current.date(from: components)
        }

        // Handle MM/YYYY
        let parts = dateString.split(separator: "/")
        if parts.count == 2,
           let month = Int(parts[0]),
           let year = Int(parts[1]) {
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = 1
            return Calendar.current.date(from: components)
        }
        
        // Handle MM/DD/YYYY
        if parts.count == 3,
           let month = Int(parts[0]),
           let day = Int(parts[1]),
           let year = Int(parts[2]) {
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = day
            return Calendar.current.date(from: components)
        }
        
        return nil
    }
    
    static func formatExpireDate(_ dateString: String) -> String {
        if dateString.isEmpty { return "Unknown" }

        // Already in MM/YYYY format
        if dateString.contains("/") && dateString.count <= 7 {
            return dateString
        }

        // YYYY-only — keep as is
        if dateString.count == 4 {
            return dateString
        }

        // 6-digit MMYYYY (migrated data) — reformat with slash
        if dateString.count == 6, dateString.allSatisfy(\.isNumber) {
            let mm   = String(dateString.prefix(2))
            let yyyy = String(dateString.suffix(4))
            return "\(mm)/\(yyyy)"
        }

        // Fallback: parse and reformat
        if let date = parseExpireDate(dateString) {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/yyyy"
            return formatter.string(from: date)
        }

        return dateString
    }
}

