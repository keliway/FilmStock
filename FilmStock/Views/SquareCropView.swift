//
//  SquareCropView.swift
//  FilmStock
//
//  Square crop view for photo library images
//

import SwiftUI

struct SquareCropView: View {
    let image: UIImage
    let onCrop: (UIImage) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    
    private var cropSize: CGFloat {
        min(UIScreen.main.bounds.width, UIScreen.main.bounds.height) * 0.8
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    // Image with pan and zoom
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .gesture(
                            SimultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let delta = value / lastScale
                                        lastScale = value
                                        scale = min(max(scale * delta, 1.0), 4.0)
                                    }
                                    .onEnded { _ in
                                        lastScale = 1.0
                                    },
                                DragGesture()
                                    .onChanged { value in
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                        )
                    
                    // Overlay with square crop area
                    VStack {
                        Spacer()
                        ZStack {
                            // Darkened areas
                            Rectangle()
                                .fill(Color.black.opacity(0.5))
                                .frame(height: (geometry.size.height - cropSize) / 2)
                                .frame(maxWidth: .infinity)
                            
                            HStack {
                                Rectangle()
                                    .fill(Color.black.opacity(0.5))
                                    .frame(width: (geometry.size.width - cropSize) / 2)
                                    .frame(height: cropSize)
                                
                                // Square crop area (transparent)
                                Rectangle()
                                    .fill(Color.clear)
                                    .frame(width: cropSize, height: cropSize)
                                    .border(Color.white, width: 2)
                                
                                Rectangle()
                                    .fill(Color.black.opacity(0.5))
                                    .frame(width: (geometry.size.width - cropSize) / 2)
                                    .frame(height: cropSize)
                            }
                            
                            Rectangle()
                                .fill(Color.black.opacity(0.5))
                                .frame(height: (geometry.size.height - cropSize) / 2)
                                .frame(maxWidth: .infinity)
                        }
                        Spacer()
                    }
                }
            }
            .navigationTitle("Crop Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        cropImage()
                    }
                }
            }
        }
    }
    
    private func cropImage() {
        let cropSize = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height) * 0.8
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        // Calculate the actual image size in the view
        let imageSize = image.size
        let imageAspectRatio = imageSize.width / imageSize.height
        let viewSize = CGSize(width: screenWidth, height: screenHeight)
        
        var displayedImageSize: CGSize
        var displayedImageOrigin: CGPoint
        
        if imageAspectRatio > 1 {
            // Landscape image
            displayedImageSize = CGSize(width: viewSize.width, height: viewSize.width / imageAspectRatio)
            displayedImageOrigin = CGPoint(x: 0, y: (viewSize.height - displayedImageSize.height) / 2)
        } else {
            // Portrait or square image
            displayedImageSize = CGSize(width: viewSize.height * imageAspectRatio, height: viewSize.height)
            displayedImageOrigin = CGPoint(x: (viewSize.width - displayedImageSize.width) / 2, y: 0)
        }
        
        // Apply scale
        let scaledSize = CGSize(width: displayedImageSize.width * scale, height: displayedImageSize.height * scale)
        let scaledOrigin = CGPoint(
            x: displayedImageOrigin.x - (scaledSize.width - displayedImageSize.width) / 2 + offset.width,
            y: displayedImageOrigin.y - (scaledSize.height - displayedImageSize.height) / 2 + offset.height
        )
        
        // Calculate crop rect in image coordinates
        let cropCenterX = screenWidth / 2
        let cropCenterY = screenHeight / 2
        
        let relativeX = (cropCenterX - scaledOrigin.x) / scaledSize.width
        let relativeY = (cropCenterY - scaledOrigin.y) / scaledSize.height
        
        let cropSizeInImage = cropSize / scaledSize.width
        
        let cropX = (relativeX - cropSizeInImage / 2) * imageSize.width
        let cropY = (relativeY - cropSizeInImage / 2) * imageSize.height
        let cropWidth = cropSizeInImage * imageSize.width
        let cropHeight = cropSizeInImage * imageSize.height
        
        let cropRect = CGRect(
            x: max(0, min(cropX, imageSize.width - cropWidth)),
            y: max(0, min(cropY, imageSize.height - cropHeight)),
            width: min(cropWidth, imageSize.width),
            height: min(cropHeight, imageSize.height)
        )
        
        // Perform crop
        if let cgImage = image.cgImage?.cropping(to: cropRect) {
            let croppedImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
            onCrop(croppedImage)
        } else {
            // Fallback: crop center square
            let size = min(imageSize.width, imageSize.height)
            let x = (imageSize.width - size) / 2
            let y = (imageSize.height - size) / 2
            if let cgImage = image.cgImage?.cropping(to: CGRect(x: x, y: y, width: size, height: size)) {
                let croppedImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
                onCrop(croppedImage)
            }
        }
    }
}

