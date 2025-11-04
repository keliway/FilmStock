//
//  FilmCardView.swift
//  FilmStock
//
//  Card view for film stock (iOS HIG style)
//

import SwiftUI

struct FilmCardView: View {
    let groupedFilm: GroupedFilm
    @State private var image: UIImage?
    
    var body: some View {
        NavigationLink(value: groupedFilm) {
            HStack(spacing: 0) {
                // Content
                VStack(alignment: .leading, spacing: 12) {
                    Text(groupedFilm.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(groupedFilm.manufacturer)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Label(groupedFilm.type.displayName, systemImage: typeIcon)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Label("ISO \(groupedFilm.filmSpeed)", systemImage: "speedometer")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Format chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(groupedFilm.formats) { format in
                                HStack(spacing: 4) {
                                    Text(format.format.displayName)
                                    Text("\(format.quantity)")
                                }
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.2))
                                .cornerRadius(8)
                            }
                        }
                    }
                    
                    // Total quantity
                    Text(totalQuantityText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Image
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 100, height: 100)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.secondary)
                        )
                }
            }
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .onAppear {
            loadImage()
        }
    }
    
    private var typeIcon: String {
        switch groupedFilm.type {
        case .bw: return "circle.fill"
        case .color: return "circle"
        case .slide: return "photo"
        case .instant: return "camera"
        }
    }
    
    private var totalQuantityText: String {
        let totalRolls = groupedFilm.formats
            .filter { $0.format != .fourByFive }
            .reduce(0) { $0 + $1.quantity }
        let totalSheets = groupedFilm.formats
            .filter { $0.format == .fourByFive }
            .reduce(0) { $0 + $1.quantity }
        
        if totalSheets > 0 && totalRolls > 0 {
            return "Total: \(totalRolls) Rolls and \(totalSheets) Sheets"
        } else if totalSheets > 0 {
            return "Total: \(totalSheets) Sheets"
        } else {
            return "Total: \(totalRolls) Rolls"
        }
    }
    
    private func loadImage() {
        let imageName = groupedFilm.name.lowercased().replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression) + ".jpg"
        
        // Try Documents/images first (user uploaded)
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imagesDir = documentsURL.appendingPathComponent("images")
        let imageURL = imagesDir.appendingPathComponent(imageName)
        
        if let data = try? Data(contentsOf: imageURL),
           let uiImage = UIImage(data: data) {
            self.image = uiImage
        } else {
            // Try bundle (if images are included in app)
            if let bundleURL = Bundle.main.url(forResource: imageName.replacingOccurrences(of: ".jpg", with: ""), withExtension: "jpg", subdirectory: "images"),
               let data = try? Data(contentsOf: bundleURL),
               let uiImage = UIImage(data: data) {
                self.image = uiImage
            }
        }
    }
}

