//
//  FilmStockDataManager.swift
//  FilmStock
//
//  Data Management using local file storage
//

import Foundation
import SwiftUI

class FilmStockDataManager: ObservableObject {
    @Published var filmStocks: [FilmStock] = []
    
    private let fileName = "filmstocks.json"
    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }
    
    init() {
        loadFilmStocks()
    }
    
    func loadFilmStocks() {
        // Try to load from Documents directory first
        if let data = try? Data(contentsOf: fileURL) {
            if let decoded = try? JSONDecoder().decode(FilmStockDataWrapper.self, from: data) {
                filmStocks = decoded.filmstocks
                return
            } else if let decoded = try? JSONDecoder().decode([FilmStock].self, from: data) {
                filmStocks = decoded
                return
            }
        }
        
        // If no file exists, try to load from bundle (initial data)
        if let bundleData = Bundle.main.url(forResource: "filmstocks", withExtension: "json"),
           let data = try? Data(contentsOf: bundleData),
           let decoded = try? JSONDecoder().decode(FilmStockDataWrapper.self, from: data) {
            filmStocks = decoded.filmstocks
            saveFilmStocks() // Save to Documents for future use
        } else {
            filmStocks = []
        }
    }
    
    func saveFilmStocks() {
        let wrapper = FilmStockDataWrapper(filmstocks: filmStocks)
        guard let data = try? JSONEncoder().encode(wrapper) else { return }
        try? data.write(to: fileURL)
    }
    
    func addFilmStock(_ filmStock: FilmStock) {
        filmStocks.append(filmStock)
        saveFilmStocks()
    }
    
    func updateFilmStock(_ filmStock: FilmStock) {
        if let index = filmStocks.firstIndex(where: { $0.id == filmStock.id }) {
            filmStocks[index] = filmStock
            saveFilmStocks()
        }
    }
    
    func deleteFilmStock(_ filmStock: FilmStock) {
        filmStocks.removeAll { $0.id == filmStock.id }
        saveFilmStocks()
    }
    
    // Helper to group films by product
    func groupedFilms() -> [GroupedFilm] {
        var groups: [String: GroupedFilm] = [:]
        
        for film in filmStocks {
            let key = "\(film.name)_\(film.manufacturer)_\(film.type.rawValue)_\(film.filmSpeed)"
            
            if groups[key] == nil {
                groups[key] = GroupedFilm(
                    id: film.id,
                    name: film.name,
                    manufacturer: film.manufacturer,
                    type: film.type,
                    filmSpeed: film.filmSpeed,
                    formats: []
                )
            }
            
            groups[key]?.formats.append(GroupedFilm.FormatInfo(
                id: film.id,
                format: film.format,
                quantity: film.quantity,
                expireDate: film.expireDate,
                filmId: film.id
            ))
        }
        
        return Array(groups.values).sorted { film1, film2 in
            if film1.manufacturer != film2.manufacturer {
                return film1.manufacturer < film2.manufacturer
            }
            return film1.name < film2.name
        }
    }
}

private struct FilmStockDataWrapper: Codable {
    let filmstocks: [FilmStock]
}

