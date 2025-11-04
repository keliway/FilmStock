//
//  FilterSectionView.swift
//  FilmStock
//
//  Filter controls (iOS HIG style)
//

import SwiftUI

struct FilterSectionView: View {
    @Binding var selectedManufacturers: Set<String>
    @Binding var selectedTypes: Set<FilmStock.FilmType>
    @Binding var selectedSpeedRanges: Set<String>
    @Binding var selectedFormats: Set<FilmStock.FilmFormat>
    @Binding var showExpiredOnly: Bool
    @Binding var hideEmpty: Bool
    @ObservedObject var dataManager: FilmStockDataManager
    
    @State private var isExpanded = false
    
    private var manufacturers: [String] {
        Array(Set(dataManager.filmStocks.map { $0.manufacturer })).sorted()
    }
    
    private let speedRanges = ["<100", "100", "200", "400", ">400"]
    
    var body: some View {
        DisclosureGroup("Filters", isExpanded: $isExpanded) {
            VStack(spacing: 16) {
                // Manufacturer chips
                FilterChipSection(
                    title: "Manufacturer",
                    items: manufacturers,
                    selection: $selectedManufacturers
                )
                
                // Type chips
                FilterChipSection(
                    title: "Type",
                    items: FilmStock.FilmType.allCases.map { $0.displayName },
                    selection: Binding(
                        get: { Set(selectedTypes.map { $0.displayName }) },
                        set: { newValue in
                            selectedTypes = Set(newValue.compactMap { name in
                                FilmStock.FilmType.allCases.first { $0.displayName == name }
                            })
                        }
                    )
                )
                
                // Speed ranges
                FilterChipSection(
                    title: "Speed",
                    items: speedRanges,
                    selection: $selectedSpeedRanges
                )
                
                // Format chips
                FilterChipSection(
                    title: "Format",
                    items: FilmStock.FilmFormat.allCases.map { $0.displayName },
                    selection: Binding(
                        get: { Set(selectedFormats.map { $0.displayName }) },
                        set: { newValue in
                            selectedFormats = Set(newValue.compactMap { name in
                                FilmStock.FilmFormat.allCases.first { $0.displayName == name }
                            })
                        }
                    )
                )
                
                // Toggles
                VStack(spacing: 12) {
                    Toggle("Show only expired films", isOn: $showExpiredOnly)
                    Toggle("Hide empty", isOn: $hideEmpty)
                }
                .font(.subheadline)
            }
            .padding(.vertical, 8)
        }
        .padding(.horizontal)
    }
}

struct FilterChipSection: View {
    let title: String
    let items: [String]
    @Binding var selection: Set<String>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(items, id: \.self) { item in
                        Button {
                            if selection.contains(item) {
                                selection.remove(item)
                            } else {
                                selection.insert(item)
                            }
                        } label: {
                            Text(item)
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selection.contains(item) ? Color.accentColor : Color.secondary.opacity(0.2))
                                .foregroundColor(selection.contains(item) ? .white : .primary)
                                .cornerRadius(8)
                        }
                    }
                }
            }
        }
    }
}

