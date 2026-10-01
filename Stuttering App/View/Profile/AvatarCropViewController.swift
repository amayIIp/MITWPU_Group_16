//
//  AvatarCropViewController.swift
//  Spasht
//
//  The "Move and Scale" step between picking a photo and saving it.
//
//  The first version centre-cropped silently, which is wrong more often than it
//  is right — a face is rarely in the exact middle of a photo, and there was no
//  way to say otherwise. This hands the framing back to the user.
//

import UIKit

final class AvatarCropViewController: UIViewController {

    private let image: UIImage
    private let onComplete: (UIImage) -> Void

    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private let overlay = CropOverlayView()

    /// Matches what `AvatarStore` keeps, so its own resize is a no-op.
    private let outputSize: CGFloat = 512
    private let cropInset: CGFloat = 24

    private var cropSquare: CGRect = .zero
    private var hasPositioned = false

    init(image: UIImage, onComplete: @escaping (UIImage) -> Void) {
        self.image = image
        self.onComplete = onComplete
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("AvatarCropViewController is created in code, not from a storyboard.")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black
        title = "Move and Scale"
        configureNavigationBar()

        scrollView.delegate = self
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bouncesZoom = true
        // The crop square is positioned by hand; letting UIKit inset for the
        // safe area on top of that would shift it out from under the circle.
        scrollView.contentInsetAdjustmentBehavior = .never
        view.addSubview(scrollView)

        imageView.image = image
        imageView.contentMode = .scaleToFill
        scrollView.addSubview(imageView)

        overlay.isUserInteractionEnabled = false
        view.addSubview(overlay)
    }

    private func configureNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .black
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
        navigationItem.compactAppearance = appearance

        let cancel = UIBarButtonItem(title: "Cancel", style: .plain,
                                     target: self, action: #selector(cancelTapped))
        let choose = UIBarButtonItem(title: "Choose", style: .prominent,
                                     target: self, action: #selector(chooseTapped))
        cancel.tintColor = .white
        choose.tintColor = .white

        navigationItem.leftBarButtonItem = cancel
        navigationItem.rightBarButtonItem = choose
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        scrollView.frame = view.bounds
        overlay.frame = view.bounds

        let side = min(view.bounds.width, view.bounds.height) - cropInset * 2
        guard side > 0 else { return }

        cropSquare = CGRect(x: (view.bounds.width - side) / 2,
                            y: (view.bounds.height - side) / 2,
                            width: side, height: side)
        overlay.cropCircle = cropSquare

        // Insetting by the margin around the crop square is what lets the edges
        // of the photo be dragged all the way into the circle.
        scrollView.contentInset = UIEdgeInsets(top: cropSquare.minY,
                                               left: cropSquare.minX,
                                               bottom: view.bounds.height - cropSquare.maxY,
                                               right: view.bounds.width - cropSquare.maxX)

        guard !hasPositioned, image.size.width > 0, image.size.height > 0 else { return }
        hasPositioned = true

        imageView.frame = CGRect(origin: .zero, size: image.size)
        scrollView.contentSize = image.size

        // The smallest zoom that still covers the circle — the user can never
        // scroll a gap into the crop.
        let minimum = max(side / image.size.width, side / image.size.height)
        scrollView.minimumZoomScale = minimum
        scrollView.maximumZoomScale = minimum * 5
        scrollView.zoomScale = minimum

        // Start centred, which is the old behaviour as a starting point.
        scrollView.contentOffset = CGPoint(
            x: (scrollView.contentSize.width - side) / 2 - cropSquare.minX,
            y: (scrollView.contentSize.height - side) / 2 - cropSquare.minY)
    }

    // MARK: - Actions

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func chooseTapped() {
        dismiss(animated: true) { [onComplete, cropped = croppedImage()] in
            onComplete(cropped)
        }
    }

    /// Renders whatever the circle is currently over, at `outputSize`.
    ///
    /// Drawing the whole image into a clipped canvas rather than cropping the
    /// CGImage keeps `UIImage`'s orientation flag applied — a photo straight
    /// from the camera would otherwise come out rotated.
    private func croppedImage() -> UIImage {
        let zoom = scrollView.zoomScale
        guard zoom > 0 else { return image }

        // The crop square, expressed in the image's own coordinates.
        let originX = (scrollView.contentOffset.x + cropSquare.minX) / zoom
        let originY = (scrollView.contentOffset.y + cropSquare.minY) / zoom
        let side = cropSquare.width / zoom
        guard side > 0 else { return image }

        let scale = outputSize / side
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: CGSize(width: outputSize, height: outputSize),
                                       format: format).image { _ in
            image.draw(in: CGRect(x: -originX * scale,
                                  y: -originY * scale,
                                  width: image.size.width * scale,
                                  height: image.size.height * scale))
        }
    }
}

// MARK: - Zooming

extension AvatarCropViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
}

// MARK: - Overlay

/// Dims everything outside the crop circle and outlines it.
private final class CropOverlayView: UIView {

    var cropCircle: CGRect = .zero {
        didSet {
            guard cropCircle != oldValue else { return }
            setNeedsDisplay()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        contentMode = .redraw
    }

    required init?(coder: NSCoder) {
        fatalError("CropOverlayView is created in code.")
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(), !cropCircle.isEmpty else { return }

        context.setFillColor(UIColor.black.withAlphaComponent(0.6).cgColor)
        context.fill(rect)

        // Punch the circle out of the dimming rather than compositing two
        // shapes, so the edge stays crisp at any scale.
        context.setBlendMode(.clear)
        context.fillEllipse(in: cropCircle)

        context.setBlendMode(.normal)
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.9).cgColor)
        context.setLineWidth(1)
        context.strokeEllipse(in: cropCircle.insetBy(dx: 0.5, dy: 0.5))
    }
}
