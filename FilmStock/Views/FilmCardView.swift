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
        HStack(alignment: .top, spacing: 0) {
            // Image
            Group {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.secondary)
                        )
                }
            }
            .padding(.leading, 16)
            .padding(.top, 12)
            .padding(.trailing, 8)
            
            // Content
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Text(groupedFilm.manufacturer)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(groupedFilm.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                HStack(spacing: 8) {
                    if groupedFilm.type == .color {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            .red, .orange, .yellow, .green, .blue, .purple
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 12, height: 12)
                            
                            Text(groupedFilm.type.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else if groupedFilm.type == .slide {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            .red, .orange, .yellow, .green, .blue, .purple
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 12, height: 12)
                                .overlay(
                                    Circle()
                                        .stroke(Color.black, lineWidth: 1.5)
                                )
                            
                            Text(groupedFilm.type.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Label(groupedFilm.type.displayName, systemImage: typeIcon)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Label("ISO \(groupedFilm.filmSpeed)", systemImage: "speedometer")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Format chips
                HStack(spacing: 8) {
                    ForEach(groupedFilm.formats) { format in
                        HStack(spacing: 6) {
                            Text("\(format.format.displayName):")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("\(format.quantity)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                }
            }
            .padding()
            .padding(.trailing, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
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
    
    private func loadImage() {
        // First, try user-uploaded image if imageName is specified
        if let customImageName = groupedFilm.imageName {
            if let userImage = ImageStorage.shared.loadImage(filename: customImageName, manufacturer: groupedFilm.manufacturer) {
                self.image = userImage
                return
            }
        }
        
        // Then try bundle images
        var variations: [String] = []
        
        // First, try custom imageName if specified (for bundle images)
        if let customImageName = groupedFilm.imageName {
            variations.append(customImageName + ".jpg")
            variations.append(customImageName.lowercased() + ".jpg")
        }
        
        // Then try auto-detected name from film name
        let baseName = groupedFilm.name.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "", options: .regularExpression)
        variations.append(contentsOf: [
            baseName + ".jpg",                    // Original case: "Pro400H.jpg"
            baseName.lowercased() + ".jpg",       // Lowercase: "pro400h.jpg"
            baseName.capitalized + ".jpg",        // Capitalized: "Pro400h.jpg"
            baseName.uppercased() + ".jpg"        // Uppercase: "PRO400H.jpg"
        ])
        
        // Add variation where only first letter is capitalized and rest is lowercase
        // This handles cases like "Pro400H" -> "Pro400h"
        if baseName.count > 1 {
            let firstChar = String(baseName.prefix(1)).uppercased()
            let rest = String(baseName.dropFirst()).lowercased()
            variations.append((firstChar + rest) + ".jpg")
        }
        
        // Try bundle with manufacturer subdirectory structure
        let manufacturerName = groupedFilm.manufacturer
        
        // Try multiple methods to find images
        var imagePaths: [URL] = []
        
        guard let resourcePath = Bundle.main.resourcePath else { return }
        let resourceURL = URL(fileURLWithPath: resourcePath, isDirectory: true)
        let imagesURL = resourceURL.appendingPathComponent("images", isDirectory: true)
        
        // When images folder is added as a group (yellow folder in Xcode),
        // Xcode flattens subdirectories, so files are in images/ directly
        // Try flattened structure first (most likely for groups)
        for variation in variations {
            let imageURL = imagesURL.appendingPathComponent(variation, isDirectory: false)
            imagePaths.append(imageURL)
        }
        
        // Also try manufacturer subdirectory structure (in case folder references are used)
        let manufacturerURL = imagesURL.appendingPathComponent(manufacturerName, isDirectory: true)
        for variation in variations {
            let imageURL = manufacturerURL.appendingPathComponent(variation, isDirectory: false)
            imagePaths.append(imageURL)
        }
        
        // Try Bundle.main.url methods
        for variation in variations {
            let resourceName = variation.replacingOccurrences(of: ".jpg", with: "")
            // Try with subdirectory
            if let bundleURL = Bundle.main.url(forResource: resourceName, withExtension: "jpg", subdirectory: "images/\(manufacturerName)") {
                imagePaths.append(bundleURL)
            }
            // Try without subdirectory (flattened)
            if let bundleURL = Bundle.main.url(forResource: resourceName, withExtension: "jpg", subdirectory: "images") {
                imagePaths.append(bundleURL)
            }
            // Try at bundle root
            if let bundleURL = Bundle.main.url(forResource: resourceName, withExtension: "jpg") {
                imagePaths.append(bundleURL)
            }
        }
        
        // Try all paths
        for imageURL in imagePaths {
            if FileManager.default.fileExists(atPath: imageURL.path),
               let data = try? Data(contentsOf: imageURL),
               let uiImage = UIImage(data: data) {
                self.image = uiImage
                return
            }
        }
    }
}

