import UIKit
import Supabase
import GoogleSignIn

class SignUpViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var SignUpButton: UIButton!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var googleSignIn: UIButton!
    @IBOutlet weak var continueAsGuest: UIButton!
    
    // NEW OUTLET: Connect this to your button in Storyboard
    @IBOutlet weak var passwordToggleButton: UIButton!
    
    private let client = SupabaseManager.shared.client
    var onSwitchToSignin: (() -> Void)?
    private var loadingOverlay: WaveLoadingOverlay?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTextField()
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
    
    func setupTextField() {
        nameTextField.delegate = self
        nameTextField.returnKeyType = .done
    }
    
    func setupUI() {
        let tap = UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing))
        view.addGestureRecognizer(tap)
        
        // Hide "Continue as Guest" if they are already a guest upgrading their account
        if SessionManager.shared.isGuestMode {
            continueAsGuest?.isHidden = true
        }
        
        // --- Fat-finger fix: ensure minimum 44pt touch targets ---
        applyButtonInsets(to: continueAsGuest, top: 12, leading: 16, bottom: 12, trailing: 16)
        
        // --- Password Toggle Config ---
        passwordTextField.isSecureTextEntry = true
        
        // Configure the eye icon (Small scale, Secondary Label color)
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium, scale: .small)
        passwordToggleButton.setImage(UIImage(systemName: "eye.slash", withConfiguration: config), for: .normal)
        passwordToggleButton.tintColor = .secondaryLabel
        
        // Attach to text field
        passwordTextField.rightView = passwordToggleButton
        passwordTextField.rightViewMode = .always
    }

    // NEW ACTION: Connect your button's "Touch Up Inside" to this
    @IBAction func togglePasswordVisibility(_ sender: UIButton) {
        passwordTextField.isSecureTextEntry.toggle()
        
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium, scale: .small)
        let imageName = passwordTextField.isSecureTextEntry ? "eye.slash" : "eye"
        sender.setImage(UIImage(systemName: imageName, withConfiguration: config), for: .normal)
        
        // Cursor fix
        if let text = passwordTextField.text {
            passwordTextField.text = nil
            passwordTextField.text = text
        }
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
                let authResponse = try await client.auth.signUp(
                    email: email,
                    password: password,
                    data: ["first_name": .string(name)]
                )

                // BUG-02 fix: after signUp, currentUser is nil when Supabase has
                // email confirmation enabled. Don't try to sign in or push data
                // until the user confirms — show a clear message and stop here.
                guard SupabaseManager.shared.currentUser != nil else {
                    await MainActor.run {
                        self.hideLoading()
                        self.SignUpButton.isEnabled = true
                        self.showAlert(message: "Account created! Please check your email to confirm your account before logging in.")
                    }
                    return
                }

                // ISSUE-11 fix: use the userId from authResponse directly.
                // Do NOT re-fetch from LogManager which may still hold the guest ID.
                let userId = authResponse.user.id.uuidString
                SessionManager.shared.startAccountSession(userId: userId)
                LogManager.shared.initializeUserIfNeeded()

                LogManager.shared.migrateGuestData(to: userId)
                var profile = LogManager.shared.getProfile(userId: userId) ?? UserProfile(id: userId, isOnboardingCompleted: false)
                profile.firstName = name
                LogManager.shared.saveProfile(profile)

                // ISSUE-09 fix: await the push so we only navigate after data
                // is safely in the cloud (no navigation-before-push data loss).
                try await SupabaseSyncManager.shared.pushAllLocalDataToCloud()

                AppState.isLoginCompleted = true

                await MainActor.run {
                    self.hideLoading()
                    self.SignUpButton.isEnabled = true
                    self.handleNavigationLogic()
                }
            } catch {
                await MainActor.run {
                    self.hideLoading()
                    self.SignUpButton.isEnabled = true
                    self.showAlert(message: error.localizedDescription)
                }
            }
        }
    }
        
    @IBAction func switchToSigninButtonTapped(_ sender: UIButton) {
        // Fat-finger fix applied on first tap if not already set
        applyButtonInsetsIfNeeded(to: sender, top: 12, leading: 8, bottom: 12, trailing: 8)
        guard let presentingVC = self.presentingViewController else { return }
        self.dismiss(animated: true) {
            let storyboard = UIStoryboard(name: "Onboarding", bundle: nil)
            let nextModalVC = storyboard.instantiateViewController(withIdentifier: "LoginViewController")

            // 1. Wrap the Login view in a Navigation Controller
            // This gives you a top bar for titles and future "Cancel" or "Done" buttons.
            let navController = UINavigationController(rootViewController: nextModalVC)

            // 2. Enable Large Titles
            navController.navigationBar.prefersLargeTitles = true

            // 3. Configure the Sheet (Modal) behavior
            // Note: We apply these settings to the navController, not nextModalVC.
            navController.modalPresentationStyle = .pageSheet
            if let sheet = navController.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
            }

            // 4. Present the Navigation Controller from your presenting view controller
            presentingVC.present(navController, animated: true)
        }
    }
    
    // MARK: - Helpers & Navigation (Existing)
    
    private func showLoading(message: String = "Creating your account") {
        guard loadingOverlay == nil else { return }
        loadingOverlay = WaveLoadingOverlay.showOnWindow(message: message)
    }

    private func hideLoading() {
        loadingOverlay?.dismiss()
        loadingOverlay = nil
    }

    func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }

    private func applyButtonInsets(to button: UIButton?, top: CGFloat, leading: CGFloat, bottom: CGFloat, trailing: CGFloat) {
        guard let button else { return }
        var configuration = button.configuration ?? .plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: top, leading: leading, bottom: bottom, trailing: trailing)
        button.configuration = configuration
    }

    private func applyButtonInsetsIfNeeded(to button: UIButton, top: CGFloat, leading: CGFloat, bottom: CGFloat, trailing: CGFloat) {
        let currentInsets = button.configuration?.contentInsets ?? .zero
        guard currentInsets == .zero else { return }
        applyButtonInsets(to: button, top: top, leading: leading, bottom: bottom, trailing: trailing)
    }
    
    func showAlert(message: String) {
        let alert = UIAlertController(title: "Alert", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    // MARK: - Nonce helpers are in AuthHelpers.swift
    
    @objc private func googleSignInTapped() {
        let rawNonce = AuthHelpers.randomNonceString()
        let hashedNonce = AuthHelpers.sha256(rawNonce)
        showLoading(message: "Connecting with Google")
        Task {
            do {
                let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: self, hint: nil, additionalScopes: nil, nonce: hashedNonce)
                let user = result.user
                guard let idToken = user.idToken?.tokenString else {
                    await MainActor.run {
                        self.hideLoading()
                        self.showAlert(message: "Failed to get ID token")
                    }
                    return
                }
                let accessToken = user.accessToken.tokenString
                _ = try await client.auth.signInWithIdToken(credentials: .init(provider: .google, idToken: idToken, accessToken: accessToken, nonce: rawNonce))

                guard let supabaseUser = SupabaseManager.shared.currentUser else { return }
                // ISSUE-11 fix: use the confirmed Supabase user ID directly.
                let userId = supabaseUser.id.uuidString
                SessionManager.shared.startAccountSession(userId: userId)
                LogManager.shared.initializeUserIfNeeded()

                LogManager.shared.migrateGuestData(to: userId)
                var profile = LogManager.shared.getProfile(userId: userId) ?? UserProfile(id: userId, isOnboardingCompleted: false)
                if let displayName = result.user.profile?.name { profile.firstName = displayName }
                LogManager.shared.saveProfile(profile)

                // ISSUE-09 fix: await push before navigating.
                try await SupabaseSyncManager.shared.pushAllLocalDataToCloud()

                AppState.isLoginCompleted = true
                await MainActor.run {
                    self.hideLoading()
                    self.handleNavigationLogic()
                }
            } catch {
                await MainActor.run {
                    self.hideLoading()
                    self.showAlert(message: error.localizedDescription)
                }
            }
        }
    }
    
    func handleNavigationLogic() {
        if AppState.isOnboardingCompleted {
            if let sceneDelegate = view.window?.windowScene?.delegate as? SceneDelegate,
               let window = sceneDelegate.window {
                let storyboard = UIStoryboard(name: "Home", bundle: nil)
                window.rootViewController = storyboard.instantiateViewController(withIdentifier: "HomeVC")
            }
        } else {
            let storyboard = UIStoryboard(name: "Onboarding", bundle: nil)
            let onboardingVC = storyboard.instantiateViewController(withIdentifier: "PhonemesSelectionViewController")
            guard let window = view.window else { return }
            window.backgroundColor = .systemBackground
            UIView.animate(withDuration: 0.3, animations: { window.rootViewController?.view.alpha = 0 }) { _ in
                onboardingVC.view.alpha = 0
                window.rootViewController = onboardingVC
                UIView.animate(withDuration: 0.3) { onboardingVC.view.alpha = 1 }
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.destination is OnboardingNameViewController {
            // startGuestSession() now internally calls initializeGuestUser(),
            // so we only need one call here.
            SessionManager.shared.startGuestSession()
        }
    }
}
