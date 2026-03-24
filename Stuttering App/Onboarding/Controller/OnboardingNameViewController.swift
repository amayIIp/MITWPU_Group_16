//
//  OnboardingNameViewController.swift
//  Spasht
//
//  Created by SDC-USER on 18/11/25.
//

import UIKit

// 1. Add UIGestureRecognizerDelegate
class OnboardingNameViewController: UIViewController, UITextFieldDelegate, UIGestureRecognizerDelegate {
    
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var continueButton: UIButton!
        
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTextField()
        setupDismissKeyboardGesture()
    }
    
    func setupTextField() {
        nameTextField.delegate = self
        nameTextField.returnKeyType = .done
        
        nameTextField.autocorrectionType = .no
        nameTextField.spellCheckingType = .no
        nameTextField.smartDashesType = .no
        nameTextField.smartQuotesType = .no
        nameTextField.smartInsertDeleteType = .no
    }
    
    func setupDismissKeyboardGesture() {
        let tapGesture = UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing))
        
        // 2. Prevent the gesture from swallowing touches
        tapGesture.cancelsTouchesInView = false
        
        // 3. Set the delegate so we can filter touches
        tapGesture.delegate = self
        
        view.addGestureRecognizer(tapGesture)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    @IBAction func continueButtonTapped(_ sender: UIButton) {
        guard let name = nameTextField.text,
              !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            return
        }
        
        guard let currentUserId = LogManager.shared.getCurrentUserId() else { return }
                
        var profile = LogManager.shared.getProfile(userId: currentUserId) ?? UserProfile(id: currentUserId, isOnboardingCompleted: false)
        profile.firstName = name

        LogManager.shared.saveProfile(profile)
    }
    
    // MARK: - UIGestureRecognizerDelegate
    
    // 4. Ignore the tap gesture if the user is tapping the text field or button
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.view is UITextField || touch.view is UIButton {
            return false
        }
        return true
    }
}
