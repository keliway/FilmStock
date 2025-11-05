//
//  ImagePickerView.swift
//  FilmStock
//
//  Image picker with camera and photo library support
//

import SwiftUI
import PhotosUI

struct ImagePickerView: View {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) var dismiss
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var showingImagePicker = false
    @State private var showingCropView = false
    @State private var rawSelectedImage: UIImage?
    
    var body: some View {
        VStack(spacing: 20) {
            Button {
                sourceType = .camera
                showingImagePicker = true
            } label: {
                HStack {
                    Image(systemName: "camera.fill")
                    Text("Take Photo")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            Button {
                sourceType = .photoLibrary
                showingImagePicker = true
            } label: {
                HStack {
                    Image(systemName: "photo.on.rectangle")
                    Text("Choose from Library")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.secondary.opacity(0.2))
                .foregroundColor(.primary)
                .cornerRadius(10)
            }
            
            Button("Cancel") {
                dismiss()
            }
            .padding(.top)
        }
        .padding()
        .fullScreenCover(isPresented: Binding(
            get: { showingImagePicker && sourceType == .camera },
            set: { if !$0 { showingImagePicker = false } }
        )) {
            CustomCameraView(image: $rawSelectedImage, isPresented: $showingImagePicker)
        }
        .sheet(isPresented: Binding(
            get: { showingImagePicker && sourceType == .photoLibrary },
            set: { if !$0 { showingImagePicker = false } }
        )) {
            PhotoLibraryPicker(image: $rawSelectedImage, isPresented: $showingImagePicker)
        }
        .sheet(isPresented: $showingCropView) {
            if let image = rawSelectedImage {
                SquareCropView(image: image) { croppedImage in
                    selectedImage = croppedImage
                    dismiss()
                }
            }
        }
        .onChange(of: rawSelectedImage) { oldValue, newValue in
            if let newValue = newValue {
                if sourceType == .camera {
                    // For camera, we already have a square crop overlay, so use directly
                    selectedImage = newValue
                    dismiss()
                } else {
                    // For photo library, show crop view
                    showingCropView = true
                }
            }
        }
    }
}

struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        picker.modalPresentationStyle = .fullScreen
        picker.showsCameraControls = true
        picker.cameraFlashMode = .auto
        picker.cameraCaptureMode = .photo
        
        // Try to use rear camera (2x if available)
        if UIImagePickerController.isCameraDeviceAvailable(.rear) {
            picker.cameraDevice = .rear
        }
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // Set up overlay after the view has appeared
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.setupOverlay(for: uiViewController, coordinator: context.coordinator)
        }
    }
    
    private func setupOverlay(for picker: UIImagePickerController, coordinator: Coordinator) {
        // Get the actual camera preview bounds (accounting for safe areas)
        let viewBounds = picker.view.bounds
        let viewWidth = viewBounds.width
        let viewHeight = viewBounds.height
        
        // Calculate square frame (50% of smaller dimension, centered)
        let squareSize = min(viewWidth, viewHeight) * 0.5
        let x = (viewWidth - squareSize) / 2
        let y = (viewHeight - squareSize) / 2
        
        // Store mask frame for crop calculation
        coordinator.maskFrame = CGRect(x: x, y: y, width: squareSize, height: squareSize)
        coordinator.viewBounds = viewBounds
        
        // Remove existing overlay if any
        picker.cameraOverlayView = nil
        
        // Create overlay view
        let overlayView = UIView(frame: viewBounds)
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        overlayView.isUserInteractionEnabled = false
        
        // Create mask with rounded corners
        let path = UIBezierPath(rect: viewBounds)
        let cornerRadius: CGFloat = 12
        let squarePath = UIBezierPath(roundedRect: coordinator.maskFrame, cornerRadius: cornerRadius)
        path.append(squarePath.reversing())
        
        let maskLayer = CAShapeLayer()
        maskLayer.path = path.cgPath
        overlayView.layer.mask = maskLayer
        
        // Add border rectangle with rounded corners
        let borderView = UIView(frame: coordinator.maskFrame)
        borderView.layer.borderColor = UIColor.white.cgColor
        borderView.layer.borderWidth = 2
        borderView.backgroundColor = .clear
        borderView.layer.cornerRadius = cornerRadius
        overlayView.addSubview(borderView)
        
        picker.cameraOverlayView = overlayView
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        var maskFrame: CGRect = .zero
        var viewBounds: CGRect = .zero
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                // Calculate crop based on the mask frame
                let croppedImage = self.cropImageToMask(image: image, maskFrame: self.maskFrame, viewBounds: self.viewBounds)
                parent.image = croppedImage ?? image
            }
            parent.isPresented = false
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
        
        private func cropImageToMask(image: UIImage, maskFrame: CGRect, viewBounds: CGRect) -> UIImage? {
            // Get image dimensions
            let imageSize = image.size
            let imageOrientation = image.imageOrientation
            
            // Calculate aspect ratio of the image and view
            let imageAspectRatio = imageSize.width / imageSize.height
            let viewAspectRatio = viewBounds.width / viewBounds.height
            
            // Calculate scale factors - the image is scaled to fill the view while maintaining aspect ratio
            var scaleX: CGFloat
            var scaleY: CGFloat
            var offsetX: CGFloat = 0
            var offsetY: CGFloat = 0
            
            if imageAspectRatio > viewAspectRatio {
                // Image is wider - it fills height, crops sides
                scaleY = imageSize.height / viewBounds.height
                scaleX = scaleY
                let scaledImageWidth = viewBounds.width * scaleX
                offsetX = (imageSize.width - scaledImageWidth) / 2
            } else {
                // Image is taller - it fills width, crops top/bottom
                scaleX = imageSize.width / viewBounds.width
                scaleY = scaleX
                let scaledImageHeight = viewBounds.height * scaleY
                offsetY = (imageSize.height - scaledImageHeight) / 2
            }
            
            // Convert mask frame coordinates to image coordinates
            let cropX = (maskFrame.origin.x * scaleX) + offsetX
            let cropY = (maskFrame.origin.y * scaleY) + offsetY
            let cropWidth = maskFrame.width * scaleX
            let cropHeight = maskFrame.height * scaleY
            
            // Ensure crop rect is within image bounds
            let finalCropX = max(0, min(cropX, imageSize.width - cropWidth))
            let finalCropY = max(0, min(cropY, imageSize.height - cropHeight))
            let finalCropWidth = min(cropWidth, imageSize.width - finalCropX)
            let finalCropHeight = min(cropHeight, imageSize.height - finalCropY)
            
            let cropRect = CGRect(x: finalCropX, y: finalCropY, width: finalCropWidth, height: finalCropHeight)
            
            // Crop the image
            guard let cgImage = image.cgImage?.cropping(to: cropRect) else {
                return nil
            }
            
            return UIImage(cgImage: cgImage, scale: image.scale, orientation: imageOrientation)
        }
    }
}

struct PhotoLibraryPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: PhotoLibraryPicker
        
        init(_ parent: PhotoLibraryPicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.isPresented = false
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }
}

