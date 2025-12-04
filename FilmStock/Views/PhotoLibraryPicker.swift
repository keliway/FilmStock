//
//  PhotoLibraryPicker.swift
//  FilmStock
//
//  Photo library picker using PHPicker with cropping
//

import SwiftUI
import PhotosUI

struct PhotoLibraryPicker: View {
    @Binding var selectedImage: UIImage?
    @Binding var isPresented: Bool
    
    @State private var showCropper = false
    @State private var rawSelectedImage: UIImage?
    @State private var selectedItem: PhotosPickerItem?
    
    var body: some View {
        PhotosPicker(
            selection: $selectedItem,
            matching: .images,
            photoLibrary: .shared()
        ) {
            EmptyView()
        }
        .photosPickerStyle(.inline)
        .photosPickerDisabledCapabilities([.collectionNavigation, .search])
        .ignoresSafeArea()
        .onChange(of: selectedItem) { oldValue, newValue in
            if let newValue = newValue {
                loadImage(from: newValue)
            }
        }
        .fullScreenCover(isPresented: $showCropper) {
            if let image = rawSelectedImage {
                ImageCropperView(
                    image: image,
                    onComplete: { croppedImage in
                        selectedImage = croppedImage
                        isPresented = false
                    },
                    onCancel: {
                        rawSelectedImage = nil
                        selectedItem = nil
                        showCropper = false
                    }
                )
            }
        }
    }
    
    private func loadImage(from item: PhotosPickerItem) {
        item.loadTransferable(type: Data.self) { result in
            switch result {
            case .success(let data):
                if let data = data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        rawSelectedImage = image
                        showCropper = true
                    }
                }
            case .failure(let error):
                print("Error loading image: \(error)")
            }
        }
    }
}

// MARK: - Photo Library Picker Sheet

struct PhotoLibraryPickerSheet: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Binding var isPresented: Bool
    var onImageSelected: ((UIImage) -> Void)?
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .current
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoLibraryPickerSheet
        
        init(_ parent: PhotoLibraryPickerSheet) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let result = results.first else {
                // User cancelled - just dismiss
                parent.isPresented = false
                return
            }
            
            let itemProvider = result.itemProvider
            
            // Load image
            if itemProvider.canLoadObject(ofClass: UIImage.self) {
                itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                    guard let self = self else { return }
                    
                    DispatchQueue.main.async {
                        if let image = object as? UIImage {
                            let fixedImage = self.fixImageOrientation(image)
                            // Store the image and dismiss - onDismiss will show cropper
                            self.parent.onImageSelected?(fixedImage)
                        }
                        // Always dismiss after attempting to load
                        self.parent.isPresented = false
                    }
                }
            } else {
                parent.isPresented = false
            }
        }
        
        private func fixImageOrientation(_ image: UIImage) -> UIImage {
            if image.imageOrientation == .up {
                return image
            }
            
            UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
            image.draw(in: CGRect(origin: .zero, size: image.size))
            let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            return normalizedImage ?? image
        }
    }
}

// MARK: - Combined Image Source Picker

struct ImageSourcePicker: View {
    @Binding var finalImage: UIImage?
    @Binding var isPresented: Bool
    
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var showLibraryCropper = false
    @State private var imageToCrop: UIImage?
    
    var body: some View {
        VStack(spacing: 12) {
            // Drag indicator
            Capsule()
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
            
            // Camera option
            Button {
                showCamera = true
            } label: {
                HStack {
                    Image(systemName: "camera.fill")
                        .font(.body)
                        .frame(width: 24)
                    Text("image.takePhoto")
                        .font(.body)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            
            // Library option
            Button {
                showLibrary = true
            } label: {
                HStack {
                    Image(systemName: "photo.on.rectangle")
                        .font(.body)
                        .frame(width: 24)
                    Text("image.chooseFromLibrary")
                        .font(.body)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .presentationDetents([.height(180)])
        .presentationDragIndicator(.hidden)
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(capturedImage: $finalImage, isPresented: $showCamera)
                .onChange(of: finalImage) { oldValue, newValue in
                    if newValue != nil {
                        isPresented = false
                    }
                }
        }
        .sheet(isPresented: $showLibrary) {
            PhotoLibraryPickerSheet(
                selectedImage: $finalImage,
                isPresented: $showLibrary,
                onImageSelected: { image in
                    imageToCrop = image
                }
            )
        }
        .onChange(of: showLibrary) { oldValue, newValue in
            // When library sheet is dismissed and we have an image, show cropper
            if oldValue == true && newValue == false && imageToCrop != nil {
                // Small delay to ensure sheet is fully dismissed
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    showLibraryCropper = true
                }
            }
        }
        .fullScreenCover(isPresented: $showLibraryCropper) {
            if let image = imageToCrop {
                LibraryCropperWrapperView(
                    image: image,
                    onComplete: { croppedImage in
                        finalImage = croppedImage
                        showLibraryCropper = false
                        imageToCrop = nil
                    },
                    onCancel: {
                        showLibraryCropper = false
                        imageToCrop = nil
                    }
                )
            }
        }
        .onChange(of: finalImage) { oldValue, newValue in
            // Close the picker sheet when we have a final image
            if newValue != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isPresented = false
                }
            }
        }
    }
}

// MARK: - Library Cropper Wrapper (handles the fullScreenCover)

struct LibraryCropperWrapperView: View {
    let image: UIImage
    var onComplete: (UIImage) -> Void
    var onCancel: () -> Void
    
