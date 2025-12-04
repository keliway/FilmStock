//
//  ImageCropperView.swift
//  FilmStock
//
//  Square image cropper using UIKit for reliable layout
//

import SwiftUI
import UIKit

// MARK: - SwiftUI Wrapper

struct ImageCropperView: View {
    let image: UIImage
    var onComplete: (UIImage) -> Void
    var onCancel: () -> Void
    
    var body: some View {
        ImageCropperRepresentable(
            image: image,
            onComplete: onComplete,
            onCancel: onCancel
        )
        .ignoresSafeArea()
    }
}

// MARK: - UIKit Representable

struct ImageCropperRepresentable: UIViewControllerRepresentable {
    let image: UIImage
    var onComplete: (UIImage) -> Void
    var onCancel: () -> Void
    
    func makeUIViewController(context: Context) -> CropViewController {
        let controller = CropViewController(image: image)
        controller.onComplete = onComplete
        controller.onCancel = onCancel
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CropViewController, context: Context) {}
}

// MARK: - Crop View Controller

class CropViewController: UIViewController {
    var onComplete: ((UIImage) -> Void)?
    var onCancel: (() -> Void)?
    
    private let sourceImage: UIImage
    private var scrollView: UIScrollView!
    private var imageView: UIImageView!
    private var cropFrame: CGRect = .zero
    private var originalContentSize: CGSize = .zero
    
    init(image: UIImage) {
        self.sourceImage = image
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        // Setup immediately in viewDidLoad
        DispatchQueue.main.async {
            self.setupUI()
        }
    }
    
    override var prefersStatusBarHidden: Bool { true }
    
    // MARK: - Setup
    
    private func setupUI() {
        let safeTop = view.safeAreaInsets.top
        let safeBottom = view.safeAreaInsets.bottom
        
        // Calculate crop frame - square, centered, with space for controls
        let navBarHeight: CGFloat = 70
        let bottomBarHeight: CGFloat = 100
        let padding: CGFloat = 16
        
        let availableWidth = view.bounds.width - (padding * 2)
        let availableHeight = view.bounds.height - safeTop - navBarHeight - bottomBarHeight - safeBottom
        let cropSize = min(availableWidth, availableHeight - 20)
        
        let cropX = (view.bounds.width - cropSize) / 2
        let cropY = safeTop + navBarHeight + (availableHeight - cropSize) / 2
        cropFrame = CGRect(x: cropX, y: cropY, width: cropSize, height: cropSize)
        
        setupScrollView()
        setupOverlay()
        setupNavBar(safeTop: safeTop)
        setupBottomHint(safeBottom: safeBottom)
    }
    
    private func setupScrollView() {
        guard cropFrame.width > 0 && cropFrame.height > 0 else { return }
        guard sourceImage.size.width > 0 && sourceImage.size.height > 0 else { return }
        
        scrollView = UIScrollView(frame: cropFrame)
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 5.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.clipsToBounds = true
        scrollView.layer.cornerRadius = 12
        scrollView.bounces = true
        scrollView.bouncesZoom = true
        scrollView.backgroundColor = .darkGray
        view.addSubview(scrollView)
        
        // Setup image view
        imageView = UIImageView(image: sourceImage)
        imageView.contentMode = .scaleAspectFill
        
        // Calculate size to fill the crop area
        let imageAspect = sourceImage.size.width / sourceImage.size.height
        let cropAspect = cropFrame.width / cropFrame.height
        
        var imageSize: CGSize
        if imageAspect > cropAspect {
            // Image is wider - fit height
            imageSize = CGSize(width: cropFrame.height * imageAspect, height: cropFrame.height)
        } else {
            // Image is taller - fit width
            imageSize = CGSize(width: cropFrame.width, height: cropFrame.width / imageAspect)
        }
        
        imageView.frame = CGRect(origin: .zero, size: imageSize)
        scrollView.addSubview(imageView)
        scrollView.contentSize = imageSize
        originalContentSize = imageSize
        
        // Center the image initially
        let offsetX = max(0, (imageSize.width - cropFrame.width) / 2)
        let offsetY = max(0, (imageSize.height - cropFrame.height) / 2)
        scrollView.contentOffset = CGPoint(x: offsetX, y: offsetY)
    }
    
    private func setupOverlay() {
        let overlay = UIView(frame: view.bounds)
        overlay.backgroundColor = .clear
        overlay.isUserInteractionEnabled = false
        view.addSubview(overlay)
        
        // Dark mask with cutout
        let maskLayer = CAShapeLayer()
        let path = UIBezierPath(rect: view.bounds)
        let cutout = UIBezierPath(roundedRect: cropFrame, cornerRadius: 12)
        path.append(cutout.reversing())
        maskLayer.path = path.cgPath
        maskLayer.fillColor = UIColor.black.withAlphaComponent(0.65).cgColor
        overlay.layer.addSublayer(maskLayer)
        
        // White border
        let border = CAShapeLayer()
        border.path = UIBezierPath(roundedRect: cropFrame, cornerRadius: 12).cgPath
        border.strokeColor = UIColor.white.cgColor
        border.fillColor = UIColor.clear.cgColor
        border.lineWidth = 2
        overlay.layer.addSublayer(border)
        
        // Grid lines
        let gridColor = UIColor.white.withAlphaComponent(0.3).cgColor
        for i in 1..<3 {
            let vLine = CALayer()
            vLine.backgroundColor = gridColor
            vLine.frame = CGRect(x: cropFrame.minX + cropFrame.width * CGFloat(i) / 3, y: cropFrame.minY, width: 0.5, height: cropFrame.height)
            overlay.layer.addSublayer(vLine)
            
            let hLine = CALayer()
            hLine.backgroundColor = gridColor
            hLine.frame = CGRect(x: cropFrame.minX, y: cropFrame.minY + cropFrame.height * CGFloat(i) / 3, width: cropFrame.width, height: 0.5)
            overlay.layer.addSublayer(hLine)
        }
    }
    
