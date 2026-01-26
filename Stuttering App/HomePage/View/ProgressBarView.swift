//
//  ProgressBarView.swift
//  Spasht
//
//  Created by Prathamesh Patil on 16/11/25.
//

import Foundation
import UIKit

class ProgressBarView: UIView {
    
    private let backgroundLayer = CALayer()
    private let progressLayer = CALayer()
    
    @IBInspectable var progress: CGFloat = 0.0 {
        didSet {
            progress = max(0.0, min(1.0, progress))
            updateProgress()
        }
    }
    
    var progressColor: UIColor = .systemBlue {
        didSet {
            progressLayer.backgroundColor = progressColor.cgColor
        }
    }
    
    var trackColor: UIColor = UIColor(red: 0.923, green: 0.948, blue: 0.977, alpha: 1.0) {
        didSet {
            backgroundLayer.backgroundColor = trackColor.cgColor
        }
    }
    
    var barHeight: CGFloat = 18.0 {
        didSet {
            setupLayers()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }
    
    private func setupLayers() {
        layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        
        backgroundLayer.backgroundColor = trackColor.cgColor
        backgroundLayer.cornerRadius = barHeight / 2
        layer.addSublayer(backgroundLayer)
        
        progressLayer.backgroundColor = progressColor.cgColor
        progressLayer.cornerRadius = barHeight / 2
        layer.addSublayer(progressLayer)
        
        updateProgress()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        backgroundLayer.frame = CGRect(x: 0, y: 0, width: bounds.width, height: barHeight)
        updateProgress()
    }
    
    private func updateProgress() {
        let progressWidth = bounds.width * progress
        progressLayer.frame = CGRect(x: 0, y: 0, width: progressWidth, height: barHeight)
    }
    
    func setProgress(_ progress: CGFloat, animated: Bool, duration: TimeInterval = 0.3) {
        if animated {
            let animation = CABasicAnimation(keyPath: "bounds.size.width")
            animation.fromValue = progressLayer.bounds.width
            animation.toValue = bounds.width * max(0.0, min(1.0, progress))
            animation.duration = duration
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            progressLayer.add(animation, forKey: "widthAnimation")
        }
        
        self.progress = progress
    }
}