    @State private var processedImage: UIImage?
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var cropSize: CGFloat = 300
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let size = min(geometry.size.width - 32, geometry.size.height - 100)
                
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    if let img = processedImage {
                        VStack {
                            Spacer()
                            
                            ZStack {
                                Image(uiImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: size, height: size)
                                    .scaleEffect(scale)
                                    .offset(offset)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .gesture(
                                        SimultaneousGesture(
                                            MagnificationGesture()
                                                .onChanged { value in
                                                    scale = max(1.0, min(lastScale * value, 5.0))
                                                }
                                                .onEnded { _ in
                                                    lastScale = scale
                                                    withAnimation(.spring(response: 0.3)) {
                                                        constrainOffset(size)
                                                    }
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
                                                    withAnimation(.spring(response: 0.3)) {
                                                        constrainOffset(size)
                                                    }
                                                }
                                        )
                                    )
                                
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white, lineWidth: 2)
                                    .frame(width: size, height: size)
                                
                                GridLinesView(size: size)
                            }
                            
                            Spacer()
                            
                            Text("cropper.hint")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.bottom, 20)
                        }
                        .onAppear {
                            cropSize = size
                        }
                        .onChange(of: size) { _, newSize in
                            cropSize = newSize
                        }
                    } else {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    }
                }
            }
            .navigationTitle("cropper.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.done") {
                        if let img = processedImage {
                            let cropped = performCrop(image: img)
                            onComplete(cropped)
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            processImage()
        }
    }
    
    private func processImage() {
        DispatchQueue.global(qos: .userInitiated).async {
            let size = image.size
            UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: size))
            let rendered = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            DispatchQueue.main.async {
                processedImage = rendered ?? image
            }
        }
    }
    
    private func constrainOffset(_ cropSize: CGFloat) {
        guard let img = processedImage else { return }
        
        let imageAspect = img.size.width / img.size.height
        
        // Calculate displayed image size based on aspectFill behavior
        var displayedWidth: CGFloat
        var displayedHeight: CGFloat
        
        if imageAspect > 1 {
            // Landscape: height fits, width extends
            displayedHeight = cropSize * scale
            displayedWidth = displayedHeight * imageAspect
        } else {
            // Portrait or square: width fits, height extends
            displayedWidth = cropSize * scale
            displayedHeight = displayedWidth / imageAspect
        }
        
        // Calculate max offset based on how much image extends beyond crop area
        let maxOffsetX = max(0, (displayedWidth - cropSize) / 2)
        let maxOffsetY = max(0, (displayedHeight - cropSize) / 2)
        
        offset.width = max(-maxOffsetX, min(maxOffsetX, offset.width))
        offset.height = max(-maxOffsetY, min(maxOffsetY, offset.height))
        lastOffset = offset
    }
    
    private func performCrop(image: UIImage) -> UIImage {
        let imageSize = image.size
        let imageAspect = imageSize.width / imageSize.height
        
        var sourceRect: CGRect
        if imageAspect > 1 {
            let visibleWidth = imageSize.height
            let offsetX = (imageSize.width - visibleWidth) / 2
            sourceRect = CGRect(x: offsetX, y: 0, width: visibleWidth, height: imageSize.height)
        } else {
            let visibleHeight = imageSize.width
            let offsetY = (imageSize.height - visibleHeight) / 2
            sourceRect = CGRect(x: 0, y: offsetY, width: imageSize.width, height: visibleHeight)
        }
        
        let visibleSize = sourceRect.width / scale
        let offsetRatioX = -offset.width / (cropSize * scale)
        let offsetRatioY = -offset.height / (cropSize * scale)
        
        let cropX = sourceRect.origin.x + (sourceRect.width - visibleSize) / 2 + offsetRatioX * sourceRect.width
        let cropY = sourceRect.origin.y + (sourceRect.height - visibleSize) / 2 + offsetRatioY * sourceRect.height
        
        var cropRect = CGRect(x: cropX, y: cropY, width: visibleSize, height: visibleSize)
        
        cropRect.origin.x = max(0, min(cropRect.origin.x, imageSize.width - cropRect.width))
        cropRect.origin.y = max(0, min(cropRect.origin.y, imageSize.height - cropRect.height))
        
        guard let cgImage = image.cgImage,
              let cropped = cgImage.cropping(to: cropRect) else {
            return image
        }
        
        let outputSize: CGFloat = 1000
        UIGraphicsBeginImageContextWithOptions(CGSize(width: outputSize, height: outputSize), false, 1.0)
        UIImage(cgImage: cropped).draw(in: CGRect(x: 0, y: 0, width: outputSize, height: outputSize))
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return result ?? image
    }
}

// MARK: - Grid Lines View

struct GridLinesView: View {
    let size: CGFloat
    
    var body: some View {
        Canvas { context, canvasSize in
            let lineColor = Color.white.opacity(0.3)
            let startX = (canvasSize.width - size) / 2
            let startY = (canvasSize.height - size) / 2
            
            for i in 1..<3 {
                var vPath = Path()
                vPath.move(to: CGPoint(x: startX + size * CGFloat(i) / 3, y: startY))
                vPath.addLine(to: CGPoint(x: startX + size * CGFloat(i) / 3, y: startY + size))
                context.stroke(vPath, with: .color(lineColor), lineWidth: 0.5)
                
                var hPath = Path()
                hPath.move(to: CGPoint(x: startX, y: startY + size * CGFloat(i) / 3))
                hPath.addLine(to: CGPoint(x: startX + size, y: startY + size * CGFloat(i) / 3))
                context.stroke(hPath, with: .color(lineColor), lineWidth: 0.5)
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    ImageSourcePicker(finalImage: .constant(nil), isPresented: .constant(true))
}

