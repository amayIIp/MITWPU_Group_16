//
//  OnboardingNameViewController.swift
//  Spasht
//
//  Created by SDC-USER on 18/11/25.
//

import UIKit

class OnboardingNameViewController: UIViewController, UITextViewDelegate {
    
    @IBOutlet weak var nameTextView: UITextView!
    @IBOutlet weak var continueButton: UIButton!
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupButton()
        setupDismissKeyboardGesture()
    }
    
    
    func setupButton() {
        continueButton.configuration = .prominentGlass()
        continueButton.configuration?.title = "Continue"
    }
    
    func setupDismissKeyboardGesture() {
        let tapGesture = UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing))
        view.addGestureRecognizer(tapGesture)
    }

    @IBAction func continueButtonTapped(_ sender: UIButton) {
        guard let name = nameTextView.text,
              !name.isEmpty,
              nameTextView.textColor != .placeholderText else {
//            print("Name field is empty or contains placeholder.")
            return
        }
        
        StorageManager.shared.saveName(name)
    }
}
