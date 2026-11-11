//
//  ExportManager.swift
//  FilmStock
//
//  Exports and imports film inventory, loaded rolls, finished rolls, and cameras to/from JSON or CSV.
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
    let isFridge: Bool?
    let exposures: Int?
    let comments: String?
    let addedAt: String?
}

struct ExportLoadedFilm: Codable, Identifiable {
    var id: String { "\(manufacturer)|\(name)|\(format)|\(camera ?? "")|\(loadedAt)" }
    let manufacturer: String
    let name: String
    let type: String
    let iso: Int
    let format: String
    let customFormat: String?
    let quantity: Int
    let shotAtISO: Int?
    let camera: String?
    let loadedAt: String
    let expiryDate: String?
    let isFrozen: Bool?
    let isFridge: Bool?
    let exposures: Int?
    let comments: String?
}

struct ExportFinishedFilm: Codable, Identifiable {
    var id: String { "\(manufacturer)|\(name)|\(format)|\(camera ?? "")|\(finishedAt)|\(loadedAt)" }
    let manufacturer: String
    let name: String
    let type: String
    let iso: Int
    let format: String
    let customFormat: String?
    let quantity: Int
    let shotAtISO: Int?
    let camera: String?
    let loadedAt: String
    let finishedAt: String
    let status: String?
    let developedAt: String?
    let expiryDate: String?
    let isFrozen: Bool?
    let isFridge: Bool?
    let exposures: Int?
    let comments: String?
}

struct ExportCamera: Codable, Identifiable {
    var id: String { name }
    let name: String
    let format: String?
    let customFormat: String?
}

struct ExportPayload: Codable {
    let exportedAt: String
    let appVersion: String
    let inventory: [ExportFilm]
    let loadedFilms: [ExportLoadedFilm]?
    let finishedFilms: [ExportFinishedFilm]?
    let cameras: [ExportCamera]?
}

struct ImportResult {
    let inventory: [FilmStock]
    let loadedFilms: [ExportLoadedFilm]
    let finishedFilms: [ExportFinishedFilm]
    let cameras: [ExportCamera]
    let warnings: [String]

    var isEmpty: Bool {
        inventory.isEmpty && loadedFilms.isEmpty && finishedFilms.isEmpty && cameras.isEmpty
    }
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

    private let iso8601Fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
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
        let loaded = try context.fetch(FetchDescriptor<LoadedFilm>(sortBy: [SortDescriptor(\.loadedAt, order: .reverse)]))
        let finished = try context.fetch(FetchDescriptor<FinishedFilm>(sortBy: [SortDescriptor(\.finishedAt, order: .reverse)]))
        let allCameras = try context.fetch(FetchDescriptor<Camera>(sortBy: [SortDescriptor(\.name)]))