    private func setupNavBar(safeTop: CGFloat) {
        // Container view for nav bar
        let navBar = UIView()
        navBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navBar)
        
        // Cancel button
        let cancelBtn = UIButton(type: .system)
        cancelBtn.setTitle(NSLocalizedString("action.cancel", comment: ""), for: .normal)
        cancelBtn.setTitleColor(.white, for: .normal)
        cancelBtn.titleLabel?.font = .systemFont(ofSize: 17)
        cancelBtn.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false
        navBar.addSubview(cancelBtn)
        
        // Title
        let titleLabel = UILabel()
        titleLabel.text = NSLocalizedString("cropper.title", comment: "")
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        navBar.addSubview(titleLabel)
        
        // Done button
        let doneBtn = UIButton(type: .system)
        doneBtn.setTitle(NSLocalizedString("action.done", comment: ""), for: .normal)
        doneBtn.setTitleColor(.systemYellow, for: .normal)
        doneBtn.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        doneBtn.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        doneBtn.translatesAutoresizingMaskIntoConstraints = false
        navBar.addSubview(doneBtn)
        
        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.topAnchor, constant: safeTop + 10),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navBar.heightAnchor.constraint(equalToConstant: 50),
            
            cancelBtn.leadingAnchor.constraint(equalTo: navBar.leadingAnchor, constant: 16),
            cancelBtn.centerYAnchor.constraint(equalTo: navBar.centerYAnchor),
            
            titleLabel.centerXAnchor.constraint(equalTo: navBar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: navBar.centerYAnchor),
            
            doneBtn.trailingAnchor.constraint(equalTo: navBar.trailingAnchor, constant: -16),
            doneBtn.centerYAnchor.constraint(equalTo: navBar.centerYAnchor)
        ])
    }
    
    private func setupBottomHint(safeBottom: CGFloat) {
        let hintLabel = UILabel()
        hintLabel.text = NSLocalizedString("cropper.hint", comment: "")
        hintLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        hintLabel.font = .systemFont(ofSize: 14)
        hintLabel.textAlignment = .center
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hintLabel)
        
        NSLayoutConstraint.activate([
            hintLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hintLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -safeBottom - 40)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func cancelTapped() {
        onCancel?()
    }
    
    @objc private func doneTapped() {
        let croppedImage = cropImage()
        onComplete?(croppedImage)
    }
    
    // MARK: - Cropping
    
    private func cropImage() -> UIImage {
        let baseWidth = originalContentSize.width
        let baseHeight = originalContentSize.height
        
        guard baseWidth > 0 && baseHeight > 0 else { return sourceImage }
        
        let scale = sourceImage.size.width / baseWidth
        let zoomScale = scrollView.zoomScale
        
        let offsetX = scrollView.contentOffset.x
        let offsetY = scrollView.contentOffset.y
        let viewWidth = scrollView.bounds.width
        let viewHeight = scrollView.bounds.height
        
        let origX = offsetX / zoomScale
        let origY = offsetY / zoomScale
        let origWidth = viewWidth / zoomScale
        let origHeight = viewHeight / zoomScale
        
        var cropRect = CGRect(
            x: origX * scale,
            y: origY * scale,
            width: origWidth * scale,
            height: origHeight * scale
        )
        
        let imageSize = sourceImage.size
        cropRect.origin.x = max(0, min(cropRect.origin.x, imageSize.width - cropRect.width))
        cropRect.origin.y = max(0, min(cropRect.origin.y, imageSize.height - cropRect.height))
        cropRect.size.width = max(1, min(cropRect.width, imageSize.width - cropRect.origin.x))
        cropRect.size.height = max(1, min(cropRect.height, imageSize.height - cropRect.origin.y))
        
        guard let cgImage = sourceImage.cgImage,
              let croppedCGImage = cgImage.cropping(to: cropRect) else {
            return sourceImage
        }
        
        let outputSize: CGFloat = 1000
        UIGraphicsBeginImageContextWithOptions(CGSize(width: outputSize, height: outputSize), false, 1.0)
        UIImage(cgImage: croppedCGImage).draw(in: CGRect(x: 0, y: 0, width: outputSize, height: outputSize))
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return result ?? sourceImage
    }
}

// MARK: - UIScrollViewDelegate

extension CropViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) / 2, 0)
        let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) / 2, 0)
        imageView.center = CGPoint(
            x: scrollView.contentSize.width / 2 + offsetX,
            y: scrollView.contentSize.height / 2 + offsetY
        )
    }
}
