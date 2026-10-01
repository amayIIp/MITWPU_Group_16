//
//  LoginViewController.swift
//  Spasht
//
//  Created by SDC-USER on 18/11/25.
//

import UIKit
import Supabase
import GoogleSignIn
import AuthenticationServices

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
    private var keyboardAvoider: KeyboardAvoider?

    private func showLoading(message: String = "Signing you in") {
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
        keyboardAvoider = KeyboardAvoider(view: view)
        setupUI()
        forgotPassword.addTarget(self, action: #selector(forgotPasswordTapped), for: .touchUpInside)
        googleSignIn.addTarget(self, action: #selector(googleSignInTapped), for: .touchUpInside)
        AppleSignInManager.installButton(above: googleSignIn,
                                         target: self,
                                         action: #selector(appleSignInTapped))
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
        } else {
            continueAsGuest?.addTarget(self,
                                       action: #selector(continueAsGuestTapped),
                                       for: .touchUpInside)
        }

        // --- Fat-finger fix: ensure minimum 44pt touch targets ---
        applyButtonInsets(to: continueAsGuest, top: 12, leading: 16, bottom: 12, trailing: 16)

        installLegalLinks()

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
    // MARK: - Legal links (Guideline 5.1.1(i))

    /// The sign-up sheet has carried this row for a while; sign-in is the other
    /// screen where credentials are handed over, and it is the screen the
    /// landing page's secondary button leads to, so it needs the same links.
    private func installLegalLinks() {
        guard let anchor = continueAsGuest, let parent = anchor.superview else { return }

        let row = LegalLinks.makeLinkRow(
            target: self,
            privacyAction: #selector(openPrivacy),
            termsAction: #selector(openTerms),
            supportAction: #selector(openSupport)
        )

        if let stack = parent as? UIStackView {
            stack.addArrangedSubview(row)
        } else {
            parent.addSubview(row)
            NSLayoutConstraint.activate([
                row.centerXAnchor.constraint(equalTo: anchor.centerXAnchor),
                row.topAnchor.constraint(equalTo: anchor.bottomAnchor, constant: 4)
            ])
        }
    }

    @objc private func openPrivacy() { LegalLinks.open(LegalLinks.privacyPolicy, from: self) }
    @objc private func openTerms()   { LegalLinks.open(LegalLinks.termsOfUse, from: self) }
    @objc private func openSupport() { LegalLinks.openSupport(from: self) }

    @objc private func continueAsGuestTapped() {
        GuestEntry.start(from: self)
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

    // MARK: - Shared post-authentication

    /// Everything that has to happen after a successful authentication,
    /// whichever provider it came from. Previously copy-pasted between the
    /// email and Google paths; Apple would have made three copies.
    ///
    /// Transactional (Q1). The old ordering reset all three local databases and
    /// *then* pulled the user's data down, so a sync failure left the user
    /// signed in with nothing while the alert blamed their password. The
    /// databases are now photocopied first and put back if any part of the
    /// sync throws, so a failed sign-in leaves the device exactly as it was.
    private func completeSignIn(userId: String) async throws {
        // Guest data has to go up before anything is reset, and it is genuinely
        // destructive to retry, so it stays outside the transaction.
        if SessionManager.shared.isGuestMode {
            LogManager.shared.migrateGuestData(to: userId)
            try await SupabaseSyncManager.shared.pushAllLocalDataToCloud()
        }

        let previousMode = SessionManager.shared.currentMode
        let previousOnboarding = AppState.isOnboardingCompleted
        let snapshot = LocalDataSnapshot.capture()

        do {
            SessionManager.shared.startAccountSession(userId: userId)

            LogManager.shared.resetDatabaseForNewUser()
            DatabaseManager.shared.resetDatabaseForNewUser()
            AwardsManager.shared.resetDatabaseForNewUser()
            AppState.resetModuleOnboarding()
            LogManager.shared.initializeUserIfNeeded()

            AppState.isOnboardingCompleted = false

            try await SupabaseSyncManager.shared.syncAllDataFromCloud()

            // Restore cloud completions BEFORE checkForNewDay.
            // reapplyDailyTaskCompletions marks the locally-inserted tasks as
            // completed so that checkForNewDay sees a non-empty, partially-done
            // list and does NOT wipe it.
            await SupabaseSyncManager.shared.reapplyDailyTaskCompletions()

            // Now checkForNewDay. If today's tasks were just restored from the
            // cloud they already exist locally, so the guard in checkForNewDay
            // bails out early (no reset, no cloud push).
            //
            // The caller then navigates, and must NOT push daily tasks back to
            // the cloud: the cloud is already the source of truth, and pushing
            // here would overwrite completed=true rows with completed=false.
            await MainActor.run {
                let logic = LogicMaker()
                logic.checkForNewDay(isFromLogin: true)
            }

            snapshot?.discard()

        } catch {
            // Put the device back exactly as it was, then let the caller show
            // the error. Without this the user is signed in with wiped data.
            snapshot?.restore()
            AppState.isOnboardingCompleted = previousOnboarding
            if previousMode == .guest {
                SessionManager.shared.startGuestSession()
            } else {
                await SessionManager.shared.endSession()
            }
            throw error
        }
    }

    @objc private func appleSignInTapped() {
        showLoading(message: "Connecting with Apple")

        Task {
            do {
                let result = try await AppleSignInManager.shared.signIn(presentingFrom: self)

                try await completeSignIn(userId: result.supabaseUserId)

                // Apple hands the name over exactly once, on first authorization.
                if let name = result.fullName {
                    await AppleSignInManager.shared.persistFirstAuthorizationName(
                        name, userId: result.supabaseUserId)
                }

                // Lets account deletion revoke the Apple grant later (Phase 3).
                if let code = result.authorizationCode {
                    await AccountDeletionService.shared.registerAppleAuthorizationCode(code)
                }

                await MainActor.run {
                    self.hideLoading()
                    self.performLoginTransition()
                }

            } catch AppleSignInManager.AppleSignInError.cancelled,
                    AppleSignInManager.AppleSignInError.alreadyInProgress {
                // Backing out of the Apple sheet is a choice, not an error, and
                // a double-tap that lost the race isn't one either.
                await MainActor.run { self.hideLoading() }

            } catch {
                await MainActor.run {
                    self.hideLoading()
                    self.showAlert(title: "Sign in with Apple Failed",
                                   message: error.localizedDescription)
                }
            }
        }
    }

    @IBAction func loginButtonTapped(_ sender: UIButton) {
        view.endEditing(true)
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

                try await completeSignIn(userId: userId)

                await MainActor.run {
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
                try await PasswordRecovery.sendResetEmail(to: email)
                DispatchQueue.main.async {
                    self.showAlert(
                        title: "Email Sent",
                        message: "Check your inbox and tap the link — it opens Spasht so you can set a new password."
                    )
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

        showLoading(message: "Connecting with Google")

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

                try await completeSignIn(userId: userId)

                await MainActor.run {
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

        let executeTransition = {
            if AppState.isOnboardingCompleted {
                let storyboard = UIStoryboard(name: "Home", bundle: nil)
                let homeVC = storyboard.instantiateViewController(withIdentifier: "HomeVC")

                if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate,
                   let window = sceneDelegate.window {

                    window.backgroundColor = .systemBackground

                    UIView.animate(
                        withDuration: 0.3,
                        animations: {
                            window.rootViewController?.view.alpha = 0
                        },
                        completion: { _ in
                            homeVC.view.alpha = 0
                            window.rootViewController = homeVC

                            UIView.animate(withDuration: 0.3) {
                                homeVC.view.alpha = 1
                            }
                        }
                    )
                }
            } else {
                let storyboard = UIStoryboard(name: "Onboarding", bundle: nil)
                let onboardingVC = storyboard.instantiateViewController(withIdentifier: "PhonemesSelectionViewController")

                if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate,
                   let window = sceneDelegate.window {

                    window.backgroundColor = .systemBackground

                    UIView.animate(
                        withDuration: 0.3,
                        animations: {
                            window.rootViewController?.view.alpha = 0
                        },
                        completion: { _ in
                            onboardingVC.view.alpha = 0
                            window.rootViewController = onboardingVC

                            UIView.animate(withDuration: 0.3) {
                                onboardingVC.view.alpha = 1
                            }
                        }
                    )
                }
            }
        }

        if let presenting = self.presentingViewController {
            presenting.dismiss(animated: false) {
                executeTransition()
            }
        } else {
            executeTransition()
        }
    }

    func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
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

    @IBAction func switchToSignupButtonTapped(_ sender: UIButton) {
        // Fat-finger fix applied on first tap if not already set
        applyButtonInsetsIfNeeded(to: sender, top: 12, leading: 8, bottom: 12, trailing: 8)
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
