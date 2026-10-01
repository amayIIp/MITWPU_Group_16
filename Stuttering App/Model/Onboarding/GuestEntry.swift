//
//  GuestEntry.swift
//  Spasht
//
//  The one route into guest mode, shared by the sign-in and sign-up sheets.
//
//  It used to be a storyboard segue on the sign-in screen only — the sign-up
//  screen's "Continue as guest" button had no action and no segue at all, so
//  the button did nothing. The segue also presented full-screen *over* the
//  still-presented sheet, which left the sheet stranded underneath and meant
//  backing out of the name screen returned to a sign-in form the user had
//  already left.
//

import UIKit

enum GuestEntry {

    /// Dismisses the auth sheet `presenter` lives in, then starts the guest
    /// onboarding from whatever presented it, so backing out lands on the
    /// landing page rather than on a stale sheet.
    static func start(from presenter: UIViewController) {
        let storyboard = UIStoryboard(name: "Onboarding", bundle: nil)
        let nameNav = storyboard.instantiateViewController(
            withIdentifier: "OnboardingNameNavigationController")
        nameNav.modalPresentationStyle = .fullScreen

        if let presenting = presenter.presentingViewController {
            presenter.dismiss(animated: false) {
                presenting.present(nameNav, animated: true)
            }
        } else {
            presenter.present(nameNav, animated: true)
        }
    }
}
