//
//  SignUpViewController.swift
//  Spasht
//
//  Created by SDC-USER on 18/11/25.
//

import UIKit
import Supabase

class SignUpViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var SignUpButton: UIButton!
    @IBOutlet weak var nameTextField: UITextField!
    
    private let client = SupabaseManager.shared.client
    var onSwitchToSignin: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTextField()
    }
    
    func setupTextField() {
        nameTextField.delegate = self
        nameTextField.returnKeyType = .done
    }
    
    func setupUI() {
        let tap = UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing))
        view.addGestureRecognizer(tap)
        passwordTextField.isSecureTextEntry = true
    }

    @IBAction func signUpButtonTapped(_ sender: UIButton) {
        guard let email = emailTextField.text, !email.isEmpty,
              let password = passwordTextField.text, !password.isEmpty
               else {
            showAlert(message: "Please fill in all fields.")
            return
        }
        
        guard let name = nameTextField.text,
              !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            showAlert(message: "Please enter your name.")
            return
        }
        
        if !isValidEmail(email) {
            showAlert(message: "Please enter a valid email address.")
            return
        }
        
        if password.count < 8 {
            showAlert(message: "Password is too short. It must be at least 8 characters.")
            return
        }
        
        SignUpButton.isEnabled = false
        
        Task {
            do {
                // Create Supabase cloud account
                try await client.auth.signUp(
                    email: email,
                    password: password,
                    data: ["first_name": .string(name)]
                )
                
                // Also save locally for offline access
                LogManager.shared.initializeUserIfNeeded()
                
                if let userId = LogManager.shared.getCurrentUserId() {
                    var profile = LogManager.shared.getProfile(userId: userId) ?? UserProfile(id: userId, isOnboardingCompleted: false)
                    profile.firstName = name
                    LogManager.shared.saveProfile(profile)
                }
                
                AppState.isLoginCompleted = true
                
                DispatchQueue.main.async {
                    self.SignUpButton.isEnabled = true
                    self.handleNavigationLogic()
                }
            } catch {
                DispatchQueue.main.async {
                    self.SignUpButton.isEnabled = true
                    self.showAlert(message: error.localizedDescription)
                }
            }
        }
    }
        
    @IBAction func switchToSigninButtonTapped(_ sender: UIButton) {
        guard let presentingVC = self.presentingViewController else {
            print("Error: No presenting view controller found.")
            return
        }
        
        // 2. Dismiss the active modal
        self.dismiss(animated: true) {
            // 3. Instantiate the next modal from your Storyboard
            let storyboard = UIStoryboard(name: "Onboarding", bundle: nil)
            let nextModalVC = storyboard.instantiateViewController(withIdentifier: "LoginViewController")
            
            // 4. (Optional) Apply modern iOS 26 sheet behaviors
            nextModalVC.modalPresentationStyle = .pageSheet
            if let sheet = nextModalVC.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
            }
            
            // 5. Present the new modal from the original underlying screen
            presentingVC.present(nextModalVC, animated: true)
        }
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
            let onboardingVC = storyboard.instantiateViewController(withIdentifier: "PhonemesSelectionViewController")
            
            guard let window = view.window else { return }

            window.backgroundColor = .systemBackground

            UIView.animate(withDuration: 0.3, animations: {
                window.rootViewController?.view.alpha = 0
            }) { _ in
                onboardingVC.view.alpha = 0
                window.rootViewController = onboardingVC
                
                UIView.animate(withDuration: 0.3) {
                    onboardingVC.view.alpha = 1
                }
            }
        }
    }
}
