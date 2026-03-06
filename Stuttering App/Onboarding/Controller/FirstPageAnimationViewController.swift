//
//  FirstPageAnimationViewController.swift
//  Spasht
//
//  Created by Prathamesh Patil on 19/11/25.
//

import UIKit

class FirstPageAnimationViewController: UIViewController {

    @IBOutlet weak var headerLabel: UIImageView!
    @IBOutlet weak var infoLabel: UIStackView!

    @IBOutlet weak var buttonView: UIView!
    var hasSetInitialState = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        headerLabel.alpha = 0
        infoLabel.alpha = 0
        buttonView.alpha = 0
    }
    

    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if !hasSetInitialState {
            setupInitialState()
            hasSetInitialState = true
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startSequenceAnimation()
    }
    
    
//    private func setupInitialState() {
//        headerLabel.alpha = 1
//        
//        // view.bounds.midY gives the exact vertical center of the visible screen
//        let screenCenterY = view.bounds.midY
//        let labelCenterY = headerLabel.center.y
//        
//        let distanceToCenter = screenCenterY - labelCenterY
//        // Move it down to the center
//        let moveDown = CGAffineTransform(translationX: 0, y: distanceToCenter)
//        let scaleUp = CGAffineTransform(scaleX: 2.0, y: 2.0)
//        
//        headerLabel.transform = scaleUp.concatenating(moveDown)
//    }
    
    private func setupInitialState() {
        headerLabel.alpha = 1

        let screenCenterY = view.bounds.midY
        let labelCenterY = headerLabel.center.y

        let distanceToCenter = screenCenterY - labelCenterY
        let moveDown = CGAffineTransform(translationX: 0, y: distanceToCenter)
        let scaleUp = CGAffineTransform(scaleX: 2.0, y: 2.0)

        headerLabel.transform = scaleUp.concatenating(moveDown)

        // Move buttonView below the screen
        buttonView.transform = CGAffineTransform(translationX: 0, y: view.bounds.height)
    }
    
//    private func startSequenceAnimation() {
//          // Animate Header back to Top
//        UIView.animate(withDuration: 2.0,
//                       delay: 0.2,
//                       usingSpringWithDamping: 0.85,
//                       initialSpringVelocity: 0.5,
//                       options: .curveEaseInOut) {
//            
//            // This automatically moves it back to the storyboard position
//            self.headerLabel.transform = .identity
//            
//        } completion: { _ in
//            
//            UIView.animate(withDuration: 0.5) {
//                self.infoLabel.alpha = 1.0
//                self.buttonView.alpha = 1.0
//                
//            }
//        }
//    }
    private func startSequenceAnimation() {
        
        // Step 1: Logo moves to top
        UIView.animate(withDuration: 2.0,
                       delay: 0.2,
                       usingSpringWithDamping: 0.85,
                       initialSpringVelocity: 0.5,
                       options: .curveEaseInOut) {
            
            self.headerLabel.transform = .identity
            
        } completion: { _ in
            
            // Step 2: Text fades in
            UIView.animate(withDuration: 1.25,
                           delay: 0.1,
                           options: .curveEaseInOut) {
                
                self.infoLabel.alpha = 1.0
                
            }
            
            // Step 3: Bottom panel starts animating AT THE SAME TIME
            UIView.animate(withDuration: 1.5,
                           delay: 0.3,
                           options: .curveEaseOut) {
                
                self.buttonView.alpha = 1
                self.buttonView.transform = .identity
            }
        }
    }

}
