import UIKit

class BarWaveformView: UIView {

    private let waveformLayer = CAShapeLayer()

    @IBInspectable var barWidth: CGFloat = 1.9 { didSet { updateLayerProperties() } }
    @IBInspectable var barSpacing: CGFloat = 3.0
    @IBInspectable var waveformColor: UIColor = UIColor(named: "ButtonTheme") ?? .systemRed {
        didSet {
            updateLayerProperties()
        }
    }

    var amplitudes: [CGFloat] = [] {
        didSet {
            updateWaveformPath()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }

    private func setupLayer() {
        layer.addSublayer(waveformLayer)
        waveformLayer.lineCap = .round
        waveformLayer.fillColor = UIColor.clear.cgColor // CRITICAL for CAShapeLayer
        updateLayerProperties()
    }

    private func updateLayerProperties() {
        waveformLayer.strokeColor = waveformColor.cgColor
        waveformLayer.lineWidth = barWidth
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // CRITICAL: The hardware layer must match the UIView's bounds
        waveformLayer.frame = bounds
        updateWaveformPath()
    }

    private func updateWaveformPath() {
        // Safety check: Prevent drawing if Auto Layout hasn't given the view a size yet
        guard bounds.width > 0 && bounds.height > 0 else { return }

        let path = UIBezierPath()
        let centerY = bounds.height / 2.0
        let maxBarHeight = bounds.height / 2.5
        let centerX = bounds.width
        let stepDistance = barWidth + barSpacing

        for (index, amplitude) in amplitudes.reversed().enumerated() {
            let xPosition = centerX - (CGFloat(index) * stepDistance)
            guard xPosition >= -barWidth else { break }

            let safeAmplitude = max(0.0, min(amplitude, 1.0))
            let dynamicHeight = safeAmplitude * maxBarHeight

            path.move(to: CGPoint(x: xPosition, y: centerY - dynamicHeight))
            path.addLine(to: CGPoint(x: xPosition, y: centerY + dynamicHeight))
        }

        // High-performance direct hardware update
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        waveformLayer.path = path.cgPath
        CATransaction.commit()
    }
}
