//
//  CameraView.swift
//  FilmStock
//
//  Native camera view with pinch-to-zoom and square preview
//

import SwiftUI
import AVFoundation
import UIKit

struct CameraView: View {
    @Binding var capturedImage: UIImage?
    @Binding var isPresented: Bool
    @State private var showCropper = false
    @State private var rawCapturedImage: UIImage?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                CameraViewRepresentable(
                    capturedImage: $rawCapturedImage
                )
                .ignoresSafeArea()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") {
                        isPresented = false
                    }
                }
            }
        }
        .onChange(of: rawCapturedImage) { oldValue, newValue in
            if newValue != nil {
                showCropper = true
            }
        }
        .fullScreenCover(isPresented: $showCropper) {
            if let image = rawCapturedImage {
                ImageCropperView(
                    image: image,
                    onComplete: { croppedImage in
                        capturedImage = croppedImage
                        isPresented = false
                    },
                    onCancel: {
                        rawCapturedImage = nil
                        showCropper = false
                    }
                )
            }
        }
    }
}

// MARK: - Camera View Representable

struct CameraViewRepresentable: UIViewControllerRepresentable {
    @Binding var capturedImage: UIImage?
    
    func makeUIViewController(context: Context) -> CameraViewControllerNew {
        let controller = CameraViewControllerNew()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CameraViewControllerNew, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CameraViewControllerNewDelegate {
        let parent: CameraViewRepresentable
        
        init(_ parent: CameraViewRepresentable) {
            self.parent = parent
        }
        
        func didCaptureImage(_ image: UIImage) {
            parent.capturedImage = image
        }
    }
}

// MARK: - Camera View Controller Delegate

protocol CameraViewControllerNewDelegate: AnyObject {
    func didCaptureImage(_ image: UIImage)
}

// MARK: - Camera View Controller

class CameraViewControllerNew: UIViewController {
    weak var delegate: CameraViewControllerNewDelegate?
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var photoOutput: AVCapturePhotoOutput?
    private var videoDeviceInput: AVCaptureDeviceInput?
    
    private var currentZoomFactor: CGFloat = 1.0
    private var minZoomFactor: CGFloat = 1.0
    private var maxZoomFactor: CGFloat = 10.0
    
    private var squareOverlayView: UIView!
    private var captureButton: UIButton!
    private var zoomLabel: UILabel!
    private var lastLayoutBounds: CGRect = .zero
    private var squareFrame: CGRect = .zero // Store for cropping
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        checkCameraPermission()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopSession()
    }
    
    override var prefersStatusBarHidden: Bool { true }
    
