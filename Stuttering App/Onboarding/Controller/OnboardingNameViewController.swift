//
//  OnboardingNameViewController.swift
//  Spasht
//
//  Created by SDC-USER on 18/11/25.
//

import UIKit

class OnboardingNameViewController: UIViewController, UITextFieldDelegate, UIGestureRecognizerDelegate {

    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var continueButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupBackButton()
        setupTextField()
        setupDismissKeyboardGesture()
        setupAppleNativeUI()
    }

    // MARK: - Native Apple Polish
    private func setupAppleNativeUI() {
        // Auto-focus the text field so the keyboard is ready immediately
        nameTextField.becomeFirstResponder()

        // Setup dynamic button state based on text input
        updateContinueButtonState()
        nameTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
    }

    @objc private func textFieldDidChange() {
        updateContinueButtonState()
    }

    private func updateContinueButtonState() {
        let text = nameTextField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let isValid = !text.isEmpty

        continueButton.isEnabled = isValid
        // Visually fade the button if it's disabled, native Apple style
        UIView.animate(withDuration: 0.2) {
            self.continueButton.alpha = isValid ? 1.0 : 0.5
        }
    }

    // MARK: - Navigation Setup
    private func setupBackButton() {
        let backImage = UIImage(systemName: "chevron.left")
        let backButton = UIBarButtonItem(image: backImage, style: .plain, target: self, action: #selector(backButtonTapped))
        self.navigationItem.leftBarButtonItem = backButton
    }

    @objc private func backButtonTapped() {
        Task {
            await SessionManager.shared.endSession()  // cancel the premature guest session
            await MainActor.run {
                self.dismiss(animated: true) {
                    print("🚪 [SESSION] Backed out of guest mode")
                }
            }
        }
    }

    // MARK: - Text Field & Gestures
    func setupTextField() {
        nameTextField.delegate = self
        nameTextField.returnKeyType = .done

        nameTextField.autocorrectionType = .no
        nameTextField.spellCheckingType = .no
        nameTextField.smartDashesType = .no
        nameTextField.smartQuotesType = .no
        nameTextField.smartInsertDeleteType = .no
    }

    func setupDismissKeyboardGesture() {
        let tapGesture = UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing))
        tapGesture.cancelsTouchesInView = false
        tapGesture.delegate = self
        view.addGestureRecognizer(tapGesture)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        // Optional: Trigger continueButtonTapped here if you want "Done" on the keyboard to auto-continue
        return true
    }

    // MARK: - Actions
    @IBAction func continueButtonTapped(_ sender: UIButton) {
        guard let name = nameTextField.text,
              !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            return
        }
        
        SessionManager.shared.startGuestSession()
        
        guard let currentUserId = LogManager.shared.getCurrentUserId() else { return }

        var profile = LogManager.shared.getProfile(userId: currentUserId) ?? UserProfile(id: currentUserId, isOnboardingCompleted: false)
        profile.firstName = name

        LogManager.shared.saveProfile(profile)

        // Add your segue or navigation to the next onboarding screen here
    }

    // MARK: - UIGestureRecognizerDelegate
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.view is UITextField || touch.view is UIButton {
            return false
        }
        return true
    }
}
