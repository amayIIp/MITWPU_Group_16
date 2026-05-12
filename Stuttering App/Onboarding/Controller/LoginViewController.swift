//
//  LoginViewController.swift
//  Spasht
//
//  Created by SDC-USER on 18/11/25.
//

import UIKit
import Supabase
import GoogleSignIn

class LoginViewController: UIViewController {

    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var continueButton: UIButton!
    @IBOutlet weak var forgotPassword: UIButton!
    
    @IBOutlet weak var passwordToggleButton: UIButton!
    @IBOutlet weak var googleSignIn: UIButton!
    @IBOutlet weak var continueAsGuest: UIButton!
    private let client = SupabaseManager.shared.client
    var onSwitchToSignup: (() -> Void)?
    
    private var loadingOverlay: WaveLoadingOverlay?

    private func showLoading(message: String = "Signing you in…") {
        guard loadingOverlay == nil else { return }
        let overlay = WaveLoadingOverlay.showOnWindow(message: message)
        loadingOverlay = overlay
    }

    private func hideLoading() {
        loadingOverlay?.dismiss()
        loadingOverlay = nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        forgotPassword.addTarget(self, action: #selector(forgotPasswordTapped), for: .touchUpInside)
        googleSignIn.addTarget(self, action: #selector(googleSignInTapped), for: .touchUpInside)
        setupDismissButtonIfNeeded()
    }

    private func setupDismissButtonIfNeeded() {
        guard presentingViewController != nil else { return }
        let closeButton = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(dismissSelf)
        )
        closeButton.tintColor = .label
        navigationItem.leftBarButtonItem = closeButton
    }

    @objc private func dismissSelf() {
        dismiss(animated: true)
    }
    
    func setupUI() {
        let tap = UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing))
        view.addGestureRecognizer(tap)
        
        // Hide "Continue as Guest" if they are already a guest upgrading their account
        if SessionManager.shared.isGuestMode {
            continueAsGuest?.isHidden = true
        }
        
        // --- Fat-finger fix: ensure minimum 44pt touch targets ---
        continueAsGuest?.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        
        passwordTextField.isSecureTextEntry = true

        // 1. Create a small configuration
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium, scale: .small)
        let icon = UIImage(systemName: "eye.slash", withConfiguration: config)

        // 2. Apply to the button
        passwordToggleButton.setImage(icon, for: .normal)
        passwordToggleButton.tintColor = .secondaryLabel // This gives it that subtle grey look

        // 3. Assign to the text field
        passwordTextField.rightView = passwordToggleButton
        passwordTextField.rightViewMode = .always
    }
    @IBAction func togglePasswordVisibility(_ sender: UIButton) {
        passwordTextField.isSecureTextEntry.toggle()
            
            // 2. Prepare the small configuration again
            let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium, scale: .small)
            let imageName = passwordTextField.isSecureTextEntry ? "eye.slash" : "eye"
            
            // 3. Update the image with the config
            let updatedIcon = UIImage(systemName: imageName, withConfiguration: config)
            sender.setImage(updatedIcon, for: .normal)
            
            // 4. Standard iOS fix for cursor/font jumping
            if let text = passwordTextField.text {
                passwordTextField.text = nil
                passwordTextField.text = text
            }
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

                guard let userId = SupabaseManager.shared.currentUser?.id.uuidString else {
                    throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user ID after login"])
                }
                SessionManager.shared.startAccountSession(userId: userId)

                LogManager.shared.resetDatabaseForNewUser()
                DatabaseManager.shared.resetDatabaseForNewUser()
                AwardsManager.shared.resetDatabaseForNewUser()
                AppState.resetModuleOnboarding()
                LogManager.shared.initializeUserIfNeeded()

                // Flat async chain — errors bubble to the single catch block below
                // so the loading overlay is always dismissed.
                try await SupabaseSyncManager.shared.syncAllDataFromCloud()

                await MainActor.run {
                    let logic = LogicMaker()
                    logic.checkForNewDay(isFromLogin: true)
                }

                await SupabaseSyncManager.shared.reapplyDailyTaskCompletions()

                await MainActor.run {
                    DatabaseManager.shared.syncLocalDailyTasksToCloud()
                    self.continueButton.isEnabled = true
                    self.hideLoading()
                    self.performLoginTransition()
                }

            } catch {
                await MainActor.run {
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
    
    // MARK: - Nonce helpers are in AuthHelpers.swift
    
    @objc private func googleSignInTapped() {
        let rawNonce = AuthHelpers.randomNonceString()
        let hashedNonce = AuthHelpers.sha256(rawNonce)

        showLoading(message: "Connecting with Google…")

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
                    await MainActor.run {
                        self.hideLoading()
                        self.showAlert(title: "Google Sign-In Error", message: "Failed to get ID token")
                    }
                    return
                }

                let accessToken = user.accessToken.tokenString

                _ = try await client.auth.signInWithIdToken(
                    credentials: .init(
                        provider: .google,
                        idToken: idToken,
                        accessToken: accessToken,
                        nonce: rawNonce
                    )
                )

                guard let userId = SupabaseManager.shared.currentUser?.id.uuidString else {
                    throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user ID after Google login"])
                }
                SessionManager.shared.startAccountSession(userId: userId)

                LogManager.shared.resetDatabaseForNewUser()
                DatabaseManager.shared.resetDatabaseForNewUser()
                AwardsManager.shared.resetDatabaseForNewUser()
                AppState.resetModuleOnboarding()
                LogManager.shared.initializeUserIfNeeded()

                // Flat async chain — errors bubble to the single catch block below.
                try await SupabaseSyncManager.shared.syncAllDataFromCloud()

                await MainActor.run {
                    let logic = LogicMaker()
                    logic.checkForNewDay(isFromLogin: true)
                }

                await SupabaseSyncManager.shared.reapplyDailyTaskCompletions()

                await MainActor.run {
                    DatabaseManager.shared.syncLocalDailyTasksToCloud()
                    self.hideLoading()
                    self.performLoginTransition()
                }

            } catch {
                await MainActor.run {
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
        // Fat-finger fix applied on first tap if not already set
        if sender.contentEdgeInsets == .zero {
            sender.contentEdgeInsets = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        }
        guard let presentingVC = self.presentingViewController else {
            print("Error: No presenting view controller found.")
            return
        }
        
        // 2. Dismiss the active modal
        self.dismiss(animated: true) {// 1. Instantiate the next modal from your Storyboard
            let storyboard = UIStoryboard(name: "Onboarding", bundle: nil)
            let nextModalVC = storyboard.instantiateViewController(withIdentifier: "SignUpViewController")

            // 2. Wrap your destination in a Navigation Controller
            // This enables the navigation bar for titles and action buttons.
            let navController = UINavigationController(rootViewController: nextModalVC)

            // 3. Enable Large Titles on the Navigation Bar
            navController.navigationBar.prefersLargeTitles = true

            // 4. Configure the Sheet (Modal) behavior
            // We apply the presentation style to the navController to ensure the "card" look.
            navController.modalPresentationStyle = .pageSheet
            if let sheet = navController.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
            }

            // 5. Present the Navigation Controller from the underlying screen
            presentingVC.present(navController, animated: true)
            
        }
    }
}
