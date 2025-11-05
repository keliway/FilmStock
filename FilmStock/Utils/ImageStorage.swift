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
        let hasCopiedImagesKey = "hasCopiedDefaultImagesToAppGroup"
        if UserDefaults.standard.bool(forKey: hasCopiedImagesKey) {
            return // Already copied
        }
        
        guard let containerURL = appGroupContainer else {
            return
        }
        
        guard let resourcePath = Bundle.main.resourcePath else {
            return
        }
        
        guard let manufacturersURL = Bundle.main.url(forResource: "manufacturers", withExtension: "json"),
              let manufacturersData = try? Data(contentsOf: manufacturersURL),
              let manufacturersWrapper = try? JSONDecoder().decode(ManufacturersDataWrapper.self, from: manufacturersData) else {
            return
        }
        
        let resourceURL = URL(fileURLWithPath: resourcePath, isDirectory: true)
        let destinationImagesURL = containerURL.appendingPathComponent("DefaultImages", isDirectory: true)
        
        // Create destination directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: destinationImagesURL.path) {
            try? FileManager.default.createDirectory(at: destinationImagesURL, withIntermediateDirectories: true)
        }
        
        // Get all png files from the bundle resource path (flattened structure)
        let pngFiles = (try? FileManager.default.contentsOfDirectory(
            at: resourceURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ))?.filter { $0.pathExtension.lowercased() == "png" } ?? []
        
        // Create a mapping of image filename (without extension) to manufacturer
        var imageToManufacturer: [String: String] = [:]
        for manufacturerName in manufacturersWrapper.manufacturers {
            let commonImageNames = getCommonImageNames(for: manufacturerName)
            for imageName in commonImageNames {
                imageToManufacturer[imageName.lowercased()] = manufacturerName
            }
        }
        
        // Copy each image to the appropriate manufacturer directory
        for imageFile in pngFiles {
            let fileName = imageFile.lastPathComponent
            let imageNameWithoutExt = fileName.replacingOccurrences(of: ".png", with: "", options: .caseInsensitive)
            
            // Find manufacturer by matching image name (case-insensitive)
            guard let mfg = imageToManufacturer[imageNameWithoutExt.lowercased()] else {
                continue
            }
            
            let destinationManufacturerURL = destinationImagesURL.appendingPathComponent(mfg, isDirectory: true)
            
            if !FileManager.default.fileExists(atPath: destinationManufacturerURL.path) {
                try? FileManager.default.createDirectory(at: destinationManufacturerURL, withIntermediateDirectories: true)
            }
            
            let destinationFile = destinationManufacturerURL.appendingPathComponent(fileName)
            
            if !FileManager.default.fileExists(atPath: destinationFile.path),
               let imageData = try? Data(contentsOf: imageFile) {
                try? imageData.write(to: destinationFile)
            }
        }
        
        // Mark as copied
        UserDefaults.standard.set(true, forKey: hasCopiedImagesKey)
    }
    
    // Helper struct for decoding manufacturers.json
    private struct ManufacturersDataWrapper: Codable {
        let manufacturers: [String]
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
    /// - Parameters:
    ///   - filmName: The film name
    ///   - manufacturer: The manufacturer name
    /// - Returns: The UIImage if found, nil otherwise
    func loadDefaultImage(filmName: String, manufacturer: String) -> UIImage? {
        let baseName = filmName.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "", options: .regularExpression)
        var variations = [
            baseName + ".png",
            baseName.lowercased() + ".png",
            baseName.capitalized + ".png",
            baseName.uppercased() + ".png"
        ]
        
        // Add variation where only first letter is capitalized
        if baseName.count > 1 {
            let firstChar = String(baseName.prefix(1)).uppercased()
            let rest = String(baseName.dropFirst()).lowercased()
            variations.append((firstChar + rest) + ".png")
        }
        
        guard let resourcePath = Bundle.main.resourcePath else { return nil }
        let resourceURL = URL(fileURLWithPath: resourcePath, isDirectory: true)
        let imagesURL = resourceURL.appendingPathComponent("images", isDirectory: true)
        
        // Check flattened structure first
        for variation in variations {
            let imageURL = imagesURL.appendingPathComponent(variation, isDirectory: false)
            if FileManager.default.fileExists(atPath: imageURL.path),
               let data = try? Data(contentsOf: imageURL),
               let image = UIImage(data: data) {
                return image
            }
        }
        
        // Check manufacturer subdirectory
        let manufacturerURL = imagesURL.appendingPathComponent(manufacturer, isDirectory: true)
        for variation in variations {
            let imageURL = manufacturerURL.appendingPathComponent(variation, isDirectory: false)
            if FileManager.default.fileExists(atPath: imageURL.path),
               let data = try? Data(contentsOf: imageURL),
               let image = UIImage(data: data) {
                return image
            }
        }
        
        // Try Bundle.main.url methods
        for variation in variations {
            let resourceName = variation.replacingOccurrences(of: ".png", with: "")
            // Try with subdirectory
            if let bundleURL = Bundle.main.url(forResource: resourceName, withExtension: "png", subdirectory: "images/\(manufacturer)"),
               let data = try? Data(contentsOf: bundleURL),
               let image = UIImage(data: data) {
                return image
            }
            // Try without subdirectory (flattened)
            if let bundleURL = Bundle.main.url(forResource: resourceName, withExtension: "png", subdirectory: "images"),
               let data = try? Data(contentsOf: bundleURL),
               let image = UIImage(data: data) {
                return image
            }
            // Try at bundle root
            if let bundleURL = Bundle.main.url(forResource: resourceName, withExtension: "png"),
               let data = try? Data(contentsOf: bundleURL),
               let image = UIImage(data: data) {
                return image
            }
        }
        
        return nil
    }
}

