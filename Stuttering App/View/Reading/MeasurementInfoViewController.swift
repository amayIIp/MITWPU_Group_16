//
//  MeasurementInfoViewController.swift
//  Spasht
//
//  "How is this measured?" — opened from the ⓘ on the reading result screen.
//
//  Guideline 1.4.1: apps "must clearly disclose data and methodology to support
//  accuracy claims relating to health measurements", and "should remind users to
//  check with a doctor". The result screen reports percent syllables stuttered,
//  so this sheet says how that number is produced and what it can't do.
//
//  Every statement here describes what StutterAnalyzer and SpeechEnvelope
//  actually do. If the thresholds in SpeechEnvelope.Tuning or the score formula
//  in StutterAnalyzer change, change this text with them — a disclosure that
//  misdescribes the method is worse than none.
//

import UIKit

final class MeasurementInfoViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let stack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "How It's Measured"
        view.backgroundColor = UIColor(named: "bg") ?? .systemGroupedBackground

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .done,
            primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) }
        )

        layout()
        populate()
    }

    // MARK: - Layout

    private func layout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 22
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -32),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20)
        ])
    }

    // MARK: - Content

    private func populate() {
        addSection(
            "Your recording stays on your iPhone",
            body: """
            Spasht records you while you read and transcribes your speech on the device — \
            with Apple's speech recogniser, or a speech model built into the app if that \
            returns nothing. The recording is deleted when the analysis finishes. Audio \
            never leaves your phone.
            """
        )

        addSection(
            "What's counted",
            bullets: [
                ("Repetitions", "a whole word said more than once, found by comparing what you said with the passage. Repeated sounds within a word, like \"b-b-but\", aren't detected yet."),
                ("Blocks", "a silent pause of a quarter of a second to a second and a half just before a word, measured from how loud the recording is. Natural pauses at commas and full stops are allowed for."),
                ("Prolongations", "a sound held steadily for about a third of a second or longer."),
                ("Misread", "a word that didn't match the passage. This is reading feedback, not a stutter, and it isn't counted as one.")
            ]
        )

        addSection(
            "The numbers",
            body: """
            Syllables stuttered is the number of repetitions, blocks and prolongations, as \
            a share of the syllables you read. Your Fluency Score starts from that, and also \
            takes into account how much of the passage you read and how closely it matched.

            Sessions shorter than about 30 syllables are marked as too short to score reliably.
            """
        )

        addSection(
            "What it can get wrong",
            bullets: [
                ("Estimates, not an assessment", "these are automated estimates for tracking your own practice. They are not a clinical assessment, and they haven't been validated against ratings by speech-language pathologists."),
                ("Recognition smooths speech", "speech recognisers are designed to tidy speech up, so they can miss repetitions."),
                ("Conditions matter", "background noise, accents, and reading very fast or very quietly can all make a result less accurate, in either direction. When a session was hard to transcribe, Spasht says so and shows rougher figures."),
                ("Compare yourself with yourself", "the scores are most useful for seeing how your own sessions change over time.")
            ]
        )

        addSection(
            "Not medical advice",
            body: LegalLinks.medicalDisclaimer
                + "\n\nCheck with a qualified professional before making any decisions about your speech or treatment."
        )
    }

    private func addSection(_ heading: String, body: String) {
        let section = sectionStack(heading)
        section.addArrangedSubview(bodyLabel(body))
        stack.addArrangedSubview(section)
    }

    private func addSection(_ heading: String, bullets: [(String, String)]) {
        let section = sectionStack(heading)
        for (term, detail) in bullets {
            let label = bodyLabel("")
            let text = NSMutableAttributedString(
                string: term + " — ",
                attributes: [.font: UIFont.preferredFont(forTextStyle: .subheadline).bold(),
                             .foregroundColor: UIColor.label]
            )
            text.append(NSAttributedString(
                string: detail,
                attributes: [.font: UIFont.preferredFont(forTextStyle: .subheadline),
                             .foregroundColor: UIColor.secondaryLabel]
            ))
            label.attributedText = text
            section.addArrangedSubview(label)
        }
        stack.addArrangedSubview(section)
    }

    private func sectionStack(_ heading: String) -> UIStackView {
        let title = UILabel()
        title.text = heading
        title.font = .preferredFont(forTextStyle: .headline)
        title.adjustsFontForContentSizeCategory = true
        title.numberOfLines = 0
        title.accessibilityTraits = .header

        let section = UIStackView(arrangedSubviews: [title])
        section.axis = .vertical
        section.spacing = 8
        return section
    }

    private func bodyLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }
}

private extension UIFont {
    func bold() -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(.traitBold) else { return self }
        return UIFont(descriptor: descriptor, size: 0)
    }
}
