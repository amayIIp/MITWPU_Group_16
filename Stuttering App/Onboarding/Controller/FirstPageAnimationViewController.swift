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
    
    @IBAction func signUpTapped(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Onboarding", bundle: nil)
        let nextModalVC = storyboard.instantiateViewController(withIdentifier: "SignUpViewController")
        
        // 4. (Optional) Apply modern iOS 26 sheet behaviors
        nextModalVC.modalPresentationStyle = .pageSheet
        if let sheet = nextModalVC.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        
        // 5. Present the new modal from the original underlying screen
        present(nextModalVC, animated: true)
    }
    
    @IBAction func signInTapped(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Onboarding", bundle: nil)
        let nextModalVC = storyboard.instantiateViewController(withIdentifier: "LoginViewController")
        
        // 4. (Optional) Apply modern iOS 26 sheet behaviors
        nextModalVC.modalPresentationStyle = .pageSheet
        if let sheet = nextModalVC.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        
        // 5. Present the new modal from the original underlying screen
        present(nextModalVC, animated: true)

    }
    
    
}