    // MARK: - Setup
    
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupCamera()
                    } else {
                        self?.showPermissionDeniedUI()
                    }
                }
            }
        default:
            showPermissionDeniedUI()
        }
    }
    
    private func showPermissionDeniedUI() {
        let label = UILabel()
        label.text = NSLocalizedString("camera.permissionDenied", comment: "")
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40)
        ])
    }
    
    private func setupCamera() {
        let session = AVCaptureSession()
        
        guard let videoDevice = getBestCamera() else {
            return
        }
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            let output = AVCapturePhotoOutput()

            session.beginConfiguration()
            session.sessionPreset = .photo
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
                videoDeviceInput = videoInput
            }
            if session.canAddOutput(output) {
                session.addOutput(output)
                photoOutput = output
            }
            session.commitConfiguration()
            
            captureSession = session
            
            // Configure zoom limits
            minZoomFactor = videoDevice.minAvailableVideoZoomFactor
            maxZoomFactor = min(videoDevice.maxAvailableVideoZoomFactor, 10.0)
            currentZoomFactor = 1.0
            
            setupPreviewLayer()
            setupUI()
            setupGestures()
            
        } catch {
            print("Error setting up camera: \(error)")
        }
    }
    
    private func getBestCamera() -> AVCaptureDevice? {
        // Prefer wide angle camera for more flexibility with zoom
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            return device
        }
        return AVCaptureDevice.default(for: .video)
    }
    
    private func setupPreviewLayer() {
        guard let session = captureSession else { return }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer
    }
    
    private func setupUI() {
        // Square overlay with darkened corners
        setupSquareOverlay()
        
        // Capture button
        setupCaptureButton()
        
        // Zoom label
        setupZoomLabel()
    }
    
    private func setupSquareOverlay() {
        squareOverlayView = UIView(frame: view.bounds)
        squareOverlayView.isUserInteractionEnabled = false
        view.addSubview(squareOverlayView)
        
        updateSquareOverlay()
    }
    
    private func updateSquareOverlay() {
        guard squareOverlayView != nil else { return }
        
        // Remove existing layers safely (create copies to avoid mutation during iteration)
        if let sublayers = squareOverlayView.layer.sublayers {
            for layer in sublayers {
                layer.removeFromSuperlayer()
            }
        }
        for subview in squareOverlayView.subviews {
            subview.removeFromSuperview()
        }
        
        let bounds = view.bounds
        let squareSize = bounds.width - 32 // 16pt padding on each side
        let squareY = (bounds.height - squareSize) / 2 - 40 // Offset up a bit for buttons
        squareFrame = CGRect(x: 16, y: squareY, width: squareSize, height: squareSize) // Store for cropping
        
        // Create darkened overlay with cutout
        let overlayPath = UIBezierPath(rect: bounds)
        let cutoutPath = UIBezierPath(roundedRect: squareFrame, cornerRadius: 12)
        overlayPath.append(cutoutPath.reversing())
        
        let overlayLayer = CAShapeLayer()
        overlayLayer.path = overlayPath.cgPath
        overlayLayer.fillColor = UIColor.black.withAlphaComponent(0.6).cgColor
        squareOverlayView.layer.addSublayer(overlayLayer)
        
        // Add border to square
        let borderView = UIView(frame: squareFrame)
        borderView.layer.borderColor = UIColor.white.cgColor
        borderView.layer.borderWidth = 2
        borderView.layer.cornerRadius = 12
        borderView.backgroundColor = .clear
        borderView.isUserInteractionEnabled = false
        squareOverlayView.addSubview(borderView)
        
        // Add corner guides
        addCornerGuides(to: squareFrame)
    }
    
    private func addCornerGuides(to frame: CGRect) {
        let guideLength: CGFloat = 24
        let guideWidth: CGFloat = 3
        let cornerRadius: CGFloat = 12
        let corners: [(CGPoint, [CGPoint])] = [
            // Top-left
            (CGPoint(x: frame.minX, y: frame.minY + cornerRadius), [
                CGPoint(x: frame.minX, y: frame.minY + guideLength),
                CGPoint(x: frame.minX + guideLength, y: frame.minY)
            ]),
            // Top-right
            (CGPoint(x: frame.maxX, y: frame.minY + cornerRadius), [
                CGPoint(x: frame.maxX, y: frame.minY + guideLength),
                CGPoint(x: frame.maxX - guideLength, y: frame.minY)
            ]),
            // Bottom-left
            (CGPoint(x: frame.minX, y: frame.maxY - cornerRadius), [
                CGPoint(x: frame.minX, y: frame.maxY - guideLength),
                CGPoint(x: frame.minX + guideLength, y: frame.maxY)
            ]),
            // Bottom-right
            (CGPoint(x: frame.maxX, y: frame.maxY - cornerRadius), [
                CGPoint(x: frame.maxX, y: frame.maxY - guideLength),
                CGPoint(x: frame.maxX - guideLength, y: frame.maxY)
            ])
        ]
        
        for (_, endpoints) in corners {
            for endpoint in endpoints {
                let guide = UIView()
                guide.backgroundColor = .white
                
                if endpoint.y == frame.minY || endpoint.y == frame.maxY {
                    // Horizontal guide
                    let x = endpoint.x < frame.midX ? frame.minX : frame.maxX - guideLength
                    let y = endpoint.y == frame.minY ? frame.minY - guideWidth/2 : frame.maxY - guideWidth/2
                    guide.frame = CGRect(x: x, y: y, width: guideLength, height: guideWidth)
                } else {
                    // Vertical guide
                    let x = endpoint.x == frame.minX ? frame.minX - guideWidth/2 : frame.maxX - guideWidth/2
                    let y = endpoint.y < frame.midY ? frame.minY : frame.maxY - guideLength
                    guide.frame = CGRect(x: x, y: y, width: guideWidth, height: guideLength)
                }
                
                squareOverlayView.addSubview(guide)
            }
        }
    }
    
    private func setupCaptureButton() {
        captureButton = UIButton(type: .custom)
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(captureButton)
        
        // Outer ring
        let outerRing = UIView()
        outerRing.backgroundColor = .clear
        outerRing.layer.borderColor = UIColor.white.cgColor
        outerRing.layer.borderWidth = 4
        outerRing.layer.cornerRadius = 37
        outerRing.isUserInteractionEnabled = false
        outerRing.translatesAutoresizingMaskIntoConstraints = false
        captureButton.addSubview(outerRing)
        
        // Inner circle
        let innerCircle = UIView()
        innerCircle.backgroundColor = .white
        innerCircle.layer.cornerRadius = 30
        innerCircle.isUserInteractionEnabled = false
        innerCircle.translatesAutoresizingMaskIntoConstraints = false
        captureButton.addSubview(innerCircle)
        
        NSLayoutConstraint.activate([
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            captureButton.widthAnchor.constraint(equalToConstant: 74),
            captureButton.heightAnchor.constraint(equalToConstant: 74),
            
            outerRing.centerXAnchor.constraint(equalTo: captureButton.centerXAnchor),
            outerRing.centerYAnchor.constraint(equalTo: captureButton.centerYAnchor),
            outerRing.widthAnchor.constraint(equalToConstant: 74),
            outerRing.heightAnchor.constraint(equalToConstant: 74),
            
            innerCircle.centerXAnchor.constraint(equalTo: captureButton.centerXAnchor),
            innerCircle.centerYAnchor.constraint(equalTo: captureButton.centerYAnchor),
            innerCircle.widthAnchor.constraint(equalToConstant: 60),
            innerCircle.heightAnchor.constraint(equalToConstant: 60)
        ])
        
        captureButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
    }
    
    private func setupZoomLabel() {
        zoomLabel = UILabel()
        zoomLabel.text = "1.0×"
        zoomLabel.textColor = .white
        zoomLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        zoomLabel.textAlignment = .center
        zoomLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        zoomLabel.layer.cornerRadius = 12
        zoomLabel.clipsToBounds = true
        zoomLabel.alpha = 0
        zoomLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(zoomLabel)
        
        NSLayoutConstraint.activate([
            zoomLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            zoomLabel.bottomAnchor.constraint(equalTo: captureButton.topAnchor, constant: -20),
            zoomLabel.widthAnchor.constraint(equalToConstant: 60),
            zoomLabel.heightAnchor.constraint(equalToConstant: 28)
        ])
    }
    
    private func setupGestures() {
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        view.addGestureRecognizer(pinchGesture)
    }
    
    // MARK: - Session Control
    
    private func startSession() {
        guard let session = captureSession, !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }
    
    private func stopSession() {
        guard let session = captureSession, session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            session.stopRunning()
        }
    }
    
    // MARK: - Gestures
    
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let device = videoDeviceInput?.device else { return }
        
        switch gesture.state {
        case .began:
            // Show zoom label
            UIView.animate(withDuration: 0.2) {
                self.zoomLabel.alpha = 1
            }
            
        case .changed:
            let scaleFactor = gesture.scale
            let newZoomFactor = currentZoomFactor * scaleFactor
            let clampedZoom = max(minZoomFactor, min(newZoomFactor, maxZoomFactor))
            
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clampedZoom
                device.unlockForConfiguration()
                
                // Update zoom label
                zoomLabel.text = String(format: "%.1f×", clampedZoom)
            } catch {
                print("Error setting zoom: \(error)")
            }
            
            gesture.scale = 1.0
            currentZoomFactor = clampedZoom
            
        case .ended, .cancelled:
            // Hide zoom label after delay
            UIView.animate(withDuration: 0.3, delay: 0.5) {
                self.zoomLabel.alpha = 0
            }
            
        default:
            break
        }
    }
    
    // MARK: - Actions
    
    @objc private func capturePhoto() {
        guard let photoOutput = photoOutput else { return }
        
        // Animate button press
        UIView.animate(withDuration: 0.1, animations: {
            self.captureButton.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.captureButton.transform = .identity
            }
        }
        
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    // MARK: - Layout
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Only update if bounds actually changed (avoid crashes during gestures)
        guard view.bounds != lastLayoutBounds else { return }
        lastLayoutBounds = view.bounds
        
        previewLayer?.frame = view.bounds
        
        if squareOverlayView != nil {
            squareOverlayView.frame = view.bounds
            updateSquareOverlay()
        }
    }
}

