//
//  ExportManager.swift
//  FilmStock
//
//  Exports the film inventory to JSON or CSV.
//

import Foundation
import SwiftData

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Export data shapes

struct ExportFilm: Codable {
    let manufacturer: String
    let name: String
    let type: String
    let iso: Int
    let format: String
    let customFormat: String?
    let quantity: Int
    let expiryDate: String?
    let isFrozen: Bool
    let exposures: Int?
    let comments: String?
    let addedAt: String?
}

struct ExportPayload: Codable {
    let exportedAt: String
    let appVersion: String
    let inventory: [ExportFilm]
}

// MARK: - Manager

@MainActor
class ExportManager {

    static let shared = ExportManager()
    private init() {}

    private let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }

    // MARK: - Fetch

    func buildPayload(context: ModelContext) throws -> ExportPayload {
        let myFilms = try context.fetch(FetchDescriptor<MyFilm>())

        // Read all values eagerly before leaving the fetch — avoids invalidated-backing crashes
        // on relationship faults that fire lazily.
        let inventory: [ExportFilm] = myFilms.compactMap { mf in
            // Guard against invalidated objects
            guard mf.quantity >= 0 else { return nil }
            let filmName  = mf.film?.name ?? ""
            let mfrName   = mf.film?.manufacturer?.name ?? ""
            let filmType  = mf.film?.type ?? ""
            let filmSpeed = mf.film?.filmSpeed ?? 0
            let expiry    = mf.expireDateArray?
                .map { FilmStock.formatExpireDate($0) }
                .joined(separator: ", ")
            return ExportFilm(
                manufacturer: mfrName,
                name: filmName,
                type: filmType,
                iso: filmSpeed,
                format: FilmStock.FilmFormat(rawValue: mf.format)?.displayName ?? mf.format,
                customFormat: mf.customFormatName,
                quantity: mf.quantity,
                expiryDate: expiry,
                isFrozen: mf.isFrozen ?? false,
                exposures: mf.exposures,
                comments: mf.comments,
                addedAt: mf.createdAt
            )
        }
        .sorted { ($0.manufacturer + $0.name) < ($1.manufacturer + $1.name) }

        return ExportPayload(
            exportedAt: iso8601.string(from: Date()),
            appVersion: appVersion,
            inventory: inventory
        )
    }

    // MARK: - JSON

    func exportJSON(context: ModelContext) throws -> URL {
        let payload = try buildPayload(context: context)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        let url  = temporaryURL(name: "FilmStock_Export", ext: "json")
        try data.write(to: url)
        return url
    }

    // MARK: - CSV  (three sheets in one zip-like structure via multiple files; we produce one multi-section CSV)

    func exportCSV(context: ModelContext) throws -> URL {
        let payload = try buildPayload(context: context)
        var lines: [String] = []

        lines.append("# INVENTORY")
        lines.append(csvRow(["Manufacturer","Film","Type","ISO","Format","Qty","Expiry","Frozen","Exposures","Comments","Added"]))
        for f in payload.inventory {
            lines.append(csvRow([
                f.manufacturer, f.name, f.type, "\(f.iso)",
                f.customFormat ?? f.format,
                "\(f.quantity)",
                f.expiryDate ?? "",
                f.isFrozen ? "Yes" : "No",
                f.exposures.map { "\($0)" } ?? "",
                f.comments ?? "",
                f.addedAt ?? ""
            ]))
        }

        let csv = lines.joined(separator: "\n")
        let url = temporaryURL(name: "FilmStock_Export", ext: "csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Import

    /// Parse a file (JSON or CSV) and return `FilmStock` DTOs ready to be fed to `addFilmStock`.
    /// Returns an array of rows and a list of non-fatal warnings.
    func importInventory(from url: URL) throws -> (rows: [FilmStock], warnings: [String]) {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "json": return try importJSON(from: url)
        case "csv":  return try importCSV(from: url)
        default:
            throw ImportError.unsupportedFormat(ext)
        }
    }

    private func importJSON(from url: URL) throws -> (rows: [FilmStock], warnings: [String]) {
        let data = try Data(contentsOf: url)
        // Try full ExportPayload first, then bare [ExportFilm] array
        if let payload = try? JSONDecoder().decode(ExportPayload.self, from: data) {
            return convert(payload.inventory)
        } else if let films = try? JSONDecoder().decode([ExportFilm].self, from: data) {
            return convert(films)
        }
        throw ImportError.parseError("Could not decode JSON as a FilmStock export.")
    }

    private func importCSV(from url: URL) throws -> (rows: [FilmStock], warnings: [String]) {
        let raw = try String(contentsOf: url, encoding: .utf8)
        var rows: [FilmStock] = []
        var warnings: [String] = []

        // Find the INVENTORY block: from "# INVENTORY" to the next "# " section or EOF
        let lines = raw.components(separatedBy: .newlines)
        var inInventory = false
        var headerParsed = false
        // Column index map populated from the header row
        var col: [String: Int] = [:]

        for (lineIdx, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# INVENTORY") {
                inInventory = true; headerParsed = false; continue
            }
            if inInventory && trimmed.hasPrefix("# ") { break } // next section
            if !inInventory || trimmed.isEmpty { continue }

            let fields = parseCSVLine(trimmed)

            if !headerParsed {
                // Build column map from header
                for (i, name) in fields.enumerated() {
                    col[name.lowercased().trimmingCharacters(in: .whitespaces)] = i
                }
                headerParsed = true
                continue
            }

            func field(_ name: String) -> String { fields[safe: col[name] ?? -1] ?? "" }

            let manufacturer = field("manufacturer")
            let name         = field("film")
            guard !manufacturer.isEmpty, !name.isEmpty else {
                warnings.append("Line \(lineIdx + 1): skipped (missing manufacturer or film name)")
                continue
            }

            // Map human-readable format display name back to FilmFormat
            let formatStr = field("format")
            let format    = FilmStock.FilmFormat.allCases.first {
                $0.displayName.lowercased() == formatStr.lowercased()
                || $0.rawValue.lowercased() == formatStr.lowercased()
            } ?? .other
            let customFormat: String? = format == .other ? formatStr : nil

            let type = FilmStock.FilmType.allCases.first {
                $0.rawValue.lowercased() == field("type").lowercased()
            } ?? .bw

            let iso = Int(field("iso")) ?? 0
            let qty = Int(field("qty")) ?? 1
            let expiry: [String]? = field("expiry").isEmpty ? nil : [field("expiry")]
            let frozen = field("frozen").lowercased() == "yes"
            let exposures = field("exposures").isEmpty ? nil : Int(field("exposures"))

            rows.append(FilmStock(
                id: UUID().uuidString,
                name: name,
                manufacturer: manufacturer,
                type: type,
                filmSpeed: iso,
                format: format,
                customFormatName: customFormat,
                quantity: qty,
                expireDate: expiry,
                comments: field("comments").isEmpty ? nil : field("comments"),
                isFrozen: frozen,
                exposures: exposures
            ))
        }

        if rows.isEmpty && !raw.contains("# INVENTORY") {
            throw ImportError.parseError("No INVENTORY section found in CSV.")
        }
        return (rows, warnings)
    }

    private func convert(_ films: [ExportFilm]) -> (rows: [FilmStock], warnings: [String]) {
        var rows: [FilmStock] = []
        var warnings: [String] = []
        for (i, f) in films.enumerated() {
            guard !f.manufacturer.isEmpty, !f.name.isEmpty else {
                warnings.append("Row \(i + 1): skipped (missing manufacturer or film name)")
                continue
            }
            let format = FilmStock.FilmFormat.allCases.first {
                $0.displayName.lowercased() == f.format.lowercased()
                || $0.rawValue.lowercased() == f.format.lowercased()
            } ?? .other
            let customFormat: String? = format == .other ? (f.customFormat ?? f.format) : nil
            let type = FilmStock.FilmType.allCases.first {
                $0.rawValue.lowercased() == f.type.lowercased()
            } ?? .bw
            let expiry: [String]? = f.expiryDate.flatMap {
                $0.isEmpty ? nil : $0.components(separatedBy: ", ").filter { !$0.isEmpty }
            }
            rows.append(FilmStock(
                id: UUID().uuidString,
                name: f.name,
                manufacturer: f.manufacturer,
                type: type,
                filmSpeed: f.iso,
                format: format,
                customFormatName: customFormat,
                quantity: f.quantity,
                expireDate: expiry,
                comments: f.comments,
                isFrozen: f.isFrozen,
                exposures: f.exposures,
                createdAt: f.addedAt
            ))
        }
        return (rows, warnings)
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var idx = line.startIndex
        while idx < line.endIndex {
            let c = line[idx]
            if c == "\"" {
                let next = line.index(after: idx)
                if inQuotes && next < line.endIndex && line[next] == "\"" {
                    current.append("\""); idx = line.index(after: next); continue
                }
                inQuotes.toggle()
            } else if c == "," && !inQuotes {
                fields.append(current); current = ""
            } else {
                current.append(c)
            }
            idx = line.index(after: idx)
        }
        fields.append(current)
        return fields
    }

    enum ImportError: LocalizedError {
        case unsupportedFormat(String)
        case parseError(String)
        var errorDescription: String? {
            switch self {
            case .unsupportedFormat(let ext): return "Unsupported file type: .\(ext). Use .json or .csv."
            case .parseError(let msg): return msg
            }
        }
    }

    // MARK: - Helpers

    private func csvRow(_ fields: [String]) -> String {
        fields.map { field in
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return escaped.contains(",") || escaped.contains("\"") || escaped.contains("\n")
                ? "\"\(escaped)\""
                : escaped
        }
        .joined(separator: ",")
    }

    // MARK: - Private

    private func temporaryURL(name: String, ext: String) -> URL {
        let dateStr = DateFormatter.localizedString(from: Date(),
                        dateStyle: .short, timeStyle: .none)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ".", with: "-")
        let filename = "\(name)_\(dateStr).\(ext)"
        return FileManager.default.temporaryDirectory.appendingPathComponent(filename)
    }
}
