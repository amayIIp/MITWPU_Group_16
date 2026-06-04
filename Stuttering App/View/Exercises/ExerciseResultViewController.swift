//
//  ExerciseResultViewController.swift
//  Spasht
//
//  Created by Prathamesh Patil on 15/11/25.
//

import UIKit

// MARK: - Wave Background View
class WaveBackgroundView: UIView {
    private var displayLink: CADisplayLink?
    private var phase: CGFloat = 0.0

    private let wave1 = CAShapeLayer()
    private let wave2 = CAShapeLayer()
    private let wave3 = CAShapeLayer()

    var themeColor: UIColor = .systemBlue {
        didSet {
            wave1.fillColor = themeColor.withAlphaComponent(0.3).cgColor
            wave2.fillColor = themeColor.withAlphaComponent(0.5).cgColor
            wave3.fillColor = themeColor.withAlphaComponent(0.8).cgColor
        }
    }

    var fillLevel: CGFloat = 0.0
    var targetFillLevel: CGFloat = 0.0

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        layer.addSublayer(wave1)
        layer.addSublayer(wave2)
        layer.addSublayer(wave3)
        backgroundColor = .clear
    }

    func start() {
        displayLink?.invalidate()
        displayLink = CADisplayLink(target: self, selector: #selector(updateWaves))
        displayLink?.add(to: .main, forMode: .common)
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    var isAnimating: Bool { displayLink != nil }

    @objc private func updateWaves() {
        phase += 0.05
        fillLevel += (targetFillLevel - fillLevel) * 0.04

        let width = bounds.width
        let height = bounds.height
        let currentWaterLevel = height * (1.0 - fillLevel)

        wave1.path = createWavePath(width: width, height: height, waterLevel: currentWaterLevel, amplitude: 12, frequency: 1.2, phaseOffset: phase)
        wave2.path = createWavePath(width: width, height: height, waterLevel: currentWaterLevel, amplitude: 18, frequency: 0.8, phaseOffset: phase + 2.0)
        wave3.path = createWavePath(width: width, height: height, waterLevel: currentWaterLevel, amplitude: 10, frequency: 1.5, phaseOffset: phase + 4.0)
    }

    private func createWavePath(width: CGFloat, height: CGFloat, waterLevel: CGFloat, amplitude: CGFloat, frequency: CGFloat, phaseOffset: CGFloat) -> CGPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: height))

        for x in stride(from: 0, through: width, by: 5) {
            let normalizedX = x / width
            let y = waterLevel + sin(normalizedX * frequency * .pi * 2 + phaseOffset) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: width, y: height))
        path.close()
        return path.cgPath
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        wave1.frame = bounds
        wave2.frame = bounds
        wave3.frame = bounds
    }
}

// MARK: - ExerciseResultViewController
class ExerciseResultViewController: UIViewController {

    var exerciseName: String = ""

    private let waveView = WaveBackgroundView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        performEntryAnimation()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        waveView.stop()
    }

    private func setupUI() {
        view.backgroundColor = UIColor(named: "bg") ?? .systemBackground
        let brandColor = UIColor(resource: .buttonTheme)

        // 1. Setup Waves
        waveView.frame = view.bounds
        waveView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        waveView.themeColor = brandColor
        view.addSubview(waveView)
        waveView.start()

        // 2. Setup Typography
        titleLabel.text = exerciseName.isEmpty ? "Session Complete" : exerciseName
        titleLabel.font = UIFont.systemFont(ofSize: 36, weight: .heavy)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.alpha = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        subtitleLabel.text = "Great Job!"
        subtitleLabel.font = UIFont.systemFont(ofSize: 22, weight: .medium)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.alpha = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitleLabel)

        // Layout - Centered title and subtitle
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    private func performEntryAnimation() {
        titleLabel.transform = CGAffineTransform(translationX: 0, y: 30)
        subtitleLabel.transform = CGAffineTransform(translationX: 0, y: 30)

        waveView.targetFillLevel = 0.35

        UIView.animate(
            withDuration: 0.8,
            delay: 0.5,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0,
            options: .curveEaseOut,
            animations: {
                self.titleLabel.alpha = 1.0
                self.titleLabel.transform = .identity

                self.subtitleLabel.alpha = 1.0
                self.subtitleLabel.transform = .identity
            },
            completion: { _ in
                // Stay for 2.5 seconds, then transition out
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    self.dissolveSplash()
                }
            }
        )
    }

    private func dissolveSplash() {
        waveView.targetFillLevel = 0.0

        UIView.animate(
            withDuration: 0.6,
            animations: {
                self.titleLabel.alpha = 0
                self.subtitleLabel.alpha = 0
            },
            completion: { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.goToMainScreen()
                }
            }
        )
    }

    func goToMainScreen() {
        let transition = CATransition()
        transition.duration = 0.4
        transition.type = .fade
        transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        if let window = self.view.window {
            window.layer.add(transition, forKey: kCATransition)
        }

        if let initialPresenter = self.presentingViewController?.presentingViewController {
            initialPresenter.dismiss(animated: false, completion: nil)
        } else {
            self.dismiss(animated: false, completion: nil)
        }
    }
}
