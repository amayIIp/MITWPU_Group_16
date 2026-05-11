import UIKit

// MARK: - WaveLoadingOverlay
//
// A reusable full-screen loading overlay that uses the same wave animation
// as ExerciseResultViewController. Show it with a context-appropriate message,
// then dismiss it when the async work is done.
//
// Usage (on a view):
//   let overlay = WaveLoadingOverlay.show(in: view, message: "Signing you in…")
//   // ... do async work ...
//   overlay.dismiss()
//
// Usage (on the window — blocks the full screen):
//   let overlay = WaveLoadingOverlay.showOnWindow(message: "Analysing your speech…")
//   overlay.dismiss()

class WaveLoadingOverlay: UIView {

    // MARK: - Subviews
    private let waveView    = WaveBackgroundView()
    private let messageLabel = UILabel()
    private let dotLabel     = UILabel()   // animated ellipsis

    // MARK: - Internal state
    private var dotTimer: Timer?
    private var dotCount = 0

    // MARK: - Factory helpers

    /// Show a wave overlay covering `targetView`.
    @discardableResult
    static func show(in targetView: UIView, message: String) -> WaveLoadingOverlay {
        let overlay = WaveLoadingOverlay(message: message)
        overlay.frame = targetView.bounds
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        targetView.addSubview(overlay)
        overlay.animateIn()
        return overlay
    }

    /// Show a wave overlay covering the entire window (useful when the VC is behind a modal).
    @discardableResult
    static func showOnWindow(message: String) -> WaveLoadingOverlay {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first(where: { $0.isKeyWindow }) else {
            // Fallback — should never happen
            return WaveLoadingOverlay(message: message)
        }
        return show(in: window, message: message)
    }

    // MARK: - Init

    init(message: String) {
        super.init(frame: .zero)
        messageLabel.text = message
        setupLayout()
    }

    required init?(coder: NSCoder) { fatalError("Use init(message:)") }

    // MARK: - Layout

    private func setupLayout() {
        backgroundColor = UIColor(named: "bg") ?? .systemBackground

        let brandColor = UIColor(named: "ButtonTheme") ?? UIColor(red: 0.21, green: 0.32, blue: 0.63, alpha: 1.0)

        // Wave
        waveView.translatesAutoresizingMaskIntoConstraints = false
        waveView.themeColor = brandColor
        addSubview(waveView)
        NSLayoutConstraint.activate([
            waveView.leadingAnchor.constraint(equalTo: leadingAnchor),
            waveView.trailingAnchor.constraint(equalTo: trailingAnchor),
            waveView.topAnchor.constraint(equalTo: topAnchor),
            waveView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // Message label
        messageLabel.font = UIFont.systemFont(ofSize: 22, weight: .semibold)
        messageLabel.textColor = .label
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.alpha = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(messageLabel)

        // Animated dot label
        dotLabel.font = UIFont.systemFont(ofSize: 22, weight: .semibold)
        dotLabel.textColor = brandColor
        dotLabel.textAlignment = .left
        dotLabel.alpha = 0
        dotLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dotLabel)

        NSLayoutConstraint.activate([
            messageLabel.centerXAnchor.constraint(equalTo: centerXAnchor, constant: -10),
            messageLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -20),
            messageLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 32),
            messageLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -32),

            dotLabel.leadingAnchor.constraint(equalTo: messageLabel.trailingAnchor, constant: 2),
            dotLabel.centerYAnchor.constraint(equalTo: messageLabel.centerYAnchor)
        ])
    }

    // MARK: - Animation

    private func animateIn() {
        waveView.start()
        waveView.targetFillLevel = 0.28

        messageLabel.transform = CGAffineTransform(translationX: 0, y: 20)
        dotLabel.transform = CGAffineTransform(translationX: 0, y: 20)

        UIView.animate(withDuration: 0.55, delay: 0.1,
                       usingSpringWithDamping: 0.82,
                       initialSpringVelocity: 0,
                       options: .curveEaseOut) {
            self.messageLabel.alpha = 1
            self.messageLabel.transform = .identity
            self.dotLabel.alpha = 1
            self.dotLabel.transform = .identity
        }

        startDotAnimation()
    }

    private func startDotAnimation() {
        dotTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.dotCount = (self.dotCount + 1) % 4
            self.dotLabel.text = String(repeating: ".", count: self.dotCount)
        }
    }

    /// Dismiss and remove the overlay from its superview.
    func dismiss(animated: Bool = true, completion: (() -> Void)? = nil) {
        dotTimer?.invalidate()
        dotTimer = nil

        waveView.targetFillLevel = 0.0

        if animated {
            UIView.animate(withDuration: 0.35, animations: {
                self.alpha = 0
            }) { _ in
                self.waveView.stop()
                self.removeFromSuperview()
                completion?()
            }
        } else {
            waveView.stop()
            removeFromSuperview()
            completion?()
        }
    }

    deinit {
        dotTimer?.invalidate()
        waveView.stop()
    }
}
