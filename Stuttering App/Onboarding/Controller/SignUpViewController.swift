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
    @IBOutlet weak var continueAsGuest: UIButton!
    
    // NEW OUTLET: Connect this to your button in Storyboard
    @IBOutlet weak var passwordToggleButton: UIButton!
    
    private let client = SupabaseManager.shared.client
    var onSwitchToSignin: (() -> Void)?
    private var loadingOverlay: UIView?

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
                
                if SupabaseManager.shared.currentUser == nil {
                    try await client.auth.signIn(email: email, password: password)
                }
                
                let userId = authResponse.user.id.uuidString
                SessionManager.shared.startAccountSession(userId: userId)
                LogManager.shared.initializeUserIfNeeded()
                
                if let userId = LogManager.shared.getCurrentUserId() {
                    LogManager.shared.migrateGuestData(to: userId)
                    var profile = LogManager.shared.getProfile(userId: userId) ?? UserProfile(id: userId, isOnboardingCompleted: false)
                    profile.firstName = name
                    LogManager.shared.saveProfile(profile)
                    
                    SupabaseSyncManager.shared.pushAllLocalDataToCloud { _ in }
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
        guard let presentingVC = self.presentingViewController else { return }
        self.dismiss(animated: true) {
            let storyboard = UIStoryboard(name: "Onboarding", bundle: nil)
            let nextModalVC = storyboard.instantiateViewController(withIdentifier: "LoginViewController")
            nextModalVC.modalPresentationStyle = .pageSheet
            if let sheet = nextModalVC.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
            }
            presentingVC.present(nextModalVC, animated: true)
        }
    }
    
    // MARK: - Helpers & Navigation (Existing)
    
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
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                _ = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
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
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    @objc private func googleSignInTapped() {
        let rawNonce = randomNonceString()
        let hashedNonce = sha256(rawNonce)
        showLoading()
        Task {
            do {
                let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: self, hint: nil, additionalScopes: nil, nonce: hashedNonce)
                let user = result.user
                guard let idToken = user.idToken?.tokenString else {
                    self.hideLoading()
                    showAlert(message: "Failed to get ID token")
                    return
                }
                let accessToken = user.accessToken.tokenString
                _ = try await client.auth.signInWithIdToken(credentials: .init(provider: .google, idToken: idToken, accessToken: accessToken, nonce: rawNonce))
                
                guard let supabaseUser = SupabaseManager.shared.currentUser else { return }
                let userId = supabaseUser.id.uuidString
                SessionManager.shared.startAccountSession(userId: userId)
                LogManager.shared.initializeUserIfNeeded()
                
                if let userId = LogManager.shared.getCurrentUserId() {
                    LogManager.shared.migrateGuestData(to: userId)
                    var profile = LogManager.shared.getProfile(userId: userId) ?? UserProfile(id: userId, isOnboardingCompleted: false)
                    if let displayName = result.user.profile?.name { profile.firstName = displayName }
                    LogManager.shared.saveProfile(profile)
                    SupabaseSyncManager.shared.pushAllLocalDataToCloud { _ in }
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
            SessionManager.shared.startGuestSession()
            LogManager.shared.initializeGuestUser()
        }
    }
}