        // Read all values eagerly before leaving the fetch — avoids invalidated-backing crashes
        // on relationship faults that fire lazily.
        let inventory: [ExportFilm] = myFilms.compactMap { mf in
            guard mf.quantity > 0 else { return nil }
            let filmName  = mf.film?.name ?? ""
            let mfrName   = mf.film?.manufacturer?.name ?? ""
            guard !filmName.isEmpty, !mfrName.isEmpty else { return nil }
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
                isFridge: mf.isFridge ?? false,
                exposures: mf.exposures,
                comments: mf.comments,
                addedAt: mf.createdAt
            )
        }
        .sorted { ($0.manufacturer + $0.name) < ($1.manufacturer + $1.name) }

        let loadedFilms: [ExportLoadedFilm] = loaded.compactMap { lf in
            guard let film = lf.film ?? lf.myFilm?.film else { return nil }
            let filmName = film.name
            let mfrName  = film.manufacturer?.name ?? ""
            guard !filmName.isEmpty, !mfrName.isEmpty else { return nil }
            let mf = lf.myFilm
            let expiry = mf?.expireDateArray?
                .map { FilmStock.formatExpireDate($0) }
                .joined(separator: ", ")
            let cameraName = lf.cameraName ?? lf.camera?.name
            return ExportLoadedFilm(
                manufacturer: mfrName,
                name: filmName,
                type: film.type,
                iso: film.filmSpeed,
                format: FilmStock.FilmFormat(rawValue: lf.format)?.displayName ?? lf.format,
                customFormat: mf?.customFormatName,
                quantity: max(1, lf.quantity),
                shotAtISO: lf.shotAtISO,
                camera: (cameraName?.isEmpty == true) ? nil : cameraName,
                loadedAt: iso8601.string(from: lf.loadedAt),
                expiryDate: expiry,
                isFrozen: mf?.isFrozen ?? false,
                isFridge: mf?.isFridge ?? false,
                exposures: mf?.exposures,
                comments: mf?.comments
            )
        }

        let finishedFilms: [ExportFinishedFilm] = finished.compactMap { ff in
            guard let film = ff.film ?? ff.myFilm?.film else { return nil }
            let filmName = film.name
            let mfrName  = film.manufacturer?.name ?? ""
            guard !filmName.isEmpty, !mfrName.isEmpty else { return nil }
            let mf = ff.myFilm
            let expiry = mf?.expireDateArray?
                .map { FilmStock.formatExpireDate($0) }
                .joined(separator: ", ")
            return ExportFinishedFilm(
                manufacturer: mfrName,
                name: filmName,
                type: film.type,
                iso: film.filmSpeed,
                format: FilmStock.FilmFormat(rawValue: ff.format)?.displayName ?? ff.format,
                customFormat: mf?.customFormatName,
                quantity: max(1, ff.quantity),
                shotAtISO: ff.shotAtISO,
                camera: (ff.cameraName?.isEmpty == true) ? nil : ff.cameraName,
                loadedAt: iso8601.string(from: ff.loadedAt),
                finishedAt: iso8601.string(from: ff.finishedAt),
                status: ff.status ?? FinishedFilmStatus.toDevelop.rawValue,
                developedAt: ff.developedAt.map { iso8601.string(from: $0) },
                expiryDate: expiry,
                isFrozen: mf?.isFrozen ?? false,
                isFridge: mf?.isFridge ?? false,
                exposures: mf?.exposures,
                comments: mf?.comments
            )
        }

        let cameras: [ExportCamera] = allCameras.compactMap { cam in
            let trimmed = cam.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let formatDisplay: String? = {
                guard !cam.format.isEmpty else { return nil }
                return FilmStock.FilmFormat(rawValue: cam.format)?.displayName ?? cam.format
            }()
            return ExportCamera(
                name: trimmed,
                format: formatDisplay,
                customFormat: (cam.customFormatName?.isEmpty == true) ? nil : cam.customFormatName
            )
        }

        return ExportPayload(
            exportedAt: iso8601.string(from: Date()),
            appVersion: appVersion,
            inventory: inventory,
            loadedFilms: loadedFilms,
            finishedFilms: finishedFilms,
            cameras: cameras
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

    // MARK: - CSV (multi-section CSV)

    func exportCSV(context: ModelContext) throws -> URL {
        let payload = try buildPayload(context: context)
        var lines: [String] = []

        lines.append("# INVENTORY")
        lines.append(csvRow(["Manufacturer","Film","Type","ISO","Format","Qty","Expiry","Frozen","Fridge","Exposures","Comments","Added"]))
        for f in payload.inventory {
            lines.append(csvRow([
                f.manufacturer, f.name, f.type, "\(f.iso)",
                f.customFormat ?? f.format,
                "\(f.quantity)",
                f.expiryDate ?? "",
                f.isFrozen ? "Yes" : "No",
                (f.isFridge ?? false) ? "Yes" : "No",
                formatExposuresForCSV(f.exposures),
                f.comments ?? "",
                f.addedAt ?? ""
            ]))
        }

        lines.append("")
        lines.append("# LOADED FILMS")
        lines.append(csvRow(["Manufacturer","Film","Type","ISO","Format","Qty","ShotAtISO","Camera","LoadedAt","Expiry","Frozen","Fridge","Exposures","Comments"]))
        for lf in payload.loadedFilms ?? [] {
            lines.append(csvRow([
                lf.manufacturer, lf.name, lf.type, "\(lf.iso)",
                lf.customFormat ?? lf.format,
                "\(lf.quantity)",
                lf.shotAtISO.map { "\($0)" } ?? "",
                lf.camera ?? "",
                lf.loadedAt,
                lf.expiryDate ?? "",
                (lf.isFrozen ?? false) ? "Yes" : "No",
                (lf.isFridge ?? false) ? "Yes" : "No",
                formatExposuresForCSV(lf.exposures),
                lf.comments ?? ""
            ]))
        }

        lines.append("")
        lines.append("# FINISHED FILMS")
        lines.append(csvRow(["Manufacturer","Film","Type","ISO","Format","Qty","ShotAtISO","Camera","LoadedAt","FinishedAt","Status","DevelopedAt","Expiry","Frozen","Fridge","Exposures","Comments"]))
        for ff in payload.finishedFilms ?? [] {
            lines.append(csvRow([
                ff.manufacturer, ff.name, ff.type, "\(ff.iso)",
                ff.customFormat ?? ff.format,
                "\(ff.quantity)",
                ff.shotAtISO.map { "\($0)" } ?? "",
                ff.camera ?? "",
                ff.loadedAt,
                ff.finishedAt,
                ff.status ?? FinishedFilmStatus.toDevelop.rawValue,
                ff.developedAt ?? "",
                ff.expiryDate ?? "",
                (ff.isFrozen ?? false) ? "Yes" : "No",
                (ff.isFridge ?? false) ? "Yes" : "No",
                formatExposuresForCSV(ff.exposures),
                ff.comments ?? ""
            ]))
        }

        lines.append("")
        lines.append("# CAMERAS")
        lines.append(csvRow(["Name","Format"]))
        for cam in payload.cameras ?? [] {
            lines.append(csvRow([
                cam.name,
                cam.customFormat ?? cam.format ?? ""
            ]))
        }

        let csv = lines.joined(separator: "\n")
        let url = temporaryURL(name: "FilmStock_Export", ext: "csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Import

    /// Parse a file (JSON or CSV) and return an `ImportResult` ready to be committed via `FilmStockDataManager`.
    func importAll(from url: URL) throws -> ImportResult {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "json": return try importJSON(from: url)
        case "csv":  return try importCSV(from: url)
        default:
            throw ImportError.unsupportedFormat(ext)
        }
    }

    private func importJSON(from url: URL) throws -> ImportResult {
        let data = try Data(contentsOf: url)
        // Try full ExportPayload first, then bare [ExportFilm] array for backward compatibility
        if let payload = try? JSONDecoder().decode(ExportPayload.self, from: data) {
            let (invRows, invWarnings) = convertInventory(payload.inventory)
            let (loadedRows, loadedWarnings) = validateLoadedFilms(payload.loadedFilms ?? [])
            let (finishedRows, finishedWarnings) = validateFinishedFilms(payload.finishedFilms ?? [])
            let (cameraRows, cameraWarnings) = validateCameras(payload.cameras ?? [])
            return ImportResult(
                inventory: invRows,
                loadedFilms: loadedRows,
                finishedFilms: finishedRows,
                cameras: cameraRows,
                warnings: invWarnings + loadedWarnings + finishedWarnings + cameraWarnings
            )
        } else if let films = try? JSONDecoder().decode([ExportFilm].self, from: data) {
            let (invRows, invWarnings) = convertInventory(films)
            return ImportResult(
                inventory: invRows,
                loadedFilms: [],
                finishedFilms: [],
                cameras: [],
                warnings: invWarnings
            )
        }
        throw ImportError.parseError("Could not decode JSON as a FilmStock export.")
    }

    private enum CSVSection {
        case none
        case inventory
        case loadedFilms
        case finishedFilms
        case cameras
    }

    private func importCSV(from url: URL) throws -> ImportResult {
        let raw = try String(contentsOf: url, encoding: .utf8)
        var inventoryRows: [FilmStock] = []
        var loadedRows: [ExportLoadedFilm] = []
        var finishedRows: [ExportFinishedFilm] = []
        var cameraRows: [ExportCamera] = []
        var warnings: [String] = []

        let lines = raw.components(separatedBy: .newlines)
        var section: CSVSection = .none
        var headerParsed = false
        var col: [String: Int] = [:]
        var sawKnownSection = false

        for (lineIdx, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            if trimmed.hasPrefix("#") {
                let upper = trimmed.uppercased()
                if upper.hasPrefix("# INVENTORY") {
                    section = .inventory
                    sawKnownSection = true
                } else if upper.hasPrefix("# LOADED FILMS") || upper.hasPrefix("# LOADED") {
                    section = .loadedFilms
                    sawKnownSection = true
                } else if upper.hasPrefix("# FINISHED FILMS") || upper.hasPrefix("# FINISHED") {
                    section = .finishedFilms
                    sawKnownSection = true
                } else if upper.hasPrefix("# CAMERAS") || upper.hasPrefix("# CAMERA") {
                    section = .cameras
                    sawKnownSection = true
                } else {
                    section = .none
                }
                headerParsed = false
                col = [:]
                continue
            }

            guard section != .none else { continue }

            let fields = parseCSVLine(trimmed)

            if !headerParsed {
                for (i, name) in fields.enumerated() {
                    col[name.lowercased().trimmingCharacters(in: .whitespaces)] = i
                }
                headerParsed = true
                continue
            }

            func field(_ name: String) -> String {
                (fields[safe: col[name] ?? -1] ?? "").trimmingCharacters(in: .whitespaces)
            }

            switch section {
            case .none:
                break

            case .inventory:
                let manufacturer = field("manufacturer")
                let name         = field("film")
                guard !manufacturer.isEmpty, !name.isEmpty else {
                    warnings.append("Line \(lineIdx + 1): skipped inventory row (missing manufacturer or film name)")
                    continue
                }
                let (format, customFormat) = Self.resolveFormat(formatStr: field("format"), explicitCustom: nil)
                let type = Self.resolveFilmType(field("type"))
                let iso = Int(field("iso")) ?? 0
                let qty = max(1, Int(field("qty")) ?? 1)
                let expiry = Self.parseExpiryList(field("expiry"))
                let frozen = field("frozen").lowercased() == "yes" || field("frozen").lowercased() == "true"
                let fridge = field("fridge").lowercased() == "yes" || field("fridge").lowercased() == "true"
                let exposures = Self.parseExposures(field("exposures"))
                let comments = field("comments").isEmpty ? nil : field("comments")
                let added = field("added").isEmpty ? nil : field("added")

                inventoryRows.append(FilmStock(
                    id: UUID().uuidString,
                    name: name,
                    manufacturer: manufacturer,
                    type: type,
                    filmSpeed: iso,
                    format: format,
                    customFormatName: customFormat,
                    quantity: qty,
                    expireDate: expiry,
                    comments: comments,
                    isFrozen: frozen,
                    isFridge: fridge,
                    exposures: exposures,
                    createdAt: added
                ))

            case .loadedFilms:
                let manufacturer = field("manufacturer")
                let name         = field("film")
                guard !manufacturer.isEmpty, !name.isEmpty else {
                    warnings.append("Line \(lineIdx + 1): skipped loaded film row (missing manufacturer or film name)")
                    continue
                }
                let formatStr = field("format")
                let (format, customFormat) = Self.resolveFormat(formatStr: formatStr, explicitCustom: nil)
                let type = Self.resolveFilmType(field("type"))
                let iso = Int(field("iso")) ?? 0
                let qty = max(1, Int(field("qty")) ?? 1)
                let shotAtISO = Int(field("shotatiso"))
                let camera = field("camera").isEmpty ? nil : field("camera")
                let loadedAt = field("loadedat").isEmpty ? iso8601.string(from: Date()) : field("loadedat")
                let expiry = field("expiry").isEmpty ? nil : field("expiry")
                let frozen = field("frozen").lowercased() == "yes" || field("frozen").lowercased() == "true"
                let fridge = field("fridge").lowercased() == "yes" || field("fridge").lowercased() == "true"
                let exposures = Self.parseExposures(field("exposures"))
                let comments = field("comments").isEmpty ? nil : field("comments")

                loadedRows.append(ExportLoadedFilm(
                    manufacturer: manufacturer,
                    name: name,
                    type: type.rawValue,
                    iso: iso,
                    format: format.displayName,
                    customFormat: customFormat,
                    quantity: qty,
                    shotAtISO: shotAtISO,
                    camera: camera,
                    loadedAt: loadedAt,
                    expiryDate: expiry,
                    isFrozen: frozen,
                    isFridge: fridge,
                    exposures: exposures,
                    comments: comments
                ))

            case .finishedFilms:
                let manufacturer = field("manufacturer")
                let name         = field("film")
                guard !manufacturer.isEmpty, !name.isEmpty else {
                    warnings.append("Line \(lineIdx + 1): skipped finished film row (missing manufacturer or film name)")
                    continue
                }
                let formatStr = field("format")
                let (format, customFormat) = Self.resolveFormat(formatStr: formatStr, explicitCustom: nil)
                let type = Self.resolveFilmType(field("type"))
                let iso = Int(field("iso")) ?? 0
                let qty = max(1, Int(field("qty")) ?? 1)
                let shotAtISO = Int(field("shotatiso"))
                let camera = field("camera").isEmpty ? nil : field("camera")
                let loadedAt = field("loadedat").isEmpty ? iso8601.string(from: Date()) : field("loadedat")
                let finishedAt = field("finishedat").isEmpty ? iso8601.string(from: Date()) : field("finishedat")
                let status = Self.normalizeStatus(field("status"))
                let developedAt = field("developedat").isEmpty ? nil : field("developedat")
                let expiry = field("expiry").isEmpty ? nil : field("expiry")
                let frozen = field("frozen").lowercased() == "yes" || field("frozen").lowercased() == "true"
                let fridge = field("fridge").lowercased() == "yes" || field("fridge").lowercased() == "true"
                let exposures = Self.parseExposures(field("exposures"))
                let comments = field("comments").isEmpty ? nil : field("comments")

                finishedRows.append(ExportFinishedFilm(
                    manufacturer: manufacturer,
                    name: name,
                    type: type.rawValue,
                    iso: iso,
                    format: format.displayName,
                    customFormat: customFormat,
                    quantity: qty,
                    shotAtISO: shotAtISO,
                    camera: camera,
                    loadedAt: loadedAt,
                    finishedAt: finishedAt,
                    status: status,
                    developedAt: developedAt,
                    expiryDate: expiry,
                    isFrozen: frozen,
                    isFridge: fridge,
                    exposures: exposures,
                    comments: comments
                ))

            case .cameras:
                let camName = field("name")
                guard !camName.isEmpty else {
                    warnings.append("Line \(lineIdx + 1): skipped camera row (missing name)")
                    continue
                }
                let formatStr = field("format")
                if formatStr.isEmpty {
                    cameraRows.append(ExportCamera(name: camName, format: nil, customFormat: nil))
                } else {
                    let (fmt, customFmt) = Self.resolveFormat(formatStr: formatStr, explicitCustom: nil)
                    cameraRows.append(ExportCamera(
                        name: camName,
                        format: fmt.displayName,
                        customFormat: customFmt
                    ))
                }
            }
        }

        if !sawKnownSection {
            throw ImportError.parseError("No valid FilmStock CSV sections found.")
        }

        return ImportResult(
            inventory: inventoryRows,
            loadedFilms: loadedRows,
            finishedFilms: finishedRows,
            cameras: cameraRows,
            warnings: warnings
        )
    }

    // MARK: - Conversion & Validation Helpers

    private func convertInventory(_ films: [ExportFilm]) -> (rows: [FilmStock], warnings: [String]) {
        var rows: [FilmStock] = []
        var warnings: [String] = []
        for (i, f) in films.enumerated() {
            guard !f.manufacturer.isEmpty, !f.name.isEmpty else {
                warnings.append("Inventory row \(i + 1): skipped (missing manufacturer or film name)")
                continue
            }
            let (format, customFormat) = Self.resolveFormat(formatStr: f.format, explicitCustom: f.customFormat)
            let type = Self.resolveFilmType(f.type)
            let expiry = Self.parseExpiryList(f.expiryDate)
            rows.append(FilmStock(
                id: UUID().uuidString,
                name: f.name,
                manufacturer: f.manufacturer,
                type: type,
                filmSpeed: f.iso,
                format: format,
                customFormatName: customFormat,
                quantity: max(1, f.quantity),
                expireDate: expiry,
                comments: f.comments,
                isFrozen: f.isFrozen,
                isFridge: f.isFridge ?? false,
                exposures: f.exposures,
                createdAt: f.addedAt
            ))
        }
        return (rows, warnings)
    }

    private func validateLoadedFilms(_ items: [ExportLoadedFilm]) -> (rows: [ExportLoadedFilm], warnings: [String]) {
        var rows: [ExportLoadedFilm] = []
        var warnings: [String] = []
        for (i, item) in items.enumerated() {
            guard !item.manufacturer.isEmpty, !item.name.isEmpty else {
                warnings.append("Loaded film \(i + 1): skipped (missing manufacturer or film name)")
                continue
            }
            rows.append(item)
        }
        return (rows, warnings)
    }

    private func validateFinishedFilms(_ items: [ExportFinishedFilm]) -> (rows: [ExportFinishedFilm], warnings: [String]) {
        var rows: [ExportFinishedFilm] = []
        var warnings: [String] = []
        for (i, item) in items.enumerated() {
            guard !item.manufacturer.isEmpty, !item.name.isEmpty else {
                warnings.append("Finished film \(i + 1): skipped (missing manufacturer or film name)")
                continue
            }
            rows.append(item)
        }
        return (rows, warnings)
    }

    private func validateCameras(_ items: [ExportCamera]) -> (rows: [ExportCamera], warnings: [String]) {
        var rows: [ExportCamera] = []
        var warnings: [String] = []
        for (i, item) in items.enumerated() {
            let trimmed = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                warnings.append("Camera \(i + 1): skipped (missing camera name)")
                continue
            }
            rows.append(item)
        }
        return (rows, warnings)
    }

    static func resolveFormat(formatStr: String, explicitCustom: String?) -> (FilmStock.FilmFormat, String?) {
        let trimmed = formatStr.trimmingCharacters(in: .whitespacesAndNewlines)
        let matched = FilmStock.FilmFormat.allCases.first {
            $0.displayName.lowercased() == trimmed.lowercased()
            || $0.rawValue.lowercased() == trimmed.lowercased()
        }
        if let matched, matched != .other {
            return (matched, nil)
        }
        let custom = (explicitCustom?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
            ?? (trimmed.isEmpty || trimmed.lowercased() == "other" ? nil : trimmed)
        return (.other, custom)
    }

    static func resolveFilmType(_ raw: String) -> FilmStock.FilmType {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return FilmStock.FilmType.allCases.first {
            $0.rawValue.lowercased() == trimmed.lowercased()
            || $0.displayName.lowercased() == trimmed.lowercased()
        } ?? .bw
    }

    static func parseExpiryList(_ raw: String?) -> [String]? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        let parts = raw.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts
    }

    static func normalizeStatus(_ raw: String?) -> String {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return FinishedFilmStatus.toDevelop.rawValue
        }
        switch raw.lowercased() {
        case "todevelop", "to develop", "to_develop", "ready for development":
            return FinishedFilmStatus.toDevelop.rawValue
        case "indevelopment", "in development", "in_development", "developing":
            return FinishedFilmStatus.inDevelopment.rawValue
        case "developed", "done":
            return FinishedFilmStatus.developed.rawValue
        default:
            return FinishedFilmStatus(rawValue: raw)?.rawValue ?? FinishedFilmStatus.toDevelop.rawValue
        }
    }

    func parseISO8601Date(_ raw: String?) -> Date? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        if let d = iso8601Fractional.date(from: raw) { return d }
        if let d = iso8601.date(from: raw) { return d }
        let fallback = DateFormatter()
        fallback.locale = Locale(identifier: "en_US_POSIX")
        for fmt in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd"] {
            fallback.dateFormat = fmt
            if let d = fallback.date(from: raw) { return d }
        }
        return nil
    }

    private func formatExposuresForCSV(_ exposures: Int?) -> String {
        guard let exposures else { return "" }
        if exposures == kBulkRollExposures { return "100ft" }
        return "\(exposures)"
    }

    private static func parseExposures(_ raw: String) -> Int? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }
        if trimmed == "100ft" || trimmed == "-2" {
            return kBulkRollExposures
        }
        return Int(trimmed)
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
