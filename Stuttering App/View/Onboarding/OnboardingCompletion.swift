//
//  OnboardingCompletion.swift
//  Spasht
//
//  The one place onboarding is marked finished.
//
//  It used to live inline in LastOnboardingViewController's Get Started button,
//  which made the speech test the only way out of onboarding. A user who
//  declined the microphone or speech recognition had no way forward — and
//  because onboarding runs after sign-up, an account holder in that state could
//  not even reach Delete Account (Guidelines 5.1.1(iv) and 5.1.1(v)). The skip
//  path in OnboardingInstructionsViewController and TestViewController now calls
//  this too, so both exits finish onboarding identically.
//

import UIKit

enum OnboardingCompletion {

    /// Marks onboarding complete, syncs the profile, and swaps in Home.
    ///
    /// Safe to call with or without a speech-test result: the phoneme choices
    /// were saved on their own screen, and Home's daily tasks are built from
    /// those, not from the test.
    static func finish(from viewController: UIViewController) {
        if !SessionManager.shared.isAccountMode {
            SessionManager.shared.startGuestSession()
        }

        AppState.isOnboardingCompleted = true
        AppState.isLoginCompleted = true
        AwardsManager.shared.updateAwardProgress(id: "nm_001", progress: 1.0, newStatus: "1 of 1 completed")

        guard let currentUserId = LogManager.shared.getCurrentUserId() else { return }
        var profile = LogManager.shared.getProfile(userId: currentUserId)
            ?? UserProfile(id: currentUserId, isOnboardingCompleted: false)
        profile.isOnboardingCompleted = true
        LogManager.shared.saveProfile(profile)

        if SessionManager.shared.isAccountMode {
            SupabaseSyncManager.shared.pushProfile(profile)
        }

        LogicMaker().checkForNewDay(isFromLogin: true)

        // Don't ask for notifications here. Home asks once it appears, *after*
        // the medical disclaimer and the AI-consent prompt. Asking from here
        // put the system alert on top of the disclaimer, so a new user's first
        // sight of Home was a notification prompt with the 1.4.1 disclaimer
        // hidden behind it. Clearing the flag is what lets Home ask.
        UserDefaults.standard.removeObject(forKey: "hasRequestedNotificationPermission")

        let storyboard = UIStoryboard(name: "Home", bundle: nil)
        let homeVC = storyboard.instantiateViewController(withIdentifier: "HomeVC")

        guard let window = viewController.view.window else { return }
        window.backgroundColor = .systemBackground

        UIView.animate(
            withDuration: 0.3,
            animations: {
                window.rootViewController?.view.alpha = 0
            },
            completion: { _ in
                homeVC.view.alpha = 0
                window.rootViewController = homeVC
                UIView.animate(withDuration: 0.3) { homeVC.view.alpha = 1 }
            }
        )
    }

    /// The skip action offered wherever the speech test can't run.
    ///
    /// Read Aloud asks for the microphone again the first time it's used, so
    /// skipping here loses nothing permanent.
    static func skipTestAction(from viewController: UIViewController) -> UIAlertAction {
        UIAlertAction(title: "Skip the Test", style: .default) { [weak viewController] _ in
            guard let viewController else { return }
            finish(from: viewController)
        }
    }

    static let skipExplanation =
        "You can skip the test and start using Spasht now. Read Aloud will ask for access again when you use it."
}
