//
//  ImageCropperView.swift
//  FilmStock
//
//  Square image cropper using UIKit for reliable layout
//

import SwiftUI
import UIKit

extension UIImage {
    /// Normalizes image orientation to `.up` with `scale = 1.0` and caps the longest side at `maxDimension`
    /// so cropping large camera / 48 MP library photos never spikes hundreds of MB of uncompressed RAM.
    func normalizedForCropping(maxDimension: CGFloat = 2400) -> UIImage {
        let pixelWidth = size.width * scale
        let pixelHeight = size.height * scale
        guard pixelWidth > 0, pixelHeight > 0 else { return self }

        let longestSide = max(pixelWidth, pixelHeight)
        if imageOrientation == .up && scale == 1.0 && longestSide <= maxDimension {
            return self
        }

        let downsampleRatio = min(1.0, maxDimension / longestSide)
        let targetSize = CGSize(
            width: round(pixelWidth * downsampleRatio),
            height: round(pixelHeight * downsampleRatio)
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

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

    func updateUIViewController(_ uiViewController: CropViewController, context: Context) {
        uiViewController.onComplete = onComplete
        uiViewController.onCancel = onCancel
    }
}

// MARK: - Crop View Controller

final class CropViewController: UIViewController {
    var onComplete: ((UIImage) -> Void)?
    var onCancel: (() -> Void)?

    private let sourceImage: UIImage
    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private let overlayView = UIView()
    private var cropFrame: CGRect = .zero
    private var originalContentSize: CGSize = .zero
    private var lastLayoutBounds: CGRect = .zero
    private var lastSafeAreaInsets: UIEdgeInsets = .zero

    init(image: UIImage) {
        self.sourceImage = image.normalizedForCropping()
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupStaticHierarchy()
    }

    override var prefersStatusBarHidden: Bool { true }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard view.bounds.width > 0, view.bounds.height > 0 else { return }
        guard view.bounds != lastLayoutBounds || view.safeAreaInsets != lastSafeAreaInsets else { return }
        lastLayoutBounds = view.bounds
        lastSafeAreaInsets = view.safeAreaInsets
        layoutCropArea()
    }

    // MARK: - Setup

    private func setupStaticHierarchy() {
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

        imageView.image = sourceImage
        imageView.contentMode = .scaleAspectFill
        scrollView.addSubview(imageView)

        overlayView.backgroundColor = .clear
        overlayView.isUserInteractionEnabled = false
        view.addSubview(overlayView)

        // Navigation bar anchored to safeAreaLayoutGuide
        let navBar = UIView()
        navBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navBar)

        let cancelBtn = UIButton(type: .system)
        cancelBtn.setTitle(NSLocalizedString("action.cancel", comment: ""), for: .normal)
        cancelBtn.setTitleColor(.white, for: .normal)
        cancelBtn.titleLabel?.font = .systemFont(ofSize: 17)
        cancelBtn.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false
        navBar.addSubview(cancelBtn)

        let titleLabel = UILabel()
        titleLabel.text = NSLocalizedString("cropper.title", comment: "")
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        navBar.addSubview(titleLabel)

        let doneBtn = UIButton(type: .system)
        doneBtn.setTitle(NSLocalizedString("action.done", comment: ""), for: .normal)
        doneBtn.setTitleColor(.systemYellow, for: .normal)
        doneBtn.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        doneBtn.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        doneBtn.translatesAutoresizingMaskIntoConstraints = false
        navBar.addSubview(doneBtn)

        let hintLabel = UILabel()
        hintLabel.text = NSLocalizedString("cropper.hint", comment: "")
        hintLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        hintLabel.font = .systemFont(ofSize: 14)
        hintLabel.textAlignment = .center
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hintLabel)

        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navBar.heightAnchor.constraint(equalToConstant: 50),

            cancelBtn.leadingAnchor.constraint(equalTo: navBar.leadingAnchor, constant: 16),
            cancelBtn.centerYAnchor.constraint(equalTo: navBar.centerYAnchor),

            titleLabel.centerXAnchor.constraint(equalTo: navBar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: navBar.centerYAnchor),

            doneBtn.trailingAnchor.constraint(equalTo: navBar.trailingAnchor, constant: -16),
            doneBtn.centerYAnchor.constraint(equalTo: navBar.centerYAnchor),

            hintLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hintLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24)
        ])
    }

    private func layoutCropArea() {
        guard sourceImage.size.width > 0, sourceImage.size.height > 0 else { return }

        let safeTop = view.safeAreaInsets.top
        let safeBottom = view.safeAreaInsets.bottom
        let navBarHeight: CGFloat = 66
        let bottomBarHeight: CGFloat = 80
        let padding: CGFloat = 16

        let availableWidth = view.bounds.width - (padding * 2)
        let availableHeight = view.bounds.height - safeTop - navBarHeight - bottomBarHeight - safeBottom
        let cropSize = max(1, min(availableWidth, availableHeight - 16))

        let cropX = (view.bounds.width - cropSize) / 2
        let cropY = safeTop + navBarHeight + (availableHeight - cropSize) / 2
        cropFrame = CGRect(x: cropX, y: cropY, width: cropSize, height: cropSize)

        scrollView.zoomScale = 1.0
        scrollView.frame = cropFrame

        let imageAspect = sourceImage.size.width / sourceImage.size.height
        let imageSize: CGSize
        if imageAspect > 1.0 {
            imageSize = CGSize(width: cropFrame.height * imageAspect, height: cropFrame.height)
        } else {
            imageSize = CGSize(width: cropFrame.width, height: cropFrame.width / imageAspect)
        }

        imageView.transform = .identity
        imageView.frame = CGRect(origin: .zero, size: imageSize)
        scrollView.contentSize = imageSize
        originalContentSize = imageSize

        let offsetX = max(0, (imageSize.width - cropFrame.width) / 2)
        let offsetY = max(0, (imageSize.height - cropFrame.height) / 2)
        scrollView.contentOffset = CGPoint(x: offsetX, y: offsetY)

        rebuildOverlay()
    }

    private func rebuildOverlay() {
        overlayView.frame = view.bounds
        overlayView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }

        let maskLayer = CAShapeLayer()
        let path = UIBezierPath(rect: view.bounds)
        let cutout = UIBezierPath(roundedRect: cropFrame, cornerRadius: 12)
        path.append(cutout.reversing())
        maskLayer.path = path.cgPath
        maskLayer.fillColor = UIColor.black.withAlphaComponent(0.65).cgColor
        overlayView.layer.addSublayer(maskLayer)

        let border = CAShapeLayer()
        border.path = UIBezierPath(roundedRect: cropFrame, cornerRadius: 12).cgPath
        border.strokeColor = UIColor.white.cgColor
        border.fillColor = UIColor.clear.cgColor
        border.lineWidth = 2
        overlayView.layer.addSublayer(border)

        let gridColor = UIColor.white.withAlphaComponent(0.3).cgColor
        for i in 1..<3 {
            let vLine = CALayer()
            vLine.backgroundColor = gridColor
            vLine.frame = CGRect(x: cropFrame.minX + cropFrame.width * CGFloat(i) / 3, y: cropFrame.minY, width: 0.5, height: cropFrame.height)
            overlayView.layer.addSublayer(vLine)

            let hLine = CALayer()
            hLine.backgroundColor = gridColor
            hLine.frame = CGRect(x: cropFrame.minX, y: cropFrame.minY + cropFrame.height * CGFloat(i) / 3, width: cropFrame.width, height: 0.5)
            overlayView.layer.addSublayer(hLine)
        }
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
        guard baseWidth > 0, baseHeight > 0 else { return sourceImage }

        let scale = sourceImage.size.width / baseWidth
        let zoomScale = scrollView.zoomScale

        let origX = scrollView.contentOffset.x / zoomScale
        let origY = scrollView.contentOffset.y / zoomScale
        let origWidth = scrollView.bounds.width / zoomScale
        let origHeight = scrollView.bounds.height / zoomScale

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

        let outputSize: CGFloat = 1000
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: outputSize, height: outputSize), format: format)
        return renderer.image { _ in
            let drawScaleX = outputSize / cropRect.width
            let drawScaleY = outputSize / cropRect.height
            let drawRect = CGRect(
                x: -cropRect.origin.x * drawScaleX,
                y: -cropRect.origin.y * drawScaleY,
                width: imageSize.width * drawScaleX,
                height: imageSize.height * drawScaleY
            )
            sourceImage.draw(in: drawRect)
        }
    }
}

// MARK: - UIScrollViewDelegate

extension CropViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
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
