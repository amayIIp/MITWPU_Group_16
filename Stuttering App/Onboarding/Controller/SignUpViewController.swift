//
//  SignUpViewController.swift
//  Spasht
//
//  Created by SDC-USER on 18/11/25.
//

import UIKit
import Supabase
import GoogleSignIn
import CryptoKit

class SignUpViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var SignUpButton: UIButton!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var googleSignIn: UIButton!
    
    private let client = SupabaseManager.shared.client
    var onSwitchToSignin: (() -> Void)?
    
    private var loadingOverlay: UIView?
    
    private func showLoading() {
        let overlay = UIView(frame: view.bounds)
        overlay.backgroundColor = UIColor(white: 0, alpha: 0.5)
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.center = overlay.center
        indicator.startAnimating()
        overlay.addSubview(indicator)
        view.addSubview(overlay)
        loadingOverlay = overlay
    }
    
    private func hideLoading() {
        loadingOverlay?.removeFromSuperview()
        loadingOverlay = nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTextField()
        googleSignIn.addTarget(self, action: #selector(googleSignInTapped), for: .touchUpInside)
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
        showLoading()
        
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
                    self.hideLoading()
                    self.SignUpButton.isEnabled = true
                    self.handleNavigationLogic()
                }
            } catch {
                DispatchQueue.main.async {
                    self.hideLoading()
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
    
    // MARK: - Nonce Helpers
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 { return }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            return String(format: "%02x", $0)
        }.joined()
        return hashString
    }
    
    @objc private func googleSignInTapped() {
        // You MUST configure Google Sign-in with your iOS Client ID somewhere in the app (like AppDelegate or here).
        // e.g. GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: "YOUR_IOS_CLIENT_ID")
        
        let rawNonce = randomNonceString()
        let hashedNonce = sha256(rawNonce)
        
        showLoading()
        
        Task {
            do {
                let result = try await GIDSignIn.sharedInstance.signIn(
                    withPresenting: self,
                    hint: nil,
                    additionalScopes: nil,
                    nonce: hashedNonce
                )
                let user = result.user
                
                guard let idToken = user.idToken?.tokenString else {
                    self.hideLoading()
                    showAlert(message: "Failed to get ID token")
                    return
                }
                
                let accessToken = user.accessToken.tokenString
                
                // Authenticate with Supabase using the Google ID Token
                let session = try await client.auth.signInWithIdToken(
                    credentials: .init(
                        provider: .google,
                        idToken: idToken,
                        accessToken: accessToken,
                        nonce: rawNonce
                    )
                )
                
                // Save locally for offline access
                LogManager.shared.initializeUserIfNeeded()
                
                if let userId = LogManager.shared.getCurrentUserId() {
                    var profile = LogManager.shared.getProfile(userId: userId) ?? UserProfile(id: userId, isOnboardingCompleted: false)
                    // You can optionally extract name from result.user.profile?.name
                    if let displayName = result.user.profile?.name {
                        profile.firstName = displayName
                    }
                    LogManager.shared.saveProfile(profile)
                }
                
                AppState.isLoginCompleted = true
                
                DispatchQueue.main.async {
                    self.hideLoading()
                    self.handleNavigationLogic()
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.hideLoading()
                    self.showAlert(message: error.localizedDescription)
                }
            }
        }
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
