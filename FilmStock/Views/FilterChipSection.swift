//
//  FilterChipSection.swift
//  FilmStock
//
//  Filter chip section component
//

import SwiftUI

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

