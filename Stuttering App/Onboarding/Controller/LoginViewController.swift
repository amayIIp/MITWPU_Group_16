//
//  LoginViewController.swift
//  Spasht
//
//  Created by SDC-USER on 18/11/25.
//

import UIKit
import Supabase
import GoogleSignIn
import CryptoKit

class LoginViewController: UIViewController {

    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var continueButton: UIButton!
    @IBOutlet weak var forgotPassword: UIButton!
    
    @IBOutlet weak var googleSignIn: UIButton!
    private let client = SupabaseManager.shared.client
    var onSwitchToSignup: (() -> Void)?
    
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
        forgotPassword.addTarget(self, action: #selector(forgotPasswordTapped), for: .touchUpInside)
        googleSignIn.addTarget(self, action: #selector(googleSignInTapped), for: .touchUpInside)
    }
    
    func setupUI() {
        let tap = UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing))
        view.addGestureRecognizer(tap)
        passwordTextField.isSecureTextEntry = true
    }

    @IBAction func loginButtonTapped(_ sender: UIButton) {
        guard let email = emailTextField.text, !email.isEmpty,
              let password = passwordTextField.text, !password.isEmpty else {
            showAlert(title: "Missing Fields", message: "Please fill in both email and password.")
            return
        }
        
        continueButton.isEnabled = false
        showLoading()
        
        Task {
            do {
                try await client.auth.signIn(email: email, password: password)
                
                // --- STEP 0: Wipe local database to replace guest data with cloud data ---
                // We do this immediately AFTER successful auth to prevent data loss on failed login!
                LogManager.shared.resetDatabaseForNewUser()
                DatabaseManager.shared.resetDatabaseForNewUser()
                AwardsManager.shared.resetDatabaseForNewUser()
                AppState.isOnboardingCompleted = false
                
                // Step 1: Init LogManager AFTER sign-in so it creates the
                // local user/profile for the correct (signed-in) user ID.
                LogManager.shared.initializeUserIfNeeded()
                
                // Step 2: Sync cloud data — restores Journey completions,
                //         awards, exercise logs, streaks, etc.
                SupabaseSyncManager.shared.syncAllDataFromCloud { [weak self] _ in
                    DispatchQueue.main.async {
                        
                        // Step 3: Reset daily tasks — now Journey is correct,
                        //         so it picks the right next exercises
                        let logic = LogicMaker()
                        logic.checkForNewDay(isFromLogin: true)
                        
                        // Step 4: Re-apply completed daily tasks from cloud
                        //         (because resetDailyTasks wiped them)
                        SupabaseSyncManager.shared.reapplyDailyTaskCompletions {
                            DispatchQueue.main.async {

                                // Step 5: Push finalized SQLite state back to cloud,
                                //         ensuring cloud accurately reflects today's set of 5 tasks.
                                DatabaseManager.shared.syncLocalDailyTasksToCloud()
                                
                                self?.continueButton.isEnabled = true
                                self?.hideLoading()
                                self?.performLoginTransition()
                            }
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.hideLoading()
                    self.continueButton.isEnabled = true
                    let msg = error.localizedDescription.contains("credentials")
                        ? "Incorrect email or password. Please try again."
                        : error.localizedDescription
                    self.showAlert(title: "Login Failed", message: msg)
                }
            }
        }
    }
    
    @objc private func forgotPasswordTapped() {
        let alert = UIAlertController(
            title: "Reset Password",
            message: "Enter your email and we'll send a reset link.",
            preferredStyle: .alert
        )
        alert.addTextField { tf in
            tf.placeholder = "Email"
            tf.keyboardType = .emailAddress
            tf.autocapitalizationType = .none
            tf.text = self.emailTextField.text
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Send Reset Link", style: .default) { [weak alert] _ in
            guard let email = alert?.textFields?.first?.text, !email.isEmpty else { return }
            self.sendPasswordReset(email: email)
        })
        present(alert, animated: true)
    }
    
    private func sendPasswordReset(email: String) {
        Task {
            do {
                try await client.auth.resetPasswordForEmail(email)
                DispatchQueue.main.async {
                    self.showAlert(title: "Email Sent ✅", message: "Check your inbox for a password reset link.")
                }
            } catch {
                DispatchQueue.main.async {
                    self.showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
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
                    showAlert(title: "Google Sign-In Error", message: "Failed to get ID token")
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
                
                // Wipe local database ONLY after successful network authentication
                LogManager.shared.resetDatabaseForNewUser()
                DatabaseManager.shared.resetDatabaseForNewUser()
                AwardsManager.shared.resetDatabaseForNewUser()
                AppState.isOnboardingCompleted = false
                
                // Sync data post-login
                LogManager.shared.initializeUserIfNeeded()
                SupabaseSyncManager.shared.syncAllDataFromCloud { [weak self] _ in
                    DispatchQueue.main.async {
                        let logic = LogicMaker()
                        logic.checkForNewDay(isFromLogin: true)
                        
                        SupabaseSyncManager.shared.reapplyDailyTaskCompletions {
                            DispatchQueue.main.async {
                                DatabaseManager.shared.syncLocalDailyTasksToCloud()
                                self?.hideLoading()
                                self?.performLoginTransition()
                            }
                        }
                    }
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.hideLoading()
                    self.showAlert(title: "Google Sign-In Failed", message: error.localizedDescription)
                }
            }
        }
    }
  
    func performLoginTransition() {
        AppState.isLoginCompleted = true
        
        if AppState.isOnboardingCompleted {
            let storyboard = UIStoryboard(name: "Home", bundle: nil)
            let homeVC = storyboard.instantiateViewController(withIdentifier: "HomeVC")

            if let sceneDelegate = view.window?.windowScene?.delegate as? SceneDelegate,
               let window = sceneDelegate.window {
                
                // Set a background color so the transition isn't harsh
                window.backgroundColor = .systemBackground
                
                // Step 1: Fade out the current root view controller
                UIView.animate(withDuration: 0.3, animations: {
                    window.rootViewController?.view.alpha = 0
                }) { _ in
                    // Step 2: Swap the root view controller while it's invisible
                    homeVC.view.alpha = 0
                    window.rootViewController = homeVC
                    
                    // Step 3: Fade in the new root view controller
                    UIView.animate(withDuration: 0.3) {
                        homeVC.view.alpha = 1
                    }
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
    
    func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @IBAction func switchToSignupButtonTapped(_ sender: UIButton) {
        guard let presentingVC = self.presentingViewController else {
            print("Error: No presenting view controller found.")
            return
        }
        
        // 2. Dismiss the active modal
        self.dismiss(animated: true) {
            // 3. Instantiate the next modal from your Storyboard
            let storyboard = UIStoryboard(name: "Onboarding", bundle: nil)
            let nextModalVC = storyboard.instantiateViewController(withIdentifier: "SignUpViewController")
            
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
}
