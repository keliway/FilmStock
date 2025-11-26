//
//  FilmStock.swift
//  FilmStock
//
//  Film Stock Data Model
//

import Foundation

struct FilmStock: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var manufacturer: String
    var type: FilmType
    var filmSpeed: Int
    var format: FilmFormat
    var customFormatName: String? // Store custom format name when format is .other
    var quantity: Int
    var expireDate: [String]? // Array of date strings (YYYY, MM/YYYY, or MM/DD/YYYY) - optional to handle null
    var comments: String?
    var isFrozen: Bool
    var createdAt: String?
    var updatedAt: String?
    
    // Returns the display name for the format (custom name if available, otherwise enum displayName)
    var formatDisplayName: String {
        if format == .other, let customName = customFormatName, !customName.isEmpty {
            return customName
        }
        return format.displayName
    }
    
    // Custom decoder to handle null expireDate values
    enum CodingKeys: String, CodingKey {
        case id, name, manufacturer, type, filmSpeed, format, customFormatName, quantity, expireDate, comments, isFrozen, createdAt, updatedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        manufacturer = try container.decode(String.self, forKey: .manufacturer)
        type = try container.decode(FilmType.self, forKey: .type)
        filmSpeed = try container.decode(Int.self, forKey: .filmSpeed)
        format = try container.decode(FilmFormat.self, forKey: .format)
        customFormatName = try container.decodeIfPresent(String.self, forKey: .customFormatName)
        quantity = try container.decode(Int.self, forKey: .quantity)
        expireDate = try container.decodeIfPresent([String].self, forKey: .expireDate)
        comments = try container.decodeIfPresent(String.self, forKey: .comments)
        isFrozen = try container.decodeIfPresent(Bool.self, forKey: .isFrozen) ?? false
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
    }
    
    init(id: String, name: String, manufacturer: String, type: FilmType, filmSpeed: Int, format: FilmFormat, customFormatName: String? = nil, quantity: Int, expireDate: [String]? = nil, comments: String? = nil, isFrozen: Bool = false, createdAt: String? = nil, updatedAt: String? = nil) {
        self.id = id
        self.name = name
        self.manufacturer = manufacturer
        self.type = type
        self.filmSpeed = filmSpeed
        self.format = format
        self.customFormatName = customFormatName
        self.quantity = quantity
        self.expireDate = expireDate
        self.comments = comments
        self.isFrozen = isFrozen
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    enum FilmType: String, Codable, CaseIterable {
        case bw = "BW"
        case color = "Color"
        case slide = "Slide"
        case instant = "Instant"
        
        var displayName: String {
            switch self {
            case .bw: return "B&W"
            case .color: return "Color"
            case .slide: return "Slide"
            case .instant: return "Instant"
            }
        }
    }
    
    enum FilmFormat: String, Codable, CaseIterable {
        case thirtyFive = "35"
        case oneTwenty = "120"
        case oneTen = "110"
        case oneTwentySeven = "127"
        case twoTwenty = "220"
        case fourByFive = "4x5"
        case fiveBySeven = "5x7"
        case eightByTen = "8x10"
        case other = "Other"
        
        var displayName: String {
            switch self {
            case .thirtyFive: return "35mm"
            case .oneTwenty: return "120"
            case .oneTen: return "110"
            case .oneTwentySeven: return "127"
            case .twoTwenty: return "220"
            case .fourByFive: return "4x5"
            case .fiveBySeven: return "5x7"
            case .eightByTen: return "8x10"
            case .other: return "Other"
            }
        }
        
        var quantityUnit: String {
            switch self {
            case .fourByFive, .fiveBySeven, .eightByTen: return "Sheets"
            default: return "Rolls"
            }
        }
    }
}

// Grouped film for display (multiple formats of same film)
struct GroupedFilm: Identifiable, Hashable {
    let id: String
    let name: String
    let manufacturer: String
    let type: FilmStock.FilmType
    let filmSpeed: Int
    var imageName: String? // For catalog: default image filename, for custom: user photo filename
    var imageSource: String // ImageSource rawValue
    var formats: [FormatInfo]
    
    struct FormatInfo: Identifiable, Hashable {
        let id: String
        let format: FilmStock.FilmFormat
        let customFormatName: String?
        let quantity: Int
        let expireDate: [String]?
        let isFrozen: Bool
        let filmId: String
        
        var formatDisplayName: String {
            if format == .other, let customName = customFormatName, !customName.isEmpty {
                return customName
            }
            return format.displayName
        }
    }
    
    static func == (lhs: GroupedFilm, rhs: GroupedFilm) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

