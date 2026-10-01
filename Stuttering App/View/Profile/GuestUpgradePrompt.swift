//
//  GuestUpgradePrompt.swift
//  Spasht
//
//  Explains why a feature needs an account, and opens sign-up.
//
//  Used by the AI features, which are account-only (decision D6). Restricting
//  them is what lets the `groq-chat` Edge Function require a real user token
//  rather than being an open proxy, and it keeps guest mode genuinely
//  local-only — nothing a guest does leaves the device.
//

import UIKit

enum GuestUpgradePrompt {

    /// Shows the explanation, then the sign-up sheet if the user wants it.
    ///
    /// `onDecline` runs when they back out, so the caller can send them
    /// somewhere else — a feature they can't use shouldn't be left on screen.
    static func present(from presenter: UIViewController,
                        featureName: String,
                        reason: String,
                        onDecline: @escaping () -> Void) {
        let alert = UIAlertController(
            title: "\(featureName) needs an account",
            message: reason,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Not Now", style: .cancel) { _ in
            onDecline()
        })
        alert.addAction(UIAlertAction(title: "Create Account", style: .default) { _ in
            presentSignUp(from: presenter, onDismiss: onDecline)
        })
        presenter.present(alert, animated: true)
    }

    private static func presentSignUp(from presenter: UIViewController,
                                      onDismiss: @escaping () -> Void) {
        // If they finish signing up the app swaps the root view controller, so
        // `onDismiss` never runs. It only matters when they close the sheet
        // still a guest, which is the case the caller needs to handle.
        AuthScreens.present(.signUp, from: presenter, onDismiss: onDismiss)
    }
}
