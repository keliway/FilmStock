//
//  ImageStorage.swift
//  FilmStock
//
//  Utility for storing and retrieving user-uploaded images
//

import UIKit
import Foundation

class ImageStorage {
    static let shared = ImageStorage()
    
    private let userImagesDirectory: URL
    private let appGroupID = "group.app.halbe.no.FilmStock"
    
    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        userImagesDirectory = documentsPath.appendingPathComponent("UserImages", isDirectory: true)
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: userImagesDirectory.path) {
            try? FileManager.default.createDirectory(at: userImagesDirectory, withIntermediateDirectories: true)
        }
    }
    
    /// Get the App Group container URL for shared images
    private var appGroupContainer: URL? {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }
    
    /// Copy default images from bundle to App Group container for widget access
    /// This is called once on app launch to make images available to the widget extension
    func copyDefaultImagesToAppGroup() {
        // Check if images have already been copied
        let hasCopiedImagesKey = "hasCopiedDefaultImagesToAppGroup_v3" // Incremented to force re-copy
        
        // Clear old flags to force re-copy
        UserDefaults.standard.removeObject(forKey: "hasCopiedDefaultImagesToAppGroup")
        UserDefaults.standard.removeObject(forKey: "hasCopiedDefaultImagesToAppGroup_v2")
        
        if UserDefaults.standard.bool(forKey: hasCopiedImagesKey) {
            return // Already copied
        }
        
        guard let containerURL = appGroupContainer else {
            return
        }
        
        let destinationImagesURL = containerURL.appendingPathComponent("DefaultImages", isDirectory: true)
        
        // Create destination directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: destinationImagesURL.path) {
            try? FileManager.default.createDirectory(at: destinationImagesURL, withIntermediateDirectories: true)
        }
        
        // Get all png files from the bundle root (new format: manufacturer_filmname.png)
        let allImagePaths = Bundle.main.paths(forResourcesOfType: "png", inDirectory: nil)
        
        // Copy each image to the appropriate manufacturer directory
        for imagePath in allImagePaths {
            let imageURL = URL(fileURLWithPath: imagePath)
            let fileName = imageURL.lastPathComponent
            let filenameWithoutExt = imageURL.deletingPathExtension().lastPathComponent
            
            // Parse manufacturer_filmname format
            if let underscoreIndex = filenameWithoutExt.firstIndex(of: "_") {
                let manufacturerName = String(filenameWithoutExt[..<underscoreIndex])
                
                let destinationManufacturerURL = destinationImagesURL.appendingPathComponent(manufacturerName, isDirectory: true)
                
                if !FileManager.default.fileExists(atPath: destinationManufacturerURL.path) {
                    try? FileManager.default.createDirectory(at: destinationManufacturerURL, withIntermediateDirectories: true)
                }
                
                // Save as manufacturer_filmname.png in the manufacturer subdirectory
                let destinationFile = destinationManufacturerURL.appendingPathComponent(fileName)
                
                if !FileManager.default.fileExists(atPath: destinationFile.path),
                   let imageData = try? Data(contentsOf: imageURL) {
                    try? imageData.write(to: destinationFile)
                }
            }
        }
        
        // Also copy manufacturers.json to App Group for widget access
        if let manufacturersURL = Bundle.main.url(forResource: "manufacturers", withExtension: "json"),
           let jsonData = try? Data(contentsOf: manufacturersURL) {
            let destinationJSON = containerURL.appendingPathComponent("manufacturers.json")
            try? jsonData.write(to: destinationJSON)
        }
        
        // Mark as copied
        UserDefaults.standard.set(true, forKey: hasCopiedImagesKey)
    }
    
    // Helper struct for decoding manufacturers.json
    struct FilmInfo: Codable {
        let filename: String
        let speed: Int?
        let type: String?
        let aliases: [String]
        let dx: [String]

        enum CodingKeys: String, CodingKey {
            case filename, speed, type, aliases, dx
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            filename = try container.decode(String.self, forKey: .filename)
            speed = try container.decodeIfPresent(Int.self, forKey: .speed)
            type = try container.decodeIfPresent(String.self, forKey: .type)
            aliases = try container.decodeIfPresent([String].self, forKey: .aliases) ?? []
            dx = try container.decodeIfPresent([String].self, forKey: .dx) ?? []
        }
    }

    struct DXFilmMatch: Identifiable, Hashable {
        var id: String { "\(manufacturer)|\(filename)" }
        let manufacturer: String
        let filename: String
        let displayName: String
        let speed: Int?
        let type: String?
    }

    struct PackageBarcodeMatch {
        let manufacturer: String
        let filename: String?
        let displayName: String
        let speed: Int?
        let type: String?
        let format: FilmStock.FilmFormat
        let quantity: Int
    }
    
    struct ManufacturerInfo: Codable {
        let name: String
        var films: [FilmInfo]
    }
    
    struct ManufacturersDataWrapper: Codable {
        var manufacturers: [ManufacturerInfo]
    }
    
    // Result type for film detection
    struct FilmMetadata {
        let filmSpeed: Int?
        let type: String?
        let hasImage: Bool
    }
    
    // Helper function to get common image names for a manufacturer
    // This is a fallback when we can't enumerate - we try common film names
    private func getCommonImageNames(for manufacturer: String) -> [String] {
        // This is a simplified list - in practice, you might want to load this from a JSON file
        // or use a more comprehensive list based on your actual film catalog
        let commonNames: [String: [String]] = [
            "Agfa": ["agfaortho25", "apx400"],
            "Ferrania": ["P30"],
            "Foma": ["fomapan100", "fomapan200", "fomapan400", "Ortho400", "Pan100"],
            "Fujifilm": ["fp100c45", "neopan1600", "neopan400", "npc160", "pro160s", "Pro400h", "Provia100F", "provia400f", "xtra400"],
            "Harman": ["Phoenix200"],
            "Ilford": ["Delta100", "Delta3200", "Delta400", "FP4", "HP5", "PanF", "XP2"],
            "Kentmere": ["Pan400"],
            "Kodak": ["bw400cn", "doublex", "ektachrome160t", "ektachrome64t", "ektapress100", "Ektar100", "Gold200", "Kodacolor200", "plusx", "portra100t", "Portra160", "portra160nc", "portra160vc", "Portra400", "portra400bw", "portra400nc", "Portra800", "techpan", "TMAX100", "tmax400", "trix320", "TriX400", "Vericolor160", "Vision200T", "Vision250D"],
            "NoColor": ["no10"],
            "Rollei": ["rpx100", "rpx25", "rpx400", "Superpan200"]
        ]
        
        return commonNames[manufacturer] ?? []
    }
    
    
    /// Save an image for a specific film
    /// - Parameters:
    ///   - image: The image to save
    ///   - manufacturer: The manufacturer name
    ///   - filmName: The film name
    /// - Returns: The filename (without extension) that can be stored in the Film model's imageName property
    @discardableResult
    func saveImage(_ image: UIImage, forManufacturer manufacturer: String, filmName: String) -> String? {
        // Create manufacturer subdirectory
        let manufacturerDir = userImagesDirectory.appendingPathComponent(manufacturer, isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: manufacturerDir.path) {
            try? FileManager.default.createDirectory(at: manufacturerDir, withIntermediateDirectories: true)
        }
        
        // Generate filename from film name (sanitize)
        let sanitizedFilmName = filmName
            .replacingOccurrences(of: "[^a-zA-Z0-9]", with: "", options: .regularExpression)
            .lowercased()
        
        let filename = "\(sanitizedFilmName)_\(UUID().uuidString.prefix(8))"
        let fileURL = manufacturerDir.appendingPathComponent("\(filename).jpg")
        
        // Convert to JPEG with high quality for widget display (95% quality)
        // Higher quality ensures crisp display on high-DPI screens (@2x, @3x)
        guard let imageData = image.jpegData(compressionQuality: 0.95) else {
            return nil
        }
        
        // Save image to Documents directory
        do {
            try imageData.write(to: fileURL)
            
            // Also save to App Group container for widget access
            if let containerURL = appGroupContainer {
                let appGroupUserImagesDir = containerURL.appendingPathComponent("UserImages", isDirectory: true)
                let appGroupManufacturerDir = appGroupUserImagesDir.appendingPathComponent(manufacturer, isDirectory: true)
                
                if !FileManager.default.fileExists(atPath: appGroupManufacturerDir.path) {
                    try? FileManager.default.createDirectory(at: appGroupManufacturerDir, withIntermediateDirectories: true)
                }
                
                let appGroupFileURL = appGroupManufacturerDir.appendingPathComponent("\(filename).jpg")
                try? imageData.write(to: appGroupFileURL)
            }
            
            return filename
        } catch {
            return nil
        }
    }
    
    /// Load an image by filename
    /// - Parameters:
    ///   - filename: The filename (without extension) stored in imageName
    ///   - manufacturer: The manufacturer name
    /// - Returns: The UIImage if found, nil otherwise
    func loadImage(filename: String, manufacturer: String) -> UIImage? {
        let manufacturerDir = userImagesDirectory.appendingPathComponent(manufacturer, isDirectory: true)
        let fileURL = manufacturerDir.appendingPathComponent("\(filename).jpg")
        
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let imageData = try? Data(contentsOf: fileURL),
              let image = UIImage(data: imageData) else {
            return nil
        }
        
        return image
    }
    
    /// Delete an image by filename
    /// - Parameters:
    ///   - filename: The filename (without extension)
    ///   - manufacturer: The manufacturer name
    func deleteImage(filename: String, manufacturer: String) {
        let manufacturerDir = userImagesDirectory.appendingPathComponent(manufacturer, isDirectory: true)
        let fileURL = manufacturerDir.appendingPathComponent("\(filename).jpg")
        
        try? FileManager.default.removeItem(at: fileURL)
        
        // Also delete from App Group container
        if let containerURL = appGroupContainer {
            let appGroupUserImagesDir = containerURL.appendingPathComponent("UserImages", isDirectory: true)
            let appGroupManufacturerDir = appGroupUserImagesDir.appendingPathComponent(manufacturer, isDirectory: true)
            let appGroupFileURL = appGroupManufacturerDir.appendingPathComponent("\(filename).jpg")
            try? FileManager.default.removeItem(at: appGroupFileURL)
            
            // Clean up empty manufacturer directory in App Group
            if let contents = try? FileManager.default.contentsOfDirectory(at: appGroupManufacturerDir, includingPropertiesForKeys: nil),
               contents.isEmpty {
                try? FileManager.default.removeItem(at: appGroupManufacturerDir)
            }
        }
        
        // Clean up empty manufacturer directory
        if let contents = try? FileManager.default.contentsOfDirectory(at: manufacturerDir, includingPropertiesForKeys: nil),
           contents.isEmpty {
            try? FileManager.default.removeItem(at: manufacturerDir)
        }
    }
    
    /// Check if a default image exists for a film
    /// - Parameters:
    ///   - filmName: The film name
    ///   - manufacturer: The manufacturer name
    /// - Returns: True if a default image exists in the bundle
    func hasDefaultImage(filmName: String, manufacturer: String) -> Bool {
        return loadDefaultImage(filmName: filmName, manufacturer: manufacturer) != nil
    }
    
    /// Load the default image for a film from the bundle
    /// Images are now in format: manufacturer_filmname.png
    /// Matching is case-insensitive and handles spaces/special characters
    /// - Parameters:
    ///   - filmName: The film name (user input, can be any case or format)
    ///   - manufacturer: The manufacturer name (user input, can be any case)
    /// - Returns: The UIImage if found, nil otherwise
    func loadDefaultImage(filmName: String, manufacturer: String) -> UIImage? {
        // Load manufacturers.json to get film name variations
        guard let manufacturersURL = Bundle.main.url(forResource: "manufacturers", withExtension: "json"),
              let manufacturersData = try? Data(contentsOf: manufacturersURL),
              let manufacturersWrapper = try? JSONDecoder().decode(ManufacturersDataWrapper.self, from: manufacturersData) else {
            return loadDefaultImageDirect(filmName: filmName, manufacturer: manufacturer)
        }
        
        // Find the manufacturer in the JSON (case-insensitive)
        guard let manufacturerInfo = manufacturersWrapper.manufacturers.first(where: { $0.name.lowercased() == manufacturer.lowercased() }) else {
            return loadDefaultImageDirect(filmName: filmName, manufacturer: manufacturer)
        }
        
        // Normalize the user's film name for comparison (remove spaces/special characters, lowercase)
        let normalizedUserInput = filmName.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "", options: .regularExpression).lowercased()
        
        // Try to find a matching film by checking all aliases
        for filmInfo in manufacturerInfo.films {
            // Check if any of the film's aliases match the user input
            // Also include the filename itself as a potential match
            let allNames = [filmInfo.filename] + filmInfo.aliases
            
            for alias in allNames {
                // Normalize alias (remove spaces/special characters, lowercase)
                let normalizedAlias = alias.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "", options: .regularExpression).lowercased()
                
                // Check if user input matches this alias
                if normalizedUserInput == normalizedAlias {
                    // Found a match! Use the filename to load the image
                    let imageFileName = filmInfo.filename
                    
                    // Try to load the image using lowercase manufacturer (as stored in files)
                    let manufacturerLower = manufacturer.lowercased()
                    let fullImageFileName = "\(manufacturerLower)_\(imageFileName).png"
                    
                    if let image = loadImageFromBundle(filename: fullImageFileName) {
                        return image
                    }
                    
                    // Try with capitalized manufacturer
                    let manufacturerCapitalized = manufacturerInfo.name.prefix(1).uppercased() + manufacturerInfo.name.dropFirst().lowercased()
                    let fullImageFileName2 = "\(manufacturerCapitalized.lowercased())_\(imageFileName).png"
                    if let image = loadImageFromBundle(filename: fullImageFileName2) {
                        return image
                    }
                }
            }
        }
        
        // If no match found in JSON, try direct filename matching
        return loadDefaultImageDirect(filmName: filmName, manufacturer: manufacturer)
    }
    
    /// Try to load image directly using manufacturer_filmname format
    private func loadDefaultImageDirect(filmName: String, manufacturer: String) -> UIImage? {
        let baseName = filmName.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "", options: .regularExpression)
        let manufacturerName = manufacturer.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "", options: .regularExpression)
        
        // Try various case combinations (manufacturer is typically lowercase in filenames)
        let variations = [
            "\(manufacturerName.lowercased())_\(baseName.lowercased()).png",
            "\(manufacturerName.lowercased())_\(baseName.capitalized).png",
            "\(manufacturerName.lowercased())_\(baseName.uppercased()).png",
            "\(manufacturerName.lowercased())_\(baseName).png", // Original case
            "\(manufacturerName.capitalized)_\(baseName.lowercased()).png",
            "\(manufacturerName.capitalized)_\(baseName.capitalized).png",
            "\(manufacturerName.capitalized)_\(baseName.uppercased()).png"
        ]
        
        for variation in variations {
            if let image = loadImageFromBundle(filename: variation) {
                return image
            }
        }
        
        return nil
    }
    
    /// Load an image from the bundle
    private func loadImageFromBundle(filename: String) -> UIImage? {
        let resourceName = filename.replacingOccurrences(of: ".png", with: "")
        
        // Load from bundle root (where images are)
        if let bundleURL = Bundle.main.url(forResource: resourceName, withExtension: "png", subdirectory: nil),
           let imageData = try? Data(contentsOf: bundleURL),
           let image = UIImage(data: imageData) {
            return image
        }
        
        return nil
    }
    
    /// Load a catalog image directly by its filename (e.g., "ilford_hp5")
    /// - Parameter filename: The filename without extension (e.g., "ilford_hp5")
    /// - Returns: The UIImage if found, nil otherwise
    func loadCatalogImage(filename: String) -> UIImage? {
        return loadImageFromBundle(filename: filename)
    }
    
    /// Detect film metadata (speed, type, and whether a default image exists)
    /// - Parameters:
    ///   - filmName: The film name entered by the user
    ///   - manufacturer: The manufacturer name entered by the user
    /// - Returns: FilmMetadata containing speed, type, and image availability
    func detectFilmMetadata(filmName: String, manufacturer: String) -> FilmMetadata {
        // Load manufacturers.json to get film information
        guard let manufacturersURL = Bundle.main.url(forResource: "manufacturers", withExtension: "json"),
              let manufacturersData = try? Data(contentsOf: manufacturersURL),
              let manufacturersWrapper = try? JSONDecoder().decode(ManufacturersDataWrapper.self, from: manufacturersData) else {
            return FilmMetadata(filmSpeed: nil, type: nil, hasImage: false)
        }
        
        // Find the manufacturer in the JSON (case-insensitive)
        guard let manufacturerInfo = manufacturersWrapper.manufacturers.first(where: { $0.name.lowercased() == manufacturer.lowercased() }) else {
            return FilmMetadata(filmSpeed: nil, type: nil, hasImage: false)
        }
        
        // Normalize the user's film name for comparison
        let normalizedUserInput = filmName.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "", options: .regularExpression).lowercased()
        
        // Try to find a matching film by checking all aliases
        for filmInfo in manufacturerInfo.films {
            let allNames = [filmInfo.filename] + filmInfo.aliases
            
            for alias in allNames {
                let normalizedAlias = alias.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "", options: .regularExpression).lowercased()
                
                if normalizedUserInput == normalizedAlias {
                    // Found a match! Return the metadata
                    let hasImage = loadDefaultImage(filmName: filmName, manufacturer: manufacturer) != nil
                    return FilmMetadata(
                        filmSpeed: filmInfo.speed,
                        type: filmInfo.type,
                        hasImage: hasImage
                    )
                }
            }
        }
        
        // No match found
        return FilmMetadata(filmSpeed: nil, type: nil, hasImage: false)
    }

    /// Films in manufacturers.json whose stored DX codes match a scanned canister barcode.
    func filmsMatching(dxCode: String) -> [DXFilmMatch] {
        let manufacturers = loadManufacturersData()
        let candidates = dxLookupCandidates(from: dxCode)
        guard !candidates.isEmpty else { return [] }

        var exact: [DXFilmMatch] = []
        var extract: [DXFilmMatch] = []
        var seenExact = Set<String>()
        var seenExtract = Set<String>()

        let candidateSet = Set(candidates)
        let extractSet = Set(candidates.compactMap { dxExtract(from: $0) })

        for manufacturer in manufacturers {
            for film in manufacturer.films {
                let stored = film.dx
                    .map { $0.filter(\.isNumber) }
                    .filter { !$0.isEmpty && Set($0) != ["0"] }
                guard !stored.isEmpty else { continue }

                let match = DXFilmMatch(
                    manufacturer: manufacturer.name,
                    filename: film.filename,
                    displayName: displayName(for: film),
                    speed: film.speed,
                    type: film.type
                )

                if stored.contains(where: { candidateSet.contains($0) }) {
                    if seenExact.insert(match.id).inserted {
                        exact.append(match)
                    }
                    continue
                }

                let storedExtracts = Set(stored.compactMap { dxExtract(from: $0) })
                if !storedExtracts.isDisjoint(with: extractSet) {
                    if seenExtract.insert(match.id).inserted {
                        extract.append(match)
                    }
                }
            }
        }

        return exact.isEmpty ? extract : exact
    }

    /// Frame count from the last digit of a 6-digit DX cartridge barcode (ANSI/NAPM IT1.14).
    /// Corrects Interleaved 2 of 5 reverse reads. Digit 0 is treated as unspecified (default 36),
    /// not 72 — consumer cans almost never have 72 exposures, and databases often store 0 as a placeholder.
    func exposures(fromScannedDXCode scanned: String) -> Int {
        let typical = Set([12, 20, 24, 36])
        let orientations = dxSixDigitOrientations(from: scanned)
        let decoded = orientations.compactMap { dxExposuresDigit(from: $0) }
        if let match = decoded.first(where: { typical.contains($0) }) {
            return match
        }
        if let match = decoded.first(where: { $0 != 72 }) {
            return match
        }
        return 36
    }

    /// Match a packaging barcode (UPC/EAN on the box) to catalog film + pack quantity.
    func packageMatching(barcode: String) -> PackageBarcodeMatch? {
        let keys = barcodeIndexKeys(barcode)
        guard !keys.isEmpty else { return nil }
        guard let record = packageBarcodeRecords().first(where: { !$0.keys.isDisjoint(with: keys) }) else {
            return nil
        }
        return resolvePackageMatch(record)
    }

    private struct PackageBarcodeRecord {
        let keys: Set<String>
        let manufacturerCSV: String
        let filmCSV: String
        let format: FilmStock.FilmFormat
        let quantity: Int
    }

    private func packageBarcodeRecords() -> [PackageBarcodeRecord] {
        struct Cache {
            static let records: [PackageBarcodeRecord] = ImageStorage.loadPackageBarcodeRecords()
        }
        return Cache.records
    }

    private static func loadPackageBarcodeRecords() -> [PackageBarcodeRecord] {
        guard let url = Bundle.main.url(forResource: "barcodes", withExtension: "csv"),
              let raw = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }
        let text = raw.replacingOccurrences(of: "\u{FEFF}", with: "")
        var records: [PackageBarcodeRecord] = []
        for (index, line) in text.split(whereSeparator: \.isNewline).enumerated() {
            if index == 0 { continue }
            let cols = line.split(separator: ",", omittingEmptySubsequences: false).map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard cols.count >= 5 else { continue }
            // Skip Excel scientific-notation values that lost the real digits.
            guard cols[0].allSatisfy(\.isNumber) else { continue }
            let barcode = cols[0]
            guard barcode.count >= 8 else { continue }
            guard let format = filmFormat(fromCSV: cols[3]),
                  let quantity = Int(cols[4]), quantity > 0 else { continue }
            let keys = barcodeIndexKeys(barcode)
            guard !keys.isEmpty else { continue }
            records.append(
                PackageBarcodeRecord(
                    keys: keys,
                    manufacturerCSV: cols[1],
                    filmCSV: cols[2],
                    format: format,
                    quantity: quantity
                )
            )
        }
        return records
    }

    private static func filmFormat(fromCSV type: String) -> FilmStock.FilmFormat? {
        switch type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "35mm", "35": return .thirtyFive
        case "120": return .oneTwenty
        case "4x5", "4×5": return .fourByFive
        default: return nil
        }
    }

    /// UPC-A / EAN-13 / short-catalog variants of a single code.
    /// Applied once to the original digits only — chaining pad/strip/drop would make
    /// every barcode share keys (and always match the first CSV row).
    private static func barcodeIndexKeys(_ raw: String) -> Set<String> {
        let digits = raw.filter(\.isNumber)
        guard (8...14).contains(digits.count) else { return [] }
        var keys: Set<String> = [digits]
        switch digits.count {
        case 11:
            keys.insert("0" + digits)
            keys.insert("00" + digits)
        case 12:
            keys.insert("0" + digits)
            if digits.hasPrefix("0") {
                keys.insert(String(digits.dropFirst()))
            }
            keys.insert(String(digits.dropLast()))
        case 13:
            if digits.hasPrefix("0") {
                keys.insert(String(digits.dropFirst()))
            }
            if digits.hasPrefix("00") {
                keys.insert(String(digits.dropFirst(2)))
            }
            keys.insert(String(digits.dropLast()))
        default:
            break
        }
        return keys
    }

    private func barcodeIndexKeys(_ raw: String) -> Set<String> {
        Self.barcodeIndexKeys(raw)
    }

    private func resolvePackageMatch(_ record: PackageBarcodeRecord) -> PackageBarcodeMatch {
        let manufacturers = loadManufacturersData()
        let manufacturerName = resolvedManufacturerName(record.manufacturerCSV, in: manufacturers)
        let film = resolvedFilm(record.filmCSV, manufacturerName: manufacturerName, in: manufacturers)
        return PackageBarcodeMatch(
            manufacturer: manufacturerName,
            filename: film?.filename,
            displayName: film.map { displayName(for: $0) } ?? record.filmCSV,
            speed: film?.speed,
            type: film?.type,
            format: record.format,
            quantity: record.quantity
        )
    }

    private func resolvedManufacturerName(_ csv: String, in manufacturers: [ManufacturerInfo]) -> String {
        let aliases = ["fomapan": "Foma"]
        let mapped = aliases[csv.lowercased()] ?? csv
        if let match = manufacturers.first(where: { $0.name.lowercased() == mapped.lowercased() }) {
            return match.name
        }
        if let match = manufacturers.first(where: { $0.name.lowercased() == csv.lowercased() }) {
            return match.name
        }
        return csv
    }

    private func resolvedFilm(_ csv: String, manufacturerName: String, in manufacturers: [ManufacturerInfo]) -> FilmInfo? {
        guard let manufacturer = manufacturers.first(where: { $0.name.lowercased() == manufacturerName.lowercased() }) else {
            return nil
        }
        let aliases = [
            "foma400": "fomapan400",
            "foma100": "fomapan100",
            "ektarchrome64t": "ektachrome64t"
        ]
        let wanted = aliases[normalizeFilmToken(csv)] ?? normalizeFilmToken(csv)
        for film in manufacturer.films {
            let names = ([film.filename] + film.aliases).map(normalizeFilmToken)
            if names.contains(wanted) || names.contains(normalizeFilmToken(csv)) {
                return film
            }
        }
        return nil
    }

    private func normalizeFilmToken(_ value: String) -> String {
        value.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "", options: .regularExpression).lowercased()
    }

    private func dxSixDigitOrientations(from scanned: String) -> [String] {
        let digits = scanned.filter(\.isNumber)
        guard !digits.isEmpty else { return [] }
        let six: String
        if digits.count == 6 {
            six = digits
        } else if digits.count < 6 {
            six = String(repeating: "0", count: 6 - digits.count) + digits
        } else {
            six = String(digits.suffix(6))
        }
        return [six, String(six.reversed())]
    }

    private func dxExposuresDigit(from sixDigit: String) -> Int? {
        guard let last = sixDigit.last, let digit = Int(String(last)) else { return nil }
        switch digit {
        case 1: return 12
        case 2: return 20
        case 3: return 24
        case 4: return 36
        case 5: return 48
        case 6: return 60
        case 0: return 72
        default: return nil
        }
    }

    /// Digits from a scan, 6-digit padded form, and Interleaved 2 of 5 reverse.
    private func dxLookupCandidates(from scanned: String) -> [String] {
        let digits = scanned.filter(\.isNumber)
        guard !digits.isEmpty else { return [] }

        var values: [String] = [digits]
        if digits.count < 6 {
            values.append(String(repeating: "0", count: 6 - digits.count) + digits)
        }
        if digits.count == 6 {
            values.append(String(digits.reversed()))
        }
        if digits.count > 6 {
            let prefix = String(digits.prefix(6))
            let suffix = String(digits.suffix(6))
            values.append(prefix)
            values.append(suffix)
            values.append(String(prefix.reversed()))
            values.append(String(suffix.reversed()))
        }
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }

    /// Middle four digits of a 6-digit DX full code, or the value itself if already 4 digits.
    private func dxExtract(from code: String) -> String? {
        let digits = code.filter(\.isNumber)
        if digits.count == 4 { return digits }
        guard digits.count == 6 else { return nil }
        let start = digits.index(digits.startIndex, offsetBy: 1)
        let end = digits.index(start, offsetBy: 4)
        return String(digits[start..<end])
    }

    private func displayName(for film: FilmInfo) -> String {
        let generic = Set(["100", "200", "400", "800", "50", "25", "80", "160", "125"])
        if let spaced = film.aliases.first(where: { alias in
            alias.contains(" ") && !generic.contains(alias.lowercased())
        }) {
            return spaced.split(separator: " ").map { part in
                guard let first = part.first else { return String(part) }
                return String(first).uppercased() + part.dropFirst()
            }.joined(separator: " ")
        }
        return film.aliases.first ?? film.filename
    }
    
    /// Get all custom images grouped by manufacturer
    /// - Returns: Dictionary mapping manufacturer names to arrays of (filename, image) tuples
    func getAllCustomImages() -> [String: [(filename: String, image: UIImage)]] {
        var imagesByManufacturer: [String: [(filename: String, image: UIImage)]] = [:]
        
        guard FileManager.default.fileExists(atPath: userImagesDirectory.path) else {
            return imagesByManufacturer
        }
        
        // Get all manufacturer directories
        guard let manufacturerDirs = try? FileManager.default.contentsOfDirectory(
            at: userImagesDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return imagesByManufacturer
        }
        
        for manufacturerDir in manufacturerDirs {
            // Check if it's actually a directory
            guard let resourceValues = try? manufacturerDir.resourceValues(forKeys: [.isDirectoryKey]),
                  resourceValues.isDirectory == true else {
                continue
            }
            
            let manufacturerName = manufacturerDir.lastPathComponent
            
            // Get all image files in this manufacturer directory
            guard let imageFiles = try? FileManager.default.contentsOfDirectory(
                at: manufacturerDir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }
            
            var images: [(filename: String, image: UIImage)] = []
            
            for imageFile in imageFiles {
                // Only process .jpg files
                guard imageFile.pathExtension.lowercased() == "jpg" else {
                    continue
                }
                
                let filename = imageFile.deletingPathExtension().lastPathComponent
                
                if let imageData = try? Data(contentsOf: imageFile),
                   let image = UIImage(data: imageData) {
                    images.append((filename: filename, image: image))
                }
            }
            
            if !images.isEmpty {
                imagesByManufacturer[manufacturerName] = images
            }
        }
        
        return imagesByManufacturer
    }
    
    /// Get all default images grouped by manufacturer
    /// Images are now in format: manufacturer_filmname.png in a single folder
    /// - Returns: Dictionary mapping manufacturer names to arrays of (imageName, image) tuples
    /// Returns raw manufacturer + film data from manufacturers.json for search/metadata use.
    func loadManufacturersData() -> [ManufacturerInfo] {
        guard let url = Bundle.main.url(forResource: "manufacturers", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let wrapper = try? JSONDecoder().decode(ManufacturersDataWrapper.self, from: data) else {
            return []
        }
        return wrapper.manufacturers
    }

    func getAllDefaultImages() -> [String: [(imageName: String, image: UIImage)]] {
        var imagesByManufacturer: [String: [(imageName: String, image: UIImage)]] = [:]
        
        // Load manufacturers.json to get proper manufacturer name capitalization
        var manufacturerNameMap: [String: String] = [:]
        if let manufacturersURL = Bundle.main.url(forResource: "manufacturers", withExtension: "json"),
           let manufacturersData = try? Data(contentsOf: manufacturersURL),
           let manufacturersWrapper = try? JSONDecoder().decode(ManufacturersDataWrapper.self, from: manufacturersData) {
            for manufacturerInfo in manufacturersWrapper.manufacturers {
                manufacturerNameMap[manufacturerInfo.name.lowercased()] = manufacturerInfo.name
            }
        }
        
        // Get all PNG files from bundle root
        let allImagePaths = Bundle.main.paths(forResourcesOfType: "png", inDirectory: nil)
        
        for imagePath in allImagePaths {
            let imageURL = URL(fileURLWithPath: imagePath)
            let filename = imageURL.deletingPathExtension().lastPathComponent
            
            // Only process files that match manufacturer_filmname format
            if let underscoreIndex = filename.firstIndex(of: "_") {
                let manufacturerNameRaw = String(filename[..<underscoreIndex])
                let filmName = String(filename[filename.index(after: underscoreIndex)...])
                
                // Get proper manufacturer name from map, or capitalize it
                let manufacturerName: String
                if let properName = manufacturerNameMap[manufacturerNameRaw.lowercased()] {
                    manufacturerName = properName
                } else {
                    // Fallback: capitalize first letter
                    manufacturerName = manufacturerNameRaw.prefix(1).uppercased() + manufacturerNameRaw.dropFirst().lowercased()
                }
                
                // Load the image
                if let imageData = try? Data(contentsOf: imageURL),
                   let image = UIImage(data: imageData) {
                    // Initialize array if needed
                    if imagesByManufacturer[manufacturerName] == nil {
                        imagesByManufacturer[manufacturerName] = []
                    }
                    
                    // Add image (use filmName as the identifier)
                    imagesByManufacturer[manufacturerName]?.append((imageName: filmName, image: image))
                }
            }
        }
        
        return imagesByManufacturer
    }
    
    /// Get all custom user photos
    func getAllCustomPhotos() -> [(filename: String, manufacturer: String, image: UIImage)] {
        var photos: [(filename: String, manufacturer: String, image: UIImage)] = []
        
        // Check if the directory exists
        guard FileManager.default.fileExists(atPath: userImagesDirectory.path) else {
            return photos
        }
        
        // Enumerate all manufacturer directories
        guard let manufacturerDirs = try? FileManager.default.contentsOfDirectory(
            at: userImagesDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return photos
        }
        
        for manufacturerDir in manufacturerDirs where manufacturerDir.hasDirectoryPath {
            let manufacturerName = manufacturerDir.lastPathComponent
            
            // Get all images in this manufacturer directory
            guard let imageFiles = try? FileManager.default.contentsOfDirectory(
                at: manufacturerDir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }
            
            for imageFile in imageFiles {
                let fileExtension = imageFile.pathExtension.lowercased()
                // Custom photos are saved as .jpg
                guard fileExtension == "jpg" || fileExtension == "jpeg" else { continue }
                
                let filename = imageFile.deletingPathExtension().lastPathComponent
                
                if let imageData = try? Data(contentsOf: imageFile),
                   let image = UIImage(data: imageData) {
                    photos.append((filename: filename, manufacturer: manufacturerName, image: image))
                }
            }
        }
        
        // Sort by manufacturer then filename
        photos.sort { $0.manufacturer < $1.manufacturer || ($0.manufacturer == $1.manufacturer && $0.filename < $1.filename) }
        
        return photos
    }
}

