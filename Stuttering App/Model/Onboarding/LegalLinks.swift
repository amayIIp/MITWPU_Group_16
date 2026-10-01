//
//  LegalLinks.swift
//  Spasht
//
//  One place for the legal URLs and the medical disclaimer.
//
//  Guideline 5.1.1(i) expects a user who is handing over personal data to be
//  able to reach the privacy policy, and App Store Connect requires the policy
//  URL as metadata. Guideline 1.4.1 holds anything that could read as a medical
//  claim to a higher bar, which is what the disclaimer is for.
//

import UIKit
import SafariServices

enum LegalLinks {

    // All three live on one page, each at its own anchor. Verified reachable and
    // the anchors present, 1 Oct 2026.
    //
    // The privacy policy URL also has to go in App Store Connect — keep the two
    // in step, because a reviewer compares them.
    static let privacyPolicy = URL(string: "https://spashtapp.netlify.app/#privacy-policy")!
    static let termsOfUse    = URL(string: "https://spashtapp.netlify.app/#terms")!

    /// Support is a web page, not a mailto. Guideline 5.1.1(v) only forbids
    /// *requiring* customer service to delete an account — which the in-app
    /// Delete Account flow already avoids — so a support page is fine, and it
    /// works on a device with no mail account configured, which a mailto link
    /// does not.
    static let supportURL = URL(string: "https://spashtapp.netlify.app/#support")!

    /// False would mean the URLs above aren't published yet, and every legal
    /// link would say so instead of opening a 404. They are live now, so this
    /// is on. Set it back to false if the site ever comes down.
    static let isConfigured = true

    /// The disclaimer. Spasht reports fluency measurements produced by
    /// automated speech analysis, which is imperfect; presenting those without
    /// saying what they are not is the part that risks 1.4.1.
    static let medicalDisclaimer = """
        Spasht is a practice tool, not a medical device. It does not diagnose or \
        treat stuttering, and its measurements are estimates produced by software. \
        For assessment or therapy, please see a qualified speech-language pathologist.
        """

    // MARK: - Presentation

    static func open(_ url: URL, from presenter: UIViewController) {
        guard isConfigured else {
            let alert = UIAlertController(
                title: "Not Available Yet",
                message: "This document isn't published yet. Please try again after the next update.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            presenter.present(alert, animated: true)
            return
        }
        let safari = SFSafariViewController(url: url)
        presenter.present(safari, animated: true)
    }

    /// Support opens in the same in-app browser as the other two.
    ///
    /// It used to build a `mailto:` from the support address and hand it to
    /// `UIApplication.open`. That had two problems once support became a web
    /// page: the URL came out as `mailto:https://…`, and a mailto bounces the
    /// user out to Mail — which does nothing at all on a device with no mail
    /// account set up.
    static func openSupport(from presenter: UIViewController) {
        open(supportURL, from: presenter)
    }

    // MARK: - Reusable views

    /// A compact "Privacy Policy · Terms · Support" row.
    ///
    /// Built in code so it can be dropped into both the settings footer and the
    /// sign-up sheet without duplicating it in two storyboards.
    static func makeLinkRow(target: Any,
                            privacyAction: Selector,
                            termsAction: Selector,
                            supportAction: Selector) -> UIStackView {
        func link(_ title: String, _ action: Selector) -> UIButton {
            var config = UIButton.Configuration.plain()
            config.title = title
            config.baseForegroundColor = .secondaryLabel
            config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 6, bottom: 8, trailing: 6)
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var out = incoming
                out.font = .preferredFont(forTextStyle: .footnote)
                return out
            }
            let button = UIButton(configuration: config)
            button.addTarget(target, action: action, for: .touchUpInside)
            return button
        }

        func dot() -> UILabel {
            let label = UILabel()
            label.text = "·"
            label.font = .preferredFont(forTextStyle: .footnote)
            label.textColor = .tertiaryLabel
            return label
        }

        // Everything sits in one flat stack. A nested stack was tried first and
        // does not work: UIStackView has no intrinsic content size, so setting a
        // hugging priority on it has nothing to act on and the parent's `.fill`
        // distribution stretched it anyway — which showed up on screen as
        // "Privacy Policy ·        Terms · Support".
        //
        // Flat, the links hug their text at required priority and the two
        // spacers are the only things that can grow, so all the slack goes to
        // the ends and the row stays centred. When the row is laid out at its
        // fitted width instead (the settings footer) the spacers collapse.
        let leading = UIView()
        let trailing = UIView()
        for spacer in [leading, trailing] {
            spacer.setContentHuggingPriority(UILayoutPriority(1), for: .horizontal)
            spacer.setContentCompressionResistancePriority(UILayoutPriority(1), for: .horizontal)
        }

        let links: [UIView] = [
            link("Privacy Policy", privacyAction),
            dot(),
            link("Terms", termsAction),
            dot(),
            link("Support", supportAction)
        ]
        for view in links {
            view.setContentHuggingPriority(.required, for: .horizontal)
            view.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        }

        let stack = UIStackView(arrangedSubviews: [leading] + links + [trailing])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .fill
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        leading.widthAnchor.constraint(equalTo: trailing.widthAnchor).isActive = true
        return stack
    }
}
