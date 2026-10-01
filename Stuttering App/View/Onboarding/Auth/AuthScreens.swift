//
//  AuthScreens.swift
//  Spasht
//
//  The bridge between the SwiftUI auth screens and the storyboard app around
//  them.
//
//  Every place that used to reach into the Onboarding storyboard for
//  "LoginViewController" or "SignUpViewController" goes through `AuthScreens`
//  instead, so those two scenes can be deleted without hunting down call sites.
//

import SwiftUI
import UIKit

// MARK: - Hosting

/// Hosts `AuthFlowView` and hands it the view controller that Google, Apple,
/// Safari and the guest hand-off all need in order to present anything.
final class AuthHostingController: UIHostingController<AuthFlowView> {

    private let model: AuthModel

    init(mode: AuthModel.Mode) {
        let model = AuthModel(mode: mode)
        self.model = model
        super.init(rootView: AuthFlowView(model: model))
        model.host = self
        // The screen draws its own title and close button.
        navigationItem.largeTitleDisplayMode = .never
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("AuthHostingController is created in code, not from a storyboard.")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Leave the bar as the rest of the app expects to find it.
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
}

// MARK: - Entry points

enum AuthScreens {

    /// A bare controller, for callers that do their own presenting or pushing.
    static func make(_ mode: AuthModel.Mode) -> UIViewController {
        AuthHostingController(mode: mode)
    }

    /// Presents the screen as the page sheet the rest of the app uses.
    ///
    /// `onDismiss` fires only when the sheet is closed without authenticating —
    /// a success swaps the root view controller, and the sheet goes with it.
    @discardableResult
    static func present(_ mode: AuthModel.Mode,
                        from presenter: UIViewController,
                        onDismiss: (() -> Void)? = nil) -> UIViewController {
        let controller = AuthHostingController(mode: mode)
        controller.modalPresentationStyle = .pageSheet
        if let sheet = controller.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }

        presenter.present(controller, animated: true)

        if let onDismiss {
            controller.presentationController?.delegate =
                AuthSheetDismissObserver.install(on: controller, onDismiss: onDismiss)
        }
        return controller
    }

    /// Pushes the screen onto an existing navigation stack.
    static func push(_ mode: AuthModel.Mode, onto navigationController: UINavigationController) {
        navigationController.pushViewController(AuthHostingController(mode: mode), animated: true)
    }
}

// MARK: - Post-authentication navigation

/// Where the app goes once someone is signed in.
///
/// Shared by both screens and all four providers, because getting this wrong in
/// one path only — navigating before the sync finished, or landing on the home
/// screen with onboarding half-done — is exactly the kind of bug that used to
/// come from each provider having its own copy.
enum AuthNavigator {

    @MainActor
    static func finish(from presenter: UIViewController?) {
        AppState.isLoginCompleted = true

        let swapRoot = {
            guard let window = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
                .first ?? (UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate)?.window
            else { return }

            window.backgroundColor = .systemBackground

            let destination: UIViewController
            if AppState.isOnboardingCompleted {
                // Safe to call repeatedly; returning users need them rescheduled.
                NotificationManager.shared.scheduleNotifications()
                destination = UIStoryboard(name: "Home", bundle: nil)
                    .instantiateViewController(withIdentifier: "HomeVC")
            } else {
                destination = UIStoryboard(name: "Onboarding", bundle: nil)
                    .instantiateViewController(withIdentifier: "PhonemesSelectionViewController")
            }

            UIView.animate(withDuration: 0.3, animations: {
                window.rootViewController?.view.alpha = 0
            }, completion: { _ in
                destination.view.alpha = 0
                window.rootViewController = destination
                UIView.animate(withDuration: 0.3) { destination.view.alpha = 1 }
            })
        }

        // Swapping the root out from under a presented sheet leaves the sheet
        // stranded on screen, so it goes first.
        if let presenting = presenter?.presentingViewController {
            presenting.dismiss(animated: false, completion: swapRoot)
        } else {
            swapRoot()
        }
    }
}

// MARK: - Dismissal observer

/// Tells the caller when the sheet was closed without authenticating.
///
/// Keeps a strong reference to itself until the sheet goes away, because
/// `presentationController.delegate` is weak.
private final class AuthSheetDismissObserver: NSObject, UIAdaptivePresentationControllerDelegate {

    private var retain: AuthSheetDismissObserver?
    private let onDismiss: () -> Void

    private init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    static func install(on controller: UIViewController,
                        onDismiss: @escaping () -> Void) -> AuthSheetDismissObserver {
        let observer = AuthSheetDismissObserver(onDismiss: onDismiss)
        observer.retain = observer
        return observer
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        // A successful sign-in swaps the root view controller and takes the
        // sheet with it, but a provider sheet can also close *after* the account
        // exists. Callers only care about the still-no-account case.
        if !SessionManager.shared.isAccountMode { onDismiss() }
        retain = nil
    }
}
