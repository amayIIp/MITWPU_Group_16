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
        // Shift anchor point so it draws left-to-right
        backgroundLayer.anchorPoint = CGPoint(x: 0, y: 0.5)
        layer.addSublayer(backgroundLayer)
        
        progressLayer.backgroundColor = progressColor.cgColor
        progressLayer.cornerRadius = barHeight / 2
        // Shift anchor point so animations grow left-to-right
        progressLayer.anchorPoint = CGPoint(x: 0, y: 0.5)
        layer.addSublayer(progressLayer)
        
        updateProgress()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Because the anchor point is (0, 0.5), we set position to the vertical center
        let yCenter = bounds.height / 2
        backgroundLayer.bounds = CGRect(x: 0, y: 0, width: bounds.width, height: barHeight)
        backgroundLayer.position = CGPoint(x: 0, y: yCenter)
        
        progressLayer.position = CGPoint(x: 0, y: yCenter)
        updateProgress()
    }
    
    private func updateProgress() {
            let rawWidth = bounds.width * progress
            let targetWidth: CGFloat
            
            if progress <= 0.0 {
                targetWidth = 0.0
            } else {
                // Clamps the minimum width to barHeight (perfect circle)
                // until the actual progress width outgrows it.
                targetWidth = max(barHeight, rawWidth)
            }
            
            // Disable implicit animations so layout updates don't lag or jitter
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            progressLayer.bounds = CGRect(x: 0, y: 0, width: targetWidth, height: barHeight)
            CATransaction.commit()
        }
        
        func setProgress(_ progress: CGFloat, animated: Bool, duration: TimeInterval = 0.3) {
            let clampedProgress = max(0.0, min(1.0, progress))
            
            if animated {
                let rawWidth = bounds.width * clampedProgress
                let targetWidth: CGFloat
                
                if clampedProgress <= 0.0 {
                    targetWidth = 0.0
                } else {
                    targetWidth = max(barHeight, rawWidth)
                }
                
                let animation = CABasicAnimation(keyPath: "bounds.size.width")
                animation.fromValue = progressLayer.bounds.width
                animation.toValue = targetWidth
                animation.duration = duration
                animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                progressLayer.add(animation, forKey: "widthAnimation")
            }
            
            self.progress = clampedProgress
        }
}
