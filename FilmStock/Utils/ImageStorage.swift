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
    private let appGroupID = "group.halbe.no.FilmStock"
    
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
        let hasCopiedImagesKey = "hasCopiedDefaultImagesToAppGroup_v2" // Changed key to force re-copy with new structure
        
        // Clear old flag to force re-copy
        UserDefaults.standard.removeObject(forKey: "hasCopiedDefaultImagesToAppGroup")
        
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

