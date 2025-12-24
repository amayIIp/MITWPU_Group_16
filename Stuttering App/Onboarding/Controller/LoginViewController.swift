//
//  LoginViewController.swift
//  Spasht
//
//  Created by SDC-USER on 18/11/25.
//

import UIKit

class LoginViewController: UIViewController {

    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var continueButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupButton()
    }
    
    func setupUI() {
        let tap = UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing))
        view.addGestureRecognizer(tap)
        
        passwordTextField.isSecureTextEntry = true
    }
    
    func setupButton() {
        continueButton.configuration = .prominentGlass()
        continueButton.configuration?.title = "Sign In"
    }

    @IBAction func loginButtonTapped(_ sender: UIButton) {
        guard let inputEmail = emailTextField.text, !inputEmail.isEmpty,
              let inputPassword = passwordTextField.text, !inputPassword.isEmpty else {
//            print("Error: Please fill in all fields.")
            return
        }
        
        let storedEmail = StorageManager.shared.getEmail()
        let storedPassword = StorageManager.shared.getPassword()
        
        if storedEmail != nil && inputEmail == storedEmail && inputPassword == storedPassword {
            performLoginTransition()
        } else {
            showAlert(message: "Invalid Email or Password")
        }
    }
  
    func performLoginTransition() {
        AppState.isLoginCompleted = true
        
        let storyboard = UIStoryboard(name: "Home", bundle: nil)
        let homeVC = storyboard.instantiateViewController(withIdentifier: "HomeVC")
        
        if let sceneDelegate = view.window?.windowScene?.delegate as? SceneDelegate,
           let window = sceneDelegate.window {
            
            UIView.transition(with: window, duration: 0.3, options: .curveEaseInOut, animations: {
                window.rootViewController = homeVC
            }, completion: nil)
        }
    }
    
    func showAlert(message: String) {
        let alert = UIAlertController(title: "Login Failed", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
