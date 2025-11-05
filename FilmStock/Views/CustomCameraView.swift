//
//  CustomCameraView.swift
//  FilmStock
//
//  Custom camera using AVFoundation with 2x support
//

import SwiftUI
import AVFoundation
import UIKit

struct CustomCameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.delegate = context.coordinator
        controller.modalPresentationStyle = .fullScreen
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CameraViewControllerDelegate {
        let parent: CustomCameraView
        
        init(_ parent: CustomCameraView) {
            self.parent = parent
        }
        
        func didCaptureImage(_ image: UIImage) {
            parent.image = image
            parent.isPresented = false
        }
        
        func didCancel() {
            parent.isPresented = false
        }
    }
}

protocol CameraViewControllerDelegate: AnyObject {
    func didCaptureImage(_ image: UIImage)
    func didCancel()
}

class CameraViewController: UIViewController {
    weak var delegate: CameraViewControllerDelegate?
    
    private var captureSession: AVCaptureSession!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var photoOutput: AVCapturePhotoOutput!
    private var videoDeviceInput: AVCaptureDeviceInput!
    private var maskFrame: CGRect = .zero
    private var overlayView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        modalPresentationStyle = .fullScreen
        setupCamera()
        setupOverlay()
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        // Update preview and overlay when safe area changes
        viewDidLayoutSubviews()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.stopRunning()
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Ensure preview layer fills entire screen including safe areas
        let bounds = view.bounds
        if bounds.width > 0 && bounds.height > 0 {
            // Use full screen bounds, ignoring safe areas
            previewLayer?.frame = bounds
            // Ensure overlay also fills the screen
            if overlayView != nil {
                overlayView.frame = bounds
            }
        }
        updateOverlay()
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .slide
    }
    
    private func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .photo
        
        guard let videoDevice = getTelephotoCamera() ?? getWideCamera() else {
            print("No camera available")
            return
        }
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
                videoDeviceInput = videoInput
            }
            
            // Check if this is a telephoto camera by checking device type
            let isTelephoto = videoDevice.deviceType == .builtInTelephotoCamera ||
                             videoDevice.deviceType == .builtInDualCamera ||
                             videoDevice.deviceType == .builtInDualWideCamera
            
            // If we're using wide camera (not telephoto), apply 2x zoom
            if !isTelephoto {
                try videoDevice.lockForConfiguration()
                // Apply 2x zoom (or maximum available zoom, whichever is smaller)
                let maxZoom = videoDevice.activeFormat.videoMaxZoomFactor
                let desiredZoom: CGFloat = 2.0
                videoDevice.videoZoomFactor = min(desiredZoom, maxZoom)
                videoDevice.unlockForConfiguration()
            }
            
            photoOutput = AVCapturePhotoOutput()
            if captureSession.canAddOutput(photoOutput) {
                captureSession.addOutput(photoOutput)
            }
            
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = view.bounds
            view.layer.insertSublayer(previewLayer, at: 0)
            
        } catch {
            print("Error setting up camera: \(error)")
        }
    }
    
    private func getTelephotoCamera() -> AVCaptureDevice? {
        // Try to find telephoto camera (2x)
        if let device = AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back) {
            return device
        }
        
        // Try to find dual camera and use telephoto
        if let device = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
            return device
        }
        
        // Try to find dual wide camera
        if let device = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back) {
            return device
        }
        
        return nil
    }
    
    private func getWideCamera() -> AVCaptureDevice? {
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    }
    
    private func setupOverlay() {
        // Ensure view has valid bounds before creating overlay
        let bounds = view.bounds
        guard bounds.width > 0 && bounds.height > 0 else {
            // Delay overlay setup if bounds aren't ready
            DispatchQueue.main.async {
                self.setupOverlay()
            }
            return
        }
        
        overlayView = UIView(frame: bounds)
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        overlayView.isUserInteractionEnabled = false
        view.addSubview(overlayView)
        
        // Add cancel button
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cancelButton)
        
        NSLayoutConstraint.activate([
            cancelButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            cancelButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20)
        ])
        
        // Add capture button
        let captureButton = UIButton(type: .custom)
        captureButton.backgroundColor = .white
        captureButton.layer.cornerRadius = 35
        captureButton.layer.borderWidth = 4
        captureButton.layer.borderColor = UIColor.white.cgColor
        captureButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(captureButton)
        
        NSLayoutConstraint.activate([
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.widthAnchor.constraint(equalToConstant: 70),
            captureButton.heightAnchor.constraint(equalToConstant: 70)
        ])
        
        updateOverlay()
    }
    
    private func updateOverlay() {
        let viewBounds = view.bounds
        let viewWidth = viewBounds.width
        let viewHeight = viewBounds.height
        
        // Ensure valid dimensions
        guard viewWidth > 0 && viewHeight > 0 else { return }
        
        // Calculate square frame (50% of smaller dimension, centered)
        let squareSize = min(viewWidth, viewHeight) * 0.5
        let x = (viewWidth - squareSize) / 2
        let y = (viewHeight - squareSize) / 2
        
        maskFrame = CGRect(x: x, y: y, width: squareSize, height: squareSize)
        
        // Update overlay
        overlayView.frame = viewBounds
        
        // Remove old border view
        overlayView.subviews.forEach { $0.removeFromSuperview() }
        
        // Create mask with rounded corners
        let path = UIBezierPath(rect: viewBounds)
        let cornerRadius: CGFloat = 12
        let squarePath = UIBezierPath(roundedRect: maskFrame, cornerRadius: cornerRadius)
        path.append(squarePath.reversing())
        
        let maskLayer = CAShapeLayer()
        maskLayer.path = path.cgPath
        overlayView.layer.mask = maskLayer
        
        // Add border rectangle with rounded corners
        let borderView = UIView(frame: maskFrame)
        borderView.layer.borderColor = UIColor.white.cgColor
        borderView.layer.borderWidth = 2
        borderView.backgroundColor = .clear
        borderView.layer.cornerRadius = cornerRadius
        overlayView.addSubview(borderView)
    }
    
    @objc private func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    @objc private func cancelTapped() {
        delegate?.didCancel()
    }
}

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let capturedImage = UIImage(data: imageData),
              let cgImage = capturedImage.cgImage else {
            return
        }
        
        // Crop to mask using preview layer's coordinate conversion
        let croppedImage = cropImageToMask(image: capturedImage, cgImage: cgImage, photo: photo)
        delegate?.didCaptureImage(croppedImage ?? capturedImage)
    }
    
    private func cropImageToMask(image: UIImage, cgImage: CGImage, photo: AVCapturePhoto) -> UIImage? {
        guard let previewLayer = previewLayer else {
            return nil
        }
        
        // Get image dimensions in pixels (not affected by orientation)
        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        let imageOrientation = image.imageOrientation
        
        // Get the preview layer's bounds
        let previewBounds = previewLayer.bounds
        
        // Calculate the actual preview area (accounting for video gravity)
        // Since we use .resizeAspectFill, the preview fills the bounds while maintaining aspect ratio
        let previewAspectRatio = previewBounds.width / previewBounds.height
        let imageAspectRatio = imageWidth / imageHeight
        
        // Calculate how the image is scaled to fill the preview
        var scaleX: CGFloat
        var scaleY: CGFloat
        var offsetX: CGFloat = 0
        var offsetY: CGFloat = 0
        
        if imageAspectRatio > previewAspectRatio {
            // Image is wider than preview - fills height, crops sides
            scaleY = imageHeight / previewBounds.height
            scaleX = scaleY
            let scaledImageWidth = previewBounds.width * scaleX
            offsetX = (imageWidth - scaledImageWidth) / 2
        } else {
            // Image is taller than preview - fills width, crops top/bottom
            scaleX = imageWidth / previewBounds.width
            scaleY = scaleX
            let scaledImageHeight = previewBounds.height * scaleY
            offsetY = (imageHeight - scaledImageHeight) / 2
        }
        
        // Convert mask frame from preview coordinates to image coordinates
        let cropX = (maskFrame.origin.x * scaleX) + offsetX
        let cropY = (maskFrame.origin.y * scaleY) + offsetY
        let cropWidth = maskFrame.width * scaleX
        let cropHeight = maskFrame.height * scaleY
        
        // Ensure crop rect is within image bounds and is valid
        let finalCropX = max(0, min(cropX, imageWidth - 1))
        let finalCropY = max(0, min(cropY, imageHeight - 1))
        let finalCropWidth = min(cropWidth, imageWidth - finalCropX)
        let finalCropHeight = min(cropHeight, imageHeight - finalCropY)
        
        guard finalCropWidth > 0 && finalCropHeight > 0 else {
            return nil
        }
        
        // Create crop rect in image coordinates
        let cropRect = CGRect(x: finalCropX, y: finalCropY, width: finalCropWidth, height: finalCropHeight)
        
        // Crop the image
        guard let croppedCGImage = cgImage.cropping(to: cropRect) else {
            return nil
        }
        
        return UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: imageOrientation)
    }
}

