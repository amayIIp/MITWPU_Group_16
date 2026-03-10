//
//  LoginViewController.swift
//  Spasht
//
//  Created by SDC-USER on 18/11/25.
//

import UIKit
import Supabase

class LoginViewController: UIViewController {

    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var continueButton: UIButton!
    @IBOutlet weak var forgotPassword: UIButton!
    
    private let client = SupabaseManager.shared.client
    var onSwitchToSignup: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        forgotPassword.addTarget(self, action: #selector(forgotPasswordTapped), for: .touchUpInside)
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
        
        Task {
            do {
                try await client.auth.signIn(email: email, password: password)
                
                // Step 1: Save email locally so LogManager can init
                StorageManager.shared.saveEmail(email)
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
                                self?.performLoginTransition()
                            }
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
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
    
    func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @IBAction func switchToSignupButtonTapped(_ sender: UIButton) {
        // Dismiss self, and trigger the presentation of A upon completion for a smooth sequence
        self.dismiss(animated: true) {
            self.onSwitchToSignup?()
        }
    }
}
