//
//  FilmRowView.swift
//  FilmStock
//
//  Table row view (iOS List style)
//

import SwiftUI

struct FilmRowView: View {
    let groupedFilm: GroupedFilm
    @State private var image: UIImage?
    
    var body: some View {
        NavigationLink(value: groupedFilm) {
            HStack(spacing: 12) {
                // Logo (small)
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 20, height: 20)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 20, height: 20)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(groupedFilm.name)
                        .font(.body)
                    
                    Text(groupedFilm.manufacturer)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Format quantities
                HStack(spacing: 16) {
                    formatQty(groupedFilm.formats, format: .thirtyFive)
                    formatQty(groupedFilm.formats, format: .oneTwenty)
                    formatQty(groupedFilm.formats, format: .fourByFive)
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .onAppear {
            loadImage()
        }
    }
    
    @ViewBuilder
    private func formatQty(_ formats: [GroupedFilm.FormatInfo], format: FilmStock.FilmFormat) -> some View {
        let qty = formats
            .filter { formatQty($0.format) == format }
            .reduce(0) { $0 + $1.quantity }
        
        Text(qty > 0 ? "\(qty)" : "-")
            .frame(width: 30)
            .multilineTextAlignment(.center)
    }
    
    private func formatQty(_ format: FilmStock.FilmFormat) -> FilmStock.FilmFormat {
        switch format {
        case .oneTwenty, .oneTwentySeven:
            return .oneTwenty
        default:
            return format
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

