//
//  OnboardingNameViewController.swift
//  Spasht
//
//  Created by SDC-USER on 18/11/25.
//

import UIKit

class OnboardingNameViewController: UIViewController, UITextFieldDelegate {
    
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
    }
    
    func setupDismissKeyboardGesture() {
        let tapGesture = UITapGestureRecognizer(target: view,
                                               action: #selector(UIView.endEditing))
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
        
        StorageManager.shared.saveName(name)
    }
}
