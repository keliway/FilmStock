//
//  ImageCatalogView.swift
//  FilmStock
//
//  Gallery view showing all custom images grouped by manufacturer
//

import SwiftUI

struct ImageCatalogView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedImage: UIImage?
    @State private var imagesByManufacturer: [String: [(imageName: String, image: UIImage)]] = [:]
    
    var sortedManufacturers: [String] {
        imagesByManufacturer.keys.sorted()
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if imagesByManufacturer.isEmpty {
                    ContentUnavailableView(
                        "No Images Available",
                        systemImage: "photo.on.rectangle",
                        description: Text("No default images found in the bundle")
                    )
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 24) {
                            ForEach(sortedManufacturers, id: \.self) { manufacturer in
                                if let images = imagesByManufacturer[manufacturer] {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text(manufacturer)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                            .padding(.horizontal, 16)
                                        
                                        LazyVGrid(columns: [
                                            GridItem(.flexible(), spacing: 8),
                                            GridItem(.flexible(), spacing: 8),
                                            GridItem(.flexible(), spacing: 8)
                                        ], spacing: 8) {
                                            ForEach(images, id: \.imageName) { item in
                                                Button {
                                                    selectedImage = item.image
                                                    dismiss()
                                                } label: {
                                                    Image(uiImage: item.image)
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                        .frame(width: (UIScreen.main.bounds.width - 64) / 3, height: (UIScreen.main.bounds.width - 64) / 3)
                                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 8)
                                                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                                        )
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 16)
                    }
                }
            }
            .navigationTitle("Image Catalog")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadImages()
            }
        }
    }
    
    private func loadImages() {
        imagesByManufacturer = ImageStorage.shared.getAllDefaultImages()
    }
}

