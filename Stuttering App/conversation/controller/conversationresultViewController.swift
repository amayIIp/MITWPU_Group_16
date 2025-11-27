//
//  conversationresultViewController.swift
//  Stuttering App
//
//  Created by SDC-USER on 27/11/25.
//

import UIKit

class conversationresultViewController: UIViewController {

    @IBOutlet weak var fluencyCircleView: UIView!
    override func viewDidLoad() {
        super.viewDidLoad()
        setupFluencyCircle(score: 60)
        // Do any additional setup after loading the view.
    }
    

    func setupFluencyCircle(score: CGFloat) {
        fluencyCircleView.layoutIfNeeded()   // ensure frame is ready
        
        let center = CGPoint(x: fluencyCircleView.bounds.midX,
                             y: fluencyCircleView.bounds.midY)

        let radius = (fluencyCircleView.bounds.width / 2) - 14

        // Background circle (light gray)
        let backgroundCircle = CAShapeLayer()
        let circlePath = UIBezierPath(arcCenter: center,
                                      radius: radius - 14,
                                      startAngle: -.pi / 2,
                                      endAngle: 1.5 * .pi,
                                      clockwise: true)
        
        backgroundCircle.path = circlePath.cgPath
        backgroundCircle.strokeColor = UIColor.systemGray5.cgColor
        backgroundCircle.lineWidth = 28
        backgroundCircle.fillColor = UIColor.clear.cgColor
        backgroundCircle.lineCap = .round
        fluencyCircleView.layer.addSublayer(backgroundCircle)
        
        // Progress circle (blue)
        let progressCircle = CAShapeLayer()
        progressCircle.path = circlePath.cgPath
        progressCircle.strokeColor = UIColor.systemBlue.cgColor
        progressCircle.lineWidth = 28
        progressCircle.fillColor = UIColor.clear.cgColor
        progressCircle.lineCap = .round
        progressCircle.strokeEnd = 0
        fluencyCircleView.layer.addSublayer(progressCircle)
        
        // Animate progress
        let progress = score / 100  // score out of 100
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.toValue = progress
        animation.duration = 1.2
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        progressCircle.add(animation, forKey: "progressAnim")
        
        // Add the score label
        let scoreLabel = UILabel(frame: fluencyCircleView.bounds)
        scoreLabel.text = "\(Int(score))"
        scoreLabel.textAlignment = .center
        scoreLabel.font = UIFont.boldSystemFont(ofSize: 45)
        scoreLabel.textColor = .black
        fluencyCircleView.addSubview(scoreLabel)
    }

}
