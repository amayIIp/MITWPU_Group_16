//
//  AboutViewController.swift
//  Spasht
//
//  The "About Us" row in Settings, which until now led nowhere.
//
//  Built in code rather than in the storyboard: it is a single column of text
//  that has to reflow for Dynamic Type, and laying that out in Interface
//  Builder would mean a dozen hand-tuned constraints that break the moment the
//  copy changes.
//
//  The copy is not marketing. Everything here is either checkable in the app
//  (what it does), repeated verbatim from a document the user can open from the
//  same screen (the privacy summary, the disclaimer), or taken from the
//  project's own README (the team). Guideline 1.4.1 holds anything that reads
//  as a medical claim to a higher bar, so the disclaimer is given its own card
//  rather than being buried in a paragraph.
//

import UIKit

final class AboutViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let column = UIStackView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "About"
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = UIColor(named: "bg") ?? .systemBackground

        setupLayout()
        buildContent()
    }

    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        column.axis = .vertical
        column.spacing = 28
        column.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(column)

        let guide = scrollView.contentLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            column.topAnchor.constraint(equalTo: guide.topAnchor, constant: 24),
            column.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -40),
            column.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 20),
            column.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -20),
            // Pins the column to the readable width; without this a vertical
            // stack inside a scroll view has no width at all.
            column.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor,
                                          constant: -40)
        ])
    }

    // MARK: - Content

    private func buildContent() {
        column.addArrangedSubview(makeHeader())

        column.addArrangedSubview(makeSection(
            title: "What Spasht is",
            card: makeTextCard(
                "Spasht is a practice tool for people who stutter. It listens while "
                + "you read aloud, shows you where your speech caught, and turns that "
                + "into exercises and daily goals you can work through on your own, "
                + "between sessions with a therapist or without one.")))

        column.addArrangedSubview(makeSection(
            title: "What's inside",
            card: makeCard(containing: makeFeatureList())))

        column.addArrangedSubview(makeSection(
            title: "Your privacy",
            card: makeCard(containing: makePrivacyList())))

        column.addArrangedSubview(makeDisclaimerCard())

//        column.addArrangedSubview(makeSection(
//            title: "Who built it",
//            card: makeCard(containing: makeTeamList())))

        column.addArrangedSubview(makeFooter())
    }

    private func makeHeader() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 10

        let wordmark = UIImageView(image: UIImage(named: "3ulzw5ywiitmi6643fo"))
        wordmark.contentMode = .scaleAspectFit
        wordmark.accessibilityLabel = "Spasht"
        wordmark.isAccessibilityElement = true
        wordmark.heightAnchor.constraint(equalToConstant: 56).isActive = true

        let tagline = makeLabel("Fluency starts here.",
                                style: .title3,
                                weight: .semibold,
                                alignment: .center)

        let subtitle = makeLabel("Practice speaking. Build confidence.",
                                 style: .subheadline,
                                 color: .secondaryLabel,
                                 alignment: .center)

        stack.addArrangedSubview(wordmark)
        stack.addArrangedSubview(tagline)
        stack.addArrangedSubview(subtitle)
        stack.setCustomSpacing(16, after: wordmark)
        stack.setCustomSpacing(4, after: tagline)
        return stack
    }

    private func makeFeatureList() -> UIView {
        makeRows([
            ("waveform", "Read Aloud",
             "Your iPhone transcribes as you read and marks the repetitions, "
             + "prolongations and blocks, word by word."),
            ("lungs", "Exercises",
             "Short guided drills — airflow, gentle onset, flexible pacing, "
             + "light contacts and prolongation."),
            ("bubble.left.and.bubble.right", "Conversation",
             "Open-ended speaking practice with a partner that replies out loud, "
             + "for the part reading aloud can't rehearse."),
            ("chart.line.uptrend.xyaxis", "Progress",
             "Daily goals, streaks and awards, and a weekly view of what actually "
             + "changed.")
        ])
    }

    private func makePrivacyList() -> UIView {
        makeRows([
            ("iphone", "Your voice stays on this device",
             "Speech is transcribed on the iPhone itself, and the recording is "
             + "deleted as soon as the session has been analysed."),
            ("sparkles", "AI coaching is opt-in",
             "Nothing is sent to our AI provider unless you turn it on, and you "
             + "can turn it off again in Settings at any time."),
            ("person.crop.circle.badge.questionmark", "Guest mode stays local",
             "Without an account nothing leaves the phone — no sync, no cloud "
             + "storage, no AI."),
            ("trash", "You can delete everything",
             "Deleting your account removes your history from this device and "
             + "from our servers, from inside the app.")
        ])
    }

    private func makeTeamList() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12

        stack.addArrangedSubview(makeLabel(
            "Spasht was built by Group 16 at MIT World Peace University, Pune, "
            + "for educational and clinical research purposes.",
            style: .subheadline,
            color: .secondaryLabel))

        let names = ["Naitik Rathore", "Prathamesh Patil", "Amay Puthiyedath", "Krish Jain"]
        for name in names {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 10
            row.alignment = .firstBaseline

            let dot = UIImageView(image: UIImage(systemName: "person.fill"))
            dot.tintColor = UIColor(named: "ButtonThemeMain") ?? .tintColor
            dot.contentMode = .scaleAspectFit
            dot.setContentHuggingPriority(.required, for: .horizontal)
            dot.widthAnchor.constraint(equalToConstant: 18).isActive = true

            row.addArrangedSubview(dot)
            row.addArrangedSubview(makeLabel(name, style: .body))
            stack.addArrangedSubview(row)
        }
        return stack
    }

    /// Guideline 1.4.1. Set apart from the rest so it reads as a statement of
    /// what the app is not, rather than as one more feature bullet.
    private func makeDisclaimerCard() -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .top

        let icon = UIImageView(image: UIImage(systemName: "info.circle.fill"))
        icon.tintColor = UIColor(named: "ButtonThemeMain") ?? .tintColor
        icon.contentMode = .scaleAspectFit
        icon.setContentHuggingPriority(.required, for: .horizontal)
        icon.widthAnchor.constraint(equalToConstant: 20).isActive = true

        row.addArrangedSubview(icon)
        row.addArrangedSubview(makeLabel(LegalLinks.medicalDisclaimer,
                                         style: .footnote,
                                         color: .secondaryLabel))

        let card = makeCard(containing: row)
        card.layer.borderWidth = 1
        card.layer.borderColor = (UIColor(named: "ButtonThemeMain") ?? .tintColor)
            .withAlphaComponent(0.35).cgColor
        return card
    }

    private func makeFooter() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12

        let links = LegalLinks.makeLinkRow(
            target: self,
            privacyAction: #selector(openPrivacy),
            termsAction: #selector(openTerms),
            supportAction: #selector(openSupport))

        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"

        stack.addArrangedSubview(links)
//        stack.addArrangedSubview(makeLabel("Spasht \(version) (\(build))",
//                                           style: .caption1,
//                                           color: .tertiaryLabel,
//                                           alignment: .center))
        return stack
    }

    // MARK: - Building blocks

    private func makeSection(title: String, card: UIView) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.addArrangedSubview(makeLabel(title, style: .headline))
        stack.addArrangedSubview(card)
        return stack
    }

    private func makeRows(_ items: [(icon: String, title: String, detail: String)]) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0

        for (index, item) in items.enumerated() {
            if index > 0 {
                let separator = UIView()
                separator.backgroundColor = .separator
                separator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale).isActive = true
                stack.addArrangedSubview(separator)
            }
            stack.addArrangedSubview(makeRow(icon: item.icon,
                                             title: item.title,
                                             detail: item.detail,
                                             isFirst: index == 0))
        }
        return stack
    }

    private func makeRow(icon: String, title: String, detail: String, isFirst: Bool) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 14
        row.alignment = .top
        row.layoutMargins = UIEdgeInsets(top: isFirst ? 0 : 14, left: 0, bottom: 14, right: 0)
        row.isLayoutMarginsRelativeArrangement = true

        let symbol = UIImageView(image: UIImage(systemName: icon))
        symbol.tintColor = UIColor(named: "ButtonThemeMain") ?? .tintColor
        symbol.contentMode = .scaleAspectFit
        symbol.setContentHuggingPriority(.required, for: .horizontal)
        symbol.widthAnchor.constraint(equalToConstant: 24).isActive = true
        // Nudges the symbol down onto the title's cap height rather than the
        // very top of the text box.
        symbol.heightAnchor.constraint(equalToConstant: 24).isActive = true

        let text = UIStackView()
        text.axis = .vertical
        text.spacing = 3
        text.addArrangedSubview(makeLabel(title, style: .subheadline, weight: .semibold))
        text.addArrangedSubview(makeLabel(detail, style: .footnote, color: .secondaryLabel))

        row.addArrangedSubview(symbol)
        row.addArrangedSubview(text)
        return row
    }

    private func makeTextCard(_ text: String) -> UIView {
        makeCard(containing: makeLabel(text, style: .body, color: .secondaryLabel))
    }

    private func makeCard(containing content: UIView) -> UIView {
        let card = UIView()
        card.backgroundColor = .secondarySystemGroupedBackground
        card.layer.cornerRadius = 16
        card.layer.cornerCurve = .continuous

        content.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(content)

        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18)
        ])
        return card
    }

    private func makeLabel(_ text: String,
                           style: UIFont.TextStyle,
                           weight: UIFont.Weight? = nil,
                           color: UIColor = .label,
                           alignment: NSTextAlignment = .natural) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = color
        label.numberOfLines = 0
        label.textAlignment = alignment
        label.adjustsFontForContentSizeCategory = true

        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: style)
        if let weight {
            let base = UIFont.systemFont(ofSize: descriptor.pointSize, weight: weight)
            label.font = UIFontMetrics(forTextStyle: style).scaledFont(for: base)
        } else {
            label.font = UIFont.preferredFont(forTextStyle: style)
        }
        return label
    }

    // MARK: - Legal links

    @objc private func openPrivacy() { LegalLinks.open(LegalLinks.privacyPolicy, from: self) }
    @objc private func openTerms()   { LegalLinks.open(LegalLinks.termsOfUse, from: self) }
    @objc private func openSupport() { LegalLinks.openSupport(from: self) }
}
