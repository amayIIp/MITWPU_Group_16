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
    
    // Animate this from 0.0 to 1.0 to fill the screen
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
    
    @objc private func updateWaves() {
        phase += 0.05
        
        // Smoothly interpolate fillLevel to targetFillLevel
        fillLevel += (targetFillLevel - fillLevel) * 0.04
        
        let width = bounds.width
        let height = bounds.height
        
        // Target water level (Y coordinate). fillLevel 0 = bottom, 1 = top
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
    var durationLabelForExercise: Int = 0
    
    private let waveView = WaveBackgroundView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let timeContainer = UIView()
    private let timeLabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        performEntryAnimation()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
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
        
        // 3. Setup Time Badge
        timeContainer.backgroundColor = brandColor.withAlphaComponent(0.15)
        timeContainer.layer.cornerRadius = 20
        timeContainer.alpha = 0
        timeContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(timeContainer)
        
        timeLabel.text = formatDuration(durationLabelForExercise)
        timeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 18, weight: .bold)
        timeLabel.textColor = brandColor
        timeLabel.textAlignment = .center
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeContainer.addSubview(timeLabel)
        
        // Layout
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -60),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            timeContainer.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 30),
            timeContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            timeContainer.heightAnchor.constraint(equalToConstant: 40),
            
            timeLabel.leadingAnchor.constraint(equalTo: timeContainer.leadingAnchor, constant: 20),
            timeLabel.trailingAnchor.constraint(equalTo: timeContainer.trailingAnchor, constant: -20),
            timeLabel.centerYAnchor.constraint(equalTo: timeContainer.centerYAnchor)
        ])
    }
    
    private func performEntryAnimation() {
        // Initial state
        titleLabel.transform = CGAffineTransform(translationX: 0, y: 30)
        subtitleLabel.transform = CGAffineTransform(translationX: 0, y: 30)
        timeContainer.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        
        // Let the wave fill up to 35% of the screen (bottom footer)
        waveView.targetFillLevel = 0.35
        
        // Animate text in
        UIView.animate(withDuration: 0.8, delay: 0.5, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseOut, animations: {
            self.titleLabel.alpha = 1.0
            self.titleLabel.transform = .identity
            
            self.subtitleLabel.alpha = 1.0
            self.subtitleLabel.transform = .identity
        })
        
        UIView.animate(withDuration: 0.6, delay: 0.8, usingSpringWithDamping: 0.7, initialSpringVelocity: 0, options: .curveEaseOut, animations: {
            self.timeContainer.alpha = 1.0
            self.timeContainer.transform = .identity
        }) { _ in
            // Stay for 2.5 seconds, then transition out
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                self.dissolveSplash()
            }
        }
    }
    
    private func dissolveSplash() {
        // Drop the wave back down
        waveView.targetFillLevel = 0.0
        
        UIView.animate(withDuration: 0.6, animations: {
            self.titleLabel.alpha = 0
            self.subtitleLabel.alpha = 0
            self.timeContainer.alpha = 0
            self.timeContainer.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        }) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.goToMainScreen()
            }
        }
    }
    
    func formatDuration(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds) Sec"
        } else {
            let minutes = Int((Double(seconds) / 60.0).rounded())
            return "\(minutes) Min"
        }
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
