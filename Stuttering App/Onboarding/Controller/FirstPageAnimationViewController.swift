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
    @IBOutlet weak var continueButton: UIButton!
    
    var hasSetInitialState = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        headerLabel.alpha = 0
        infoLabel.alpha = 0
        continueButton.alpha = 0
        
        setupButton()
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
    
    func setupButton() {
        continueButton.configuration = .prominentGlass()
        continueButton.configuration?.title = "Continue"
    }
    
    private func setupInitialState() {
        headerLabel.alpha = 1
        
        // view.bounds.midY gives the exact vertical center of the visible screen
        let screenCenterY = view.bounds.midY
        let labelCenterY = headerLabel.center.y
        
        //print("ScreenCenterY\(screenCenterY)")
        //print("LabelCenterY\(labelCenterY)")
        let distanceToCenter = screenCenterY - labelCenterY
        // Move it down to the center
        let moveDown = CGAffineTransform(translationX: 0, y: distanceToCenter)
        let scaleUp = CGAffineTransform(scaleX: 2.0, y: 2.0)
        
        headerLabel.transform = scaleUp.concatenating(moveDown)
    }
    
    private func startSequenceAnimation() {
        // Animate Header back to Top
        UIView.animate(withDuration: 2.0,
                       delay: 0.2,
                       usingSpringWithDamping: 0.85,
                       initialSpringVelocity: 0.5,
                       options: .curveEaseInOut) {
            
            // This automatically moves it back to the storyboard position
            self.headerLabel.transform = .identity
            
        } completion: { _ in
            
            UIView.animate(withDuration: 0.5) {
                self.infoLabel.alpha = 1.0
                self.continueButton.alpha = 1.0
            }
        }
    }

}
