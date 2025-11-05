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
    
    private let speedRanges = ["Super slow", "Slow", "Normal", "Fast", "Super fast"]
    
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
                .padding(.trailing, 8)
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
                                .background(backgroundForItem(item, isSelected: selection.contains(item)))
                                .foregroundColor(foregroundColorForItem(item, isSelected: selection.contains(item)))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(borderColorForItem(item, isSelected: selection.contains(item)), lineWidth: borderWidthForItem(item, isSelected: selection.contains(item)))
                                )
                        }
                    }
                }
            }
        }
    }
    
    private func backgroundForItem(_ item: String, isSelected: Bool) -> some View {
        if title == "Type" && isSelected {
            // Get the film type from display name
            if let filmType = FilmStock.FilmType.allCases.first(where: { $0.displayName == item }) {
                switch filmType {
                case .bw:
                    return AnyView(Color.black)
                case .color:
                    return AnyView(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .red, .orange, .yellow, .green, .blue, .purple
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                case .slide:
                    return AnyView(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .red, .orange, .yellow, .green, .blue, .purple
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                case .instant:
                    return AnyView(Color.red)
                }
            }
        }
        
        // Default styling
        if isSelected {
            return AnyView(Color.accentColor)
        } else {
            return AnyView(Color.secondary.opacity(0.2))
        }
    }
    
    private func foregroundColorForItem(_ item: String, isSelected: Bool) -> Color {
        if title == "Type" && isSelected {
            if let filmType = FilmStock.FilmType.allCases.first(where: { $0.displayName == item }) {
                switch filmType {
                case .bw:
                    return .white
                case .color:
                    return .white
                case .slide:
                    return .black
                case .instant:
                    return .white
                }
            }
        }
        
        // Default styling
        return isSelected ? .white : .primary
    }
    
    private func borderColorForItem(_ item: String, isSelected: Bool) -> Color {
        // No borders for any film type toggles
        return .clear
    }
    
    private func borderWidthForItem(_ item: String, isSelected: Bool) -> CGFloat {
        // No borders for any film type toggles
        return 0
    }
}

