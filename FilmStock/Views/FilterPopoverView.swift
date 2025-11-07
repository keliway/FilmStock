//
//  FilterPopoverView.swift
//  FilmStock
//
//  Filter popover view
//

import SwiftUI

struct FilterPopoverView: View {
    @Binding var selectedManufacturers: Set<String>
    @Binding var selectedTypes: Set<FilmStock.FilmType>
    @Binding var selectedSpeedRanges: Set<String>
    @Binding var selectedFormats: Set<FilmStock.FilmFormat>
    @Binding var showExpiredOnly: Bool
    @Binding var hideEmpty: Bool
    @ObservedObject var dataManager: FilmStockDataManager
    @Environment(\.dismiss) var dismiss
    
    private let speedRanges = [
        ("<100", 0, 99),
        ("100", 100, 199),
        ("200", 200, 300),
        ("400", 301, 400),
        ("400+", 401, Int.max)
    ]
    
    // Get all films that match current filters (excluding the filter category being evaluated)
    private func getAvailableFilms(excludingCategory: FilterCategory) -> [GroupedFilm] {
        let allFilms = dataManager.groupedFilms()
        
        var filtered = allFilms
        
        // Apply hide empty filter
        if hideEmpty {
            filtered = filtered.filter { group in
                group.formats.contains { $0.quantity > 0 }
            }
        }
        
        // Apply filters except the one being evaluated
        if excludingCategory != .manufacturer && !selectedManufacturers.isEmpty {
            filtered = filtered.filter { selectedManufacturers.contains($0.manufacturer) }
        }
        
        if excludingCategory != .type && !selectedTypes.isEmpty {
            filtered = filtered.filter { selectedTypes.contains($0.type) }
        }
        
        if excludingCategory != .speed && !selectedSpeedRanges.isEmpty {
            filtered = filtered.filter { group in
                selectedSpeedRanges.contains { rangeKey in
                    if let range = speedRanges.first(where: { $0.0 == rangeKey }) {
                        return group.filmSpeed >= range.1 && group.filmSpeed <= range.2
                    }
                    return false
                }
            }
        }
        
        if excludingCategory != .format && !selectedFormats.isEmpty {
            filtered = filtered.filter { group in
                group.formats.contains { selectedFormats.contains($0.format) }
            }
        }
        
        return filtered
    }
    
    private var availableManufacturers: [String] {
        let films = getAvailableFilms(excludingCategory: .manufacturer)
        return Array(Set(films.map { $0.manufacturer })).sorted()
    }
    
    private var availableTypes: [FilmStock.FilmType] {
        let films = getAvailableFilms(excludingCategory: .type)
        let availableTypeSet = Set(films.map { $0.type })
        return FilmStock.FilmType.allCases.filter { availableTypeSet.contains($0) }
    }
    
    private var availableSpeedRanges: [String] {
        let films = getAvailableFilms(excludingCategory: .speed)
        let availableSpeeds = Set(films.map { $0.filmSpeed })
        
        return speedRanges.filter { range in
            availableSpeeds.contains { speed in
                speed >= range.1 && speed <= range.2
            }
        }.map { $0.0 }
    }
    
    private var availableFormats: [FilmStock.FilmFormat] {
        let films = getAvailableFilms(excludingCategory: .format)
        let availableFormatSet = Set(films.flatMap { $0.formats.map { $0.format } })
        return FilmStock.FilmFormat.allCases.filter { availableFormatSet.contains($0) }
    }
    
    enum FilterCategory {
        case manufacturer, type, speed, format
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Manufacturer chips
                    FilterChipSection(
                        title: "Manufacturer",
                        items: availableManufacturers,
                        selection: Binding(
                            get: { selectedManufacturers },
                            set: { newValue in
                                selectedManufacturers = newValue
                                // Clear unavailable type selections
                                let availableTypeSet = Set(availableTypes)
                                selectedTypes = selectedTypes.filter { availableTypeSet.contains($0) }
                            }
                        )
                    )
                    
                    // Type chips
                    FilterChipSection(
                        title: "Type",
                        items: availableTypes.map { $0.displayName },
                        selection: Binding(
                            get: { Set(selectedTypes.map { $0.displayName }) },
                            set: { newValue in
                                selectedTypes = Set(newValue.compactMap { name in
                                    availableTypes.first { $0.displayName == name }
                                })
                            }
                        )
                    )
                    
                    // Speed ranges
                    FilterChipSection(
                        title: "Speed",
                        items: availableSpeedRanges,
                        selection: Binding(
                            get: { selectedSpeedRanges },
                            set: { newValue in
                                selectedSpeedRanges = newValue.intersection(Set(availableSpeedRanges))
                            }
                        )
                    )
                    
                    // Format chips
                    FilterChipSection(
                        title: "Format",
                        items: availableFormats.map { $0.displayName },
                        selection: Binding(
                            get: { Set(selectedFormats.map { $0.displayName }) },
                            set: { newValue in
                                selectedFormats = Set(newValue.compactMap { name in
                                    availableFormats.first { $0.displayName == name }
                                })
                            }
                        )
                    )
                    
                    // Toggles
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Options")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Toggle("Show only expired films", isOn: $showExpiredOnly)
                        Toggle("Hide empty", isOn: $hideEmpty)
                    }
                }
                .padding()
            }
            .navigationTitle("filter.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("action.done") {
                        // Clean up any selections that are no longer available
                        let availableManufacturerSet = Set(availableManufacturers)
                        selectedManufacturers = selectedManufacturers.intersection(availableManufacturerSet)
                        
                        let availableTypeSet = Set(availableTypes)
                        selectedTypes = selectedTypes.filter { availableTypeSet.contains($0) }
                        
                        let availableSpeedSet = Set(availableSpeedRanges)
                        selectedSpeedRanges = selectedSpeedRanges.intersection(availableSpeedSet)
                        
                        let availableFormatSet = Set(availableFormats)
                        selectedFormats = selectedFormats.filter { availableFormatSet.contains($0) }
                        
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Clean up selections when view appears
                let availableManufacturerSet = Set(availableManufacturers)
                selectedManufacturers = selectedManufacturers.intersection(availableManufacturerSet)
                
                let availableTypeSet = Set(availableTypes)
                selectedTypes = selectedTypes.filter { availableTypeSet.contains($0) }
                
                let availableSpeedSet = Set(availableSpeedRanges)
                selectedSpeedRanges = selectedSpeedRanges.intersection(availableSpeedSet)
                
                let availableFormatSet = Set(availableFormats)
                selectedFormats = selectedFormats.filter { availableFormatSet.contains($0) }
            }
        }
    }
}

