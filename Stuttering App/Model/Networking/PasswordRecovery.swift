//
//  PasswordRecovery.swift
//  Spasht
//
//  Closes the loop on "Forgot Password".
//
//  Previously `resetPasswordForEmail` was called with no redirect, so the link
//  in the email opened a Supabase web page and the user had no route back into
//  the app — they could request a reset and still never change their password.
//  App Review does test forgot-password.
//
//  The flow now: request → email → tap link → `spasht://password-reset` opens
//  the app → the link is exchanged for a recovery session → the user sets a new
//  password without leaving Spasht.
//

import Foundation
import Supabase
import UIKit

enum PasswordRecovery {

    /// Where Supabase sends the user back to. Must also be listed under
    /// Authentication → URL Configuration → Redirect URLs in the Supabase
    /// dashboard, or Supabase refuses to use it.
    static let redirectURL = URL(string: "spasht://password-reset")!

    /// True when `url` is the recovery link coming back into the app.
    static func isRecoveryLink(_ url: URL) -> Bool {
        guard url.scheme == "spasht" else { return false }
        if url.host == "password-reset" { return true }
        // Supabase puts type=recovery in the fragment on some configurations.
        return (url.fragment ?? "").contains("type=recovery")
            || (url.query ?? "").contains("type=recovery")
    }

    /// Sends the reset email, pointed back at the app.
    static func sendResetEmail(to email: String) async throws {
        try await SupabaseManager.shared.client.auth.resetPasswordForEmail(
            email, redirectTo: redirectURL
        )
    }

    /// Handles the tapped link: exchanges it for a recovery session, then asks
    /// for the new password.
    @MainActor
    static func handle(_ url: URL, from presenter: UIViewController?) {
        guard let presenter else { return }

        Task {
            do {
                try await SupabaseManager.shared.client.auth.session(from: url)
                promptForNewPassword(from: presenter)
            } catch {
                alert(from: presenter,
                      title: "Link Expired",
                      message: "That reset link is no longer valid. Request a new one from the sign-in screen.")
            }
        }
    }

    // MARK: - New password

    @MainActor
    private static func promptForNewPassword(from presenter: UIViewController) {
        let sheet = UIAlertController(
            title: "Set a New Password",
            message: "Choose a password of at least 8 characters.",
            preferredStyle: .alert
        )
        sheet.addTextField { field in
            field.placeholder = "New password"
            field.isSecureTextEntry = true
            field.textContentType = .newPassword
        }
        sheet.addTextField { field in
            field.placeholder = "Confirm password"
            field.isSecureTextEntry = true
            field.textContentType = .newPassword
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.addAction(UIAlertAction(title: "Save", style: .default) { [weak sheet] _ in
            let new = sheet?.textFields?.first?.text ?? ""
            let confirm = sheet?.textFields?.last?.text ?? ""

            guard new.count >= 8 else {
                retry(from: presenter, message: "That password is too short. Use at least 8 characters.")
                return
            }
            guard new == confirm else {
                retry(from: presenter, message: "Those passwords don't match.")
                return
            }
            apply(newPassword: new, from: presenter)
        })
        presenter.present(sheet, animated: true)
    }

    @MainActor
    private static func retry(from presenter: UIViewController, message: String) {
        let alert = UIAlertController(title: "Try Again", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            promptForNewPassword(from: presenter)
        })
        presenter.present(alert, animated: true)
    }

    @MainActor
    private static func apply(newPassword: String, from presenter: UIViewController) {
        Task {
            do {
                _ = try await SupabaseManager.shared.client.auth.update(
                    user: UserAttributes(password: newPassword)
                )
                alert(from: presenter,
                      title: "Password Updated",
                      message: "You can now sign in with your new password.")
            } catch {
                alert(from: presenter,
                      title: "Couldn't Update Password",
                      message: error.localizedDescription)
            }
        }
    }

    @MainActor
    private static func alert(from presenter: UIViewController, title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        presenter.present(alert, animated: true)
    }
}
