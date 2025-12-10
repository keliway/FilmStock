//
//  FilmDataModel.swift
//  FilmStock
//
//  SwiftData model for film stock relationships
//

import Foundation
import SwiftData

@Model
final class Manufacturer {
    var name: String
    var isCustom: Bool // true if user added it, false if from manufacturers.json
    @Relationship(deleteRule: .nullify)
    var films: [Film]?
    
    init(name: String, isCustom: Bool = false) {
        self.name = name
        self.isCustom = isCustom
        self.films = []
    }
}

enum ImageSource: String, Codable {
    case none = "none"              // No image
    case autoDetected = "auto"      // Auto-detected default image based on manufacturer + film name
    case catalog = "catalog"        // User selected a specific default image from catalog
    case custom = "custom"          // User took a photo with camera
}

@Model
final class Film {
    var name: String
    @Relationship(deleteRule: .nullify)
    var manufacturer: Manufacturer?
    var type: String // FilmType rawValue
    var filmSpeed: Int
    var imageName: String? // For catalog: default image filename, for custom: user photo filename
    var imageSource: String // ImageSource rawValue - tracks the type of image
    @Relationship(deleteRule: .cascade)
    var myFilms: [MyFilm]?
    
    init(name: String, manufacturer: Manufacturer?, type: String, filmSpeed: Int, imageName: String? = nil, imageSource: String = ImageSource.autoDetected.rawValue) {
        self.name = name
        self.manufacturer = manufacturer
        self.type = type
        self.filmSpeed = filmSpeed
        self.imageName = imageName
        self.imageSource = imageSource
        self.myFilms = []
    }
}

@Model
final class MyFilm {
    var id: String
    var format: String // FilmFormat rawValue
    var customFormatName: String? // Store custom format name when format is "Other"
    var quantity: Int
    var expireDate: String? // Store as comma-separated string for SwiftData compatibility
    var comments: String?
    var isFrozen: Bool? // Optional for backward compatibility - nil means false
    var createdAt: String?
    var updatedAt: String?
    @Relationship(deleteRule: .nullify)
    var film: Film?
    
    init(id: String, format: String, customFormatName: String? = nil, quantity: Int, expireDate: [String]? = nil, comments: String? = nil, isFrozen: Bool = false, createdAt: String? = nil, updatedAt: String? = nil, film: Film? = nil) {
        self.id = id
        self.format = format
        self.customFormatName = customFormatName
        self.quantity = quantity
        // Convert array to comma-separated string for storage
        self.expireDate = expireDate?.joined(separator: ",")
        self.comments = comments
        self.isFrozen = isFrozen
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.film = film
    }
    
    // Helper computed property to get expireDate as array
    var expireDateArray: [String]? {
        get {
            guard let expireDate = expireDate, !expireDate.isEmpty else { return nil }
            return expireDate.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        }
        set {
            expireDate = newValue?.joined(separator: ",")
        }
    }
}

@Model
final class Camera {
    var name: String
    @Relationship(deleteRule: .nullify)
    var loadedFilms: [LoadedFilm]?
    
    init(name: String) {
        self.name = name
        self.loadedFilms = []
    }
}

@Model
final class LoadedFilm {
    var id: String
    var loadedAt: Date
    var quantity: Int // Number of rolls/sheets loaded
    var shotAtISO: Int? // ISO the film is being shot at (if different from film's native ISO)
    @Relationship(deleteRule: .nullify)
    var film: Film?
    var format: String // FilmFormat rawValue
    @Relationship(deleteRule: .nullify)
    var camera: Camera?
    @Relationship(deleteRule: .nullify)
    var myFilm: MyFilm? // Reference to the MyFilm entry that was loaded
    
    // Computed property to get the effective ISO (shot ISO or film's native ISO)
    var effectiveISO: Int {
        if let shotISO = shotAtISO {
            return shotISO
        }
        return film?.filmSpeed ?? 0
    }
    
    init(id: String, film: Film?, format: String, camera: Camera?, myFilm: MyFilm?, quantity: Int = 1, loadedAt: Date = Date(), shotAtISO: Int? = nil) {
        self.id = id
        self.film = film
        self.format = format
        self.camera = camera
        self.myFilm = myFilm
        self.quantity = quantity
        self.loadedAt = loadedAt
        self.shotAtISO = shotAtISO
    }
}

@Model
final class FinishedFilm {
    var id: String
    var loadedAt: Date
    var finishedAt: Date
    var quantity: Int
    var shotAtISO: Int?
    var status: String? // toDevelop, inDevelopment, developed
    @Relationship(deleteRule: .nullify)
    var film: Film?
    var format: String
    @Relationship(deleteRule: .nullify)
    var camera: Camera?
    @Relationship(deleteRule: .nullify)
    var myFilm: MyFilm?
    
    var effectiveISO: Int {
        if let shotISO = shotAtISO {
            return shotISO
        }
        return film?.filmSpeed ?? 0
    }
    
    init(id: String, film: Film?, format: String, camera: Camera?, myFilm: MyFilm?, quantity: Int, loadedAt: Date, finishedAt: Date = Date(), shotAtISO: Int? = nil, status: String? = nil) {
        self.id = id
        self.film = film
        self.format = format
        self.camera = camera
        self.myFilm = myFilm
        self.quantity = quantity
        self.loadedAt = loadedAt
        self.finishedAt = finishedAt
        self.shotAtISO = shotAtISO
        self.status = status
    }
}

