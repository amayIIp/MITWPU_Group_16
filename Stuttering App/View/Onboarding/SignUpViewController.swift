import UIKit
import Supabase
import GoogleSignIn
import AuthenticationServices

class SignUpViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var signUpButton: UIButton!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var googleSignIn: UIButton!
    @IBOutlet weak var continueAsGuest: UIButton!

    // NEW OUTLET: Connect this to your button in Storyboard
    @IBOutlet weak var passwordToggleButton: UIButton!

    private let client = SupabaseManager.shared.client
    var onSwitchToSignin: (() -> Void)?
    private var loadingOverlay: WaveLoadingOverlay?
    private var keyboardAvoider: KeyboardAvoider?

    override func viewDidLoad() {
        super.viewDidLoad()
        keyboardAvoider = KeyboardAvoider(view: view)
        setupUI()
        setupTextField()
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
        } else {
            // The storyboard has never had an action on this button, so until now
            // it did nothing at all — the guest path only worked from sign-in.
            continueAsGuest?.addTarget(self,
                                       action: #selector(continueAsGuestTapped),
                                       for: .touchUpInside)
        }

        installLegalLinks()

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

    @objc private func continueAsGuestTapped() {
        GuestEntry.start(from: self)
    }

    // MARK: - Email confirmation

    /// Shown when Supabase has email confirmation switched on, so `signUp`
    /// returns without a session.
    ///
    /// Previously this was a bare "check your email" alert that dropped the user
    /// back on the same form with no next step and no way to ask for another
    /// email — a dead end if the first one never arrived, which is exactly the
    /// situation a reviewer creating a test account can land in.
    private func presentConfirmationPending(email: String) {
        let alert = UIAlertController(
            title: "Confirm Your Email",
            message: "We've sent a confirmation link to \(email). Tap it, then sign in.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Resend Email", style: .default) { _ in
            self.resendConfirmation(to: email)
        })
        alert.addAction(UIAlertAction(title: "Go to Sign In", style: .default) { _ in
            self.switchToSignIn()
        })
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alert, animated: true)
    }

    private func resendConfirmation(to email: String) {
        Task {
            do {
                try await client.auth.resend(email: email, type: .signup)
                await MainActor.run {
                    self.showAlert(message: "Sent again. Check your inbox, and your spam folder.")
                }
            } catch {
                await MainActor.run {
                    self.showAlert(message: error.localizedDescription)
                }
            }
        }
    }

    /// Same transition as the "Sign In" link at the bottom of the form.
    private func switchToSignIn() {
        guard let presentingVC = self.presentingViewController else { return }
        self.dismiss(animated: true) {
            let storyboard = UIStoryboard(name: "Onboarding", bundle: nil)
            let loginVC = storyboard.instantiateViewController(withIdentifier: "LoginViewController")
            let navController = UINavigationController(rootViewController: loginVC)
            navController.navigationBar.prefersLargeTitles = true
            navController.modalPresentationStyle = .pageSheet
            if let sheet = navController.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
            }
            presentingVC.present(navController, animated: true)
        }
    }

    // MARK: - Legal links (Guideline 5.1.1(i))

    /// Adds the privacy/terms/support row to the sign-up sheet.
    ///
    /// This is the screen where a user actually hands over personal data, so it
    /// is where the policy most needs to be reachable. It is also the only
    /// screen guests can get to from the home screen, which makes it their one
    /// route to the privacy policy.
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

    // MARK: - Shared post-registration

    /// Everything that has to happen after a successful registration, whichever
    /// provider it came from. Unlike the login path this *pushes* local data up
    /// rather than pulling it down — a new account starts from whatever the
    /// user built in guest mode.
    ///
    /// `displayName` is applied only when the profile doesn't already have one,
    /// so a provider that gives us nothing can't blank out a real name.
    private func completeSignUp(userId: String, displayName: String?) async throws {
        SessionManager.shared.startAccountSession(userId: userId)
        LogManager.shared.initializeUserIfNeeded()

        LogManager.shared.migrateGuestData(to: userId)

        var profile = LogManager.shared.getProfile(userId: userId)
            ?? UserProfile(id: userId, isOnboardingCompleted: false)
        if let displayName, !displayName.isEmpty,
           profile.firstName?.trimmingCharacters(in: .whitespaces).isEmpty ?? true {
            profile.firstName = displayName
        }
        LogManager.shared.saveProfile(profile)

        // ISSUE-09 fix: await the push so we only navigate after data
        // is safely in the cloud (no navigation-before-push data loss).
        try await SupabaseSyncManager.shared.pushAllLocalDataToCloud()

        AppState.isLoginCompleted = true
    }

    @objc private func appleSignInTapped() {
        showLoading(message: "Connecting with Apple")

        Task {
            do {
                let result = try await AppleSignInManager.shared.signIn(presentingFrom: self)

                try await completeSignUp(userId: result.supabaseUserId,
                                         displayName: result.fullName)

                // Apple hands the name over exactly once, on first authorization.
                // completeSignUp has already stored it locally; this also puts it
                // in Supabase user metadata.
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
                    self.handleNavigationLogic()
                }

            } catch AppleSignInManager.AppleSignInError.cancelled,
                    AppleSignInManager.AppleSignInError.alreadyInProgress {
                // Backing out of the Apple sheet is a choice, not an error, and
                // a double-tap that lost the race isn't one either.
                await MainActor.run { self.hideLoading() }

            } catch {
                await MainActor.run {
                    self.hideLoading()
                    self.showAlert(message: error.localizedDescription)
                }
            }
        }
    }

    @IBAction func signUpButtonTapped(_ sender: UIButton) {
        view.endEditing(true)
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

        signUpButton.isEnabled = false
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
                        self.signUpButton.isEnabled = true
                        self.presentConfirmationPending(email: email)
                    }
                    return
                }

                // ISSUE-11 fix: use the userId from authResponse directly.
                // Do NOT re-fetch from LogManager which may still hold the guest ID.
                let userId = authResponse.user.id.uuidString

                try await completeSignUp(userId: userId, displayName: name)

                await MainActor.run {
                    self.hideLoading()
                    self.signUpButton.isEnabled = true
                    self.handleNavigationLogic()
                }
            } catch {
                await MainActor.run {
                    self.hideLoading()
                    self.signUpButton.isEnabled = true
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
        let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
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

                try await completeSignUp(userId: userId,
                                         displayName: result.user.profile?.name)

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
        let executeTransition = {
            if AppState.isOnboardingCompleted {
                // Re-schedule notifications for returning users (safe to call multiple times)
                NotificationManager.shared.scheduleNotifications()
                if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate,
                   let window = sceneDelegate.window {
                    let storyboard = UIStoryboard(name: "Home", bundle: nil)
                    window.rootViewController = storyboard.instantiateViewController(withIdentifier: "HomeVC")
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
                            UIView.animate(withDuration: 0.3) { onboardingVC.view.alpha = 1 }
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

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.destination is OnboardingNameViewController {
            // startGuestSession() is now called in OnboardingNameViewController
            // only after the user successfully enters their name.
        }
    }
}
