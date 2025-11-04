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
    var quantity: Int
    var expireDate: [String] // Array of date strings (YYYY, MM/YYYY, or MM/DD/YYYY)
    var comments: String?
    var createdAt: String?
    var updatedAt: String?
    
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
        case oneTwentySeven = "127"
        case fourByFive = "4x5"
        
        var displayName: String {
            switch self {
            case .thirtyFive: return "35mm"
            case .oneTwenty: return "120"
            case .oneTwentySeven: return "127"
            case .fourByFive: return "4x5"
            }
        }
        
        var quantityUnit: String {
            switch self {
            case .fourByFive: return "Sheets"
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
    var formats: [FormatInfo]
    
    struct FormatInfo: Identifiable, Hashable {
        let id: String
        let format: FilmStock.FilmFormat
        let quantity: Int
        let expireDate: [String]
        let filmId: String
    }
    
    static func == (lhs: GroupedFilm, rhs: GroupedFilm) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

