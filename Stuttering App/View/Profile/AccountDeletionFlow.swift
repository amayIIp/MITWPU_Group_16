//
//  AccountDeletionFlow.swift
//  Spasht
//
//  The user-facing half of Guideline 5.1.1(v): confirm, delete, confirm again.
//
//  Account holders only, reached from Settings. Guest mode has no account and no
//  cloud footprint — its data lives entirely in the app container, which iOS
//  deletes with the app — so there is nothing for a guest-facing delete button
//  to do that uninstalling does not already do.
//

import UIKit

enum AccountDeletionFlow {

    /// Presents the full confirm → delete → confirm sequence from `presenter`.
    ///
    /// `onDeleted` runs after the user dismisses the success alert, and is where
    /// the caller sends them back to the landing screen.
    static func start(from presenter: UIViewController, onDeleted: @escaping () -> Void) {
        let alert = UIAlertController(
            title: "Delete Account?",
            message: "This permanently deletes your account and everything in it — your practice history, recordings, streaks, and awards, on this device and in the cloud. This cannot be undone.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            confirm(from: presenter, onDeleted: onDeleted)
        })
        presenter.present(alert, animated: true)
    }

    /// Second, deliberately slower confirmation. Apple allows confirmation steps
    /// to prevent accidents; what it forbids is making deletion *hard*. This
    /// stops at two taps plus a typed word — no email, no phone call, nothing
    /// that would count as a customer-service flow.
    private static func confirm(from presenter: UIViewController,
                                onDeleted: @escaping () -> Void) {
        let confirm = UIAlertController(
            title: "Are you sure?",
            message: "Type DELETE to confirm.",
            preferredStyle: .alert
        )
        confirm.addTextField { textField in
            textField.autocapitalizationType = .allCharacters
            textField.autocorrectionType = .no
        }
        confirm.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        confirm.addAction(UIAlertAction(title: "Delete Permanently", style: .destructive) { [weak confirm] _ in
            let typed = confirm?.textFields?.first?.text?
                .trimmingCharacters(in: .whitespaces)
                .uppercased()
            guard typed == "DELETE" else {
                simpleAlert(from: presenter,
                            title: "Not Deleted",
                            message: "Type DELETE to confirm.")
                return
            }
            perform(from: presenter, onDeleted: onDeleted)
        })
        presenter.present(confirm, animated: true)
    }

    private static func perform(from presenter: UIViewController,
                                onDeleted: @escaping () -> Void) {
        let overlay = WaveLoadingOverlay.showOnWindow(message: "Deleting your account")

        Task { @MainActor in
            do {
                try await AccountDeletionService.shared.deleteAccount()
                overlay.dismiss()
                confirmDeleted(from: presenter, onDeleted: onDeleted)
            } catch {
                overlay.dismiss()
                simpleAlert(from: presenter,
                            title: "Couldn't Delete Account",
                            message: error.localizedDescription)
            }
        }
    }

    /// Apple asks for an explicit confirmation that deletion has completed.
    private static func confirmDeleted(from presenter: UIViewController,
                                       onDeleted: @escaping () -> Void) {
        let done = UIAlertController(
            title: "Account Deleted",
            message: "Your account and all of its data have been permanently deleted.",
            preferredStyle: .alert
        )
        done.addAction(UIAlertAction(title: "OK", style: .default) { _ in onDeleted() })
        presenter.present(done, animated: true)
    }

    private static func simpleAlert(from presenter: UIViewController,
                                    title: String,
                                    message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        presenter.present(alert, animated: true)
    }

    // MARK: - Shared teardown

    /// Returns the app to the landing screen after a deletion, from wherever the
    /// flow was presented. Dismisses the presenting sheet first so the window
    /// swap isn't happening underneath a modal.
    static func returnToLanding(from presenter: UIViewController) {
        let swap = {
            let storyboard = UIStoryboard(name: "Onboarding", bundle: nil)
            guard let landingNav = storyboard.instantiateViewController(withIdentifier: "LandingNav") as? UINavigationController,
                  let window = UIApplication.shared.connectedScenes
                      .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
                      .first else { return }

            UIView.transition(with: window, duration: 0.5, options: .transitionCrossDissolve) {
                window.rootViewController = landingNav
            }
        }

        if presenter.presentingViewController != nil {
            presenter.dismiss(animated: true, completion: swap)
        } else {
            swap()
        }
    }

    /// The destructive button, as it appears in Settings.
    static func makeButton(target: Any, action: Selector) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.title = "Delete Account"
        config.baseForegroundColor = .systemRed
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)

        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(target, action: action, for: .touchUpInside)
        return button
    }
}
