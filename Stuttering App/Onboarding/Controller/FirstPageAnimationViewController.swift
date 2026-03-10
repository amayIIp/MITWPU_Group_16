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
    
    // MARK: - New Button Outlets
    @IBOutlet weak var SignUpButton: UIButton!
    @IBOutlet weak var SigninButton: UIButton!
    
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
    
    private func setupInitialState() {
        headerLabel.alpha = 1

        let screenCenterY = view.bounds.midY
        let labelCenterY = headerLabel.center.y

        let distanceToCenter = screenCenterY - labelCenterY
        let moveDown = CGAffineTransform(translationX: 0, y: distanceToCenter)
        let scaleUp = CGAffineTransform(scaleX: 2.0, y: 2.0)

        headerLabel.transform = scaleUp.concatenating(moveDown)
        buttonView.transform = CGAffineTransform(translationX: 0, y: view.bounds.height)
    }

    private func startSequenceAnimation() {
    
        UIView.animate(withDuration: 2.0,
                       delay: 0.2,
                       usingSpringWithDamping: 0.85,
                       initialSpringVelocity: 0.5,
                       options: .curveEaseInOut) {
            
            self.headerLabel.transform = .identity
            
        } completion: { _ in

            UIView.animate(withDuration: 1.25,
                           delay: 0.1,
                           options: .curveEaseInOut) {
                
                self.infoLabel.alpha = 1.0
                
            }
            
            UIView.animate(withDuration: 1.5,
                           delay: 0.3,
                           options: .curveEaseOut) {
                
                self.buttonView.alpha = 1
                self.buttonView.transform = .identity
            }
        }
    }

    // MARK: - Button Actions
    
    @IBAction func buttonATapped(_ sender: UIButton) {
        animateOutAndPresentSheet(storyboardID: "SignUpViewController", heightMultiplier: 0.75)
    }
    
    @IBAction func buttonBTapped(_ sender: UIButton) {
        animateOutAndPresentSheet(storyboardID: "LoginViewController", heightMultiplier: 0.65)
    }
    
    // MARK: - Exit Animation & Modal Presentation
    
    private func animateOutAndPresentSheet(storyboardID: String, heightMultiplier: CGFloat) {
        // 1. Reverse the entry animation
        UIView.animate(withDuration: 0.8,
                       delay: 0,
                       options: .curveEaseInOut,
                       animations: {
            
            self.infoLabel.alpha = 0
            self.buttonView.transform = CGAffineTransform(translationX: 0, y: self.view.bounds.height)
            
        }) { _ in
            // 2. Present the modal after animation finishes
            self.presentCustomSheet(storyboardID: storyboardID, heightMultiplier: heightMultiplier)
        }
    }
    
    private func presentCustomSheet(storyboardID: String, heightMultiplier: CGFloat) {
        let storyboard = UIStoryboard(name: "Onboarding", bundle: nil)
        let modalVC = storyboard.instantiateViewController(withIdentifier: storyboardID)
        
        // 1. Prevent the modal from being dismissed via swipe or tapping outside
        modalVC.isModalInPresentation = true
        
        if let sheet = modalVC.sheetPresentationController {
            let detentID = UISheetPresentationController.Detent.Identifier("customHeight_\(storyboardID)")
            let customDetent = UISheetPresentationController.Detent.custom(identifier: detentID) { context in
                return context.maximumDetentValue * heightMultiplier
            }
            
            sheet.detents = [customDetent]
            sheet.prefersGrabberVisible = false
            sheet.preferredCornerRadius = 24.0
            
            // 2. Remove the background dimming effect
            sheet.largestUndimmedDetentIdentifier = detentID
        }
        
        // 3. Routing Logic: Pass closures to handle the smooth swapping of sheets
        if let vcA = modalVC as? SignUpViewController {
            vcA.onSwitchToSignin = { [weak self] in
                self?.presentCustomSheet(storyboardID: "LoginViewController", heightMultiplier: 0.65)
            }
        } else if let vcB = modalVC as? LoginViewController {
            vcB.onSwitchToSignup = { [weak self] in
                self?.presentCustomSheet(storyboardID: "SignUpViewController", heightMultiplier: 0.75)
            }
        }
        
        present(modalVC, animated: true)
    }
}
