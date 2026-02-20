//
//  SignUpViewController.swift
//  Spasht
//
//  Created by SDC-USER on 18/11/25.
//

import UIKit

class SignUpViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var confirmPasswordTextField: UITextField!
    @IBOutlet weak var SignUpButton: UIButton!
    
    @IBOutlet weak var nameTextField: UITextField!
    override func viewDidLoad() {
        super.viewDidLoad()
        //setupButtons()
        setupUI()
        setupTextField()
    }
    
    func setupButtons() {
        SignUpButton.configuration = .prominentGlass()
        SignUpButton.configuration?.title = "Sign Up"
    }
    func setupTextField() {
        nameTextField.delegate = self
        //nameTextField.placeholder = "Enter your name"
        nameTextField.returnKeyType = .done
    }
    func setupUI() {
        let tap = UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing))
        view.addGestureRecognizer(tap)
        
        passwordTextField.isSecureTextEntry = true
        confirmPasswordTextField.isSecureTextEntry = true

    }


    @IBAction func signUpButtonTapped(_ sender: UIButton) {
        
        guard let email = emailTextField.text, !email.isEmpty,
              let password = passwordTextField.text, !password.isEmpty,
              let confirmPassword = confirmPasswordTextField.text, !confirmPassword.isEmpty else {
            showAlert(message: "Please fill in all fields.")
            return
        }
        
        if !isValidEmail(email) {
            showAlert(message: "Please enter a valid email address.")
            return
        }
    
        if password != confirmPassword {
            showAlert(message: "Passwords do not match. Please try again.")
            return
        }
        
        if password.count < 8 {
            showAlert(message: "Password is too short. It must be at least 8 characters.")
            return
        }
        
            guard let name = nameTextField.text,
                  !name.trimmingCharacters(in: .whitespaces).isEmpty else {
                return
            }
            
            StorageManager.shared.saveName(name)
        
        StorageManager.shared.saveEmail(email)
        StorageManager.shared.savePassword(password)
        AppState.isLoginCompleted = true
        handleNavigationLogic() // takes to homepage and sets it to be the  default vc on reopening app
    }
    
    
    func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    
    func showAlert(message: String) {
        let alert = UIAlertController(title: "Alert", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    func handleNavigationLogic() {
        if AppState.isOnboardingCompleted {
            if let presentingVC = self.navigationController?.presentingViewController {
                presentingVC.dismiss(animated: true)
            } else {
                let storyboard = UIStoryboard(name: "Home", bundle: nil)
                let homeVC = storyboard.instantiateViewController(withIdentifier: "HomeVC")
                if let sceneDelegate = view.window?.windowScene?.delegate as? SceneDelegate,
                   let window = sceneDelegate.window {
                    window.rootViewController = homeVC
                }
            }
        } else {
            let storyboard = UIStoryboard(name: "Onboarding", bundle: nil)
            let onboardingVC = storyboard.instantiateViewController(withIdentifier: "onboardingPg2")
            navigationController?.pushViewController(onboardingVC, animated: true)
        }
    }
}