// MARK: - Photo Capture Delegate

extension CameraViewControllerNew: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            return
        }
        
        let fixedImage = image.normalizedForCropping()
        let croppedImage = cropToSquarePreview(fixedImage)
        delegate?.didCaptureImage(croppedImage)
    }
    
    private func cropToSquarePreview(_ image: UIImage) -> UIImage {
        guard let previewLayer = previewLayer,
              previewLayer.bounds.width > 0,
              previewLayer.bounds.height > 0 else { return image }
        
        let imageSize = image.size
        let previewBounds = previewLayer.bounds
        
        let previewAspect = previewBounds.width / previewBounds.height
        let imageAspect = imageSize.width / imageSize.height
        
        let visibleImageRect: CGRect
        if imageAspect > previewAspect {
            let visibleWidth = imageSize.height * previewAspect
            let offsetX = (imageSize.width - visibleWidth) / 2
            visibleImageRect = CGRect(x: offsetX, y: 0, width: visibleWidth, height: imageSize.height)
        } else {
            let visibleHeight = imageSize.width / previewAspect
            let offsetY = (imageSize.height - visibleHeight) / 2
            visibleImageRect = CGRect(x: 0, y: offsetY, width: imageSize.width, height: visibleHeight)
        }
        
        let scaleX = visibleImageRect.width / previewBounds.width
        let scaleY = visibleImageRect.height / previewBounds.height
        
        var cropRect = CGRect(
            x: visibleImageRect.origin.x + (squareFrame.origin.x * scaleX),
            y: visibleImageRect.origin.y + (squareFrame.origin.y * scaleY),
            width: squareFrame.width * scaleX,
            height: squareFrame.height * scaleY
        )
        
        cropRect.origin.x = max(0, min(cropRect.origin.x, imageSize.width - cropRect.width))
        cropRect.origin.y = max(0, min(cropRect.origin.y, imageSize.height - cropRect.height))
        cropRect.size.width = min(cropRect.width, imageSize.width - cropRect.origin.x)
        cropRect.size.height = min(cropRect.height, imageSize.height - cropRect.origin.y)
        
        let pixelRect = CGRect(
            x: cropRect.origin.x * image.scale,
            y: cropRect.origin.y * image.scale,
            width: cropRect.size.width * image.scale,
            height: cropRect.size.height * image.scale
        )
        
        guard pixelRect.width > 0, pixelRect.height > 0,
              let cgImage = image.cgImage,
              let croppedCGImage = cgImage.cropping(to: pixelRect) else {
            return image
        }
        
        return UIImage(cgImage: croppedCGImage, scale: 1.0, orientation: .up)
    }
}

