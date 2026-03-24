//
//  ExerciseResultViewController.swift
//  Spasht
//
//  Created by Prathamesh Patil on 15/11/25.
//

import UIKit

class ExerciseResultViewController: UIViewController {
    
    var exerciseName: String = ""
    var durationLabelForExercise: Int = 0
    
    private let splashContainer = UIView()
    private let titleLabel = UILabel()
    private let circleLayer = CAShapeLayer()
    private let checkmarkImageView = UIImageView()
    private let completedLabel = UILabel()
    private let timeLabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        performEntryAnimation()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    private func performEntryAnimation() {
        setupRingUI()
        
        let circularProgressAnimation = CABasicAnimation(keyPath: "strokeEnd")
        circularProgressAnimation.duration = 1.0
        circularProgressAnimation.toValue = 1.0
        circularProgressAnimation.fillMode = .forwards
        circularProgressAnimation.isRemovedOnCompletion = false
        circularProgressAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        
        CATransaction.begin()
        CATransaction.setCompletionBlock {
            // Fade in checkmark and text after ring finishe
            UIView.animate(withDuration: 0.3, animations: {
                self.checkmarkImageView.alpha = 1.0
                self.completedLabel.alpha = 1.0
                self.timeLabel.alpha = 1.0
            }) { _ in
                // Wait 1 second, then dissolve the entire view controller
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.dissolveSplash()
                }
            }
        }
        circleLayer.add(circularProgressAnimation, forKey: "progressAnim")
        CATransaction.commit()
    }
    
    private func setupRingUI() {
        splashContainer.frame = view.bounds
        splashContainer.backgroundColor = UIColor(named: "bg") ?? .white
        view.addSubview(splashContainer)

        let centerPoint = view.center
        let brandColour = UIColor(resource:.buttonTheme).cgColor
        let radius: CGFloat = 80
        
        titleLabel.text = exerciseName.isEmpty ? "Stutter Test" : exerciseName
        titleLabel.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        titleLabel.textColor = .black
        titleLabel.sizeToFit()
        titleLabel.center = CGPoint(x: centerPoint.x, y: centerPoint.y - radius - 80)
        titleLabel.alpha = 1.0
        splashContainer.addSubview(titleLabel)
        
        let circularPath = UIBezierPath(arcCenter: centerPoint, radius: radius, startAngle: -CGFloat.pi / 2, endAngle: 3 * CGFloat.pi / 2, clockwise: true)
        circleLayer.path = circularPath.cgPath
        circleLayer.strokeColor = brandColour
        circleLayer.lineWidth = 20
        circleLayer.fillColor = UIColor.clear.cgColor
        circleLayer.lineCap = .round
        circleLayer.strokeEnd = 0
        splashContainer.layer.addSublayer(circleLayer)
        
        let config = UIImage.SymbolConfiguration(pointSize: 60, weight: .bold)
        checkmarkImageView.image = UIImage(systemName: "checkmark", withConfiguration: config)
        checkmarkImageView.tintColor = UIColor(cgColor: brandColour)
        checkmarkImageView.frame = CGRect(x: 0, y: 0, width: 60, height: 60)
        checkmarkImageView.center = centerPoint
        checkmarkImageView.alpha = 0
        splashContainer.addSubview(checkmarkImageView)
        
        completedLabel.text = "Completed !!"
        completedLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        completedLabel.textColor = .black
        completedLabel.sizeToFit()
        completedLabel.center = CGPoint(x: centerPoint.x, y: centerPoint.y - radius - 40)
        completedLabel.alpha = 0
        splashContainer.addSubview(completedLabel)
        
        timeLabel.text = formatDuration(durationLabelForExercise)
        timeLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        timeLabel.textColor = .black
        timeLabel.sizeToFit()
        timeLabel.center = CGPoint(x: centerPoint.x, y: centerPoint.y + radius + 40)
        timeLabel.alpha = 0
        splashContainer.addSubview(timeLabel)
    }
    
    private func dissolveSplash() {
            self.goToMainScreen()
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
