import UIKit

/// Shows why a session reported what it reported.
///
/// Reached by long-pressing the score ring. It exists because the detection
/// pipeline has several places where a session can legitimately produce no
/// events — unusable word timings, gaps rejected at clause boundaries, gaps
/// that turned out to contain speech — and from the outside all of them look
/// identical to "you were fluent". Without this, diagnosing a device session
/// means guessing.
///
/// The text is selectable so it can be copied into a bug report.
final class SessionDiagnosticsViewController: UIViewController {

    private let report: StutterJSONReport
    private let textView = UITextView()

    init(report: StutterJSONReport) {
        self.report = report
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Session Diagnostics"
        view.backgroundColor = .systemBackground

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Copy", style: .plain, target: self, action: #selector(copyTapped)
        )
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close, target: self, action: #selector(closeTapped)
        )

        textView.isEditable = false
        textView.isSelectable = true
        textView.alwaysBounceVertical = true
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textColor = .label
        textView.backgroundColor = .systemBackground
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 32, right: 12)
        textView.text = buildText()
        textView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func buildText() -> String {
        var lines: [String] = []

        func section(_ name: String) {
            lines.append("")
            lines.append("── \(name) " + String(repeating: "─", count: max(0, 34 - name.count)))
        }
        func row(_ key: String, _ value: String) {
            lines.append(key.padding(toLength: 26, withPad: " ", startingAt: 0) + value)
        }

        section("RESULT")
        row("fluencyScore", "\(report.fluencyScore)")
        row("severity", report.severity)
        row("confidence", report.confidence)
        row("isReliable", "\(report.isReliable)")
        row("acousticAnalysisRan", "\(report.acousticAnalysisRan)")
        row("%SS", String(format: "%.2f", report.percentages.stutteredSyllables))
        row("duration", report.duration)

        section("EVENTS")
        row("repetition", "\(report.breakdown.repetition.count)  \(report.breakdown.repetition.prefix(6).joined(separator: ", "))")
        row("prolongation", "\(report.breakdown.prolongation.count)  \(report.breakdown.prolongation.prefix(6).joined(separator: ", "))")
        row("blocks", "\(report.breakdown.blocks)")
        report.blocks.prefix(8).forEach { lines.append("                          \($0)") }
        row("misread", "\(report.breakdown.misread.count)  \(report.breakdown.misread.prefix(6).joined(separator: ", "))")

        section("READING")
        let r = report.reading
        row("referenceWords", "\(r.referenceWords)")
        row("attempted", "\(r.attemptedWords)")
        row("judgeable", "\(r.judgeableWords)")
        row("matched", "\(r.matchedWords)")
        row("spoken", "\(r.spokenWords)")
        row("skipped", "\(r.skippedWords)")
        row("unrecognised", "\(r.unrecognisedWords)")
        row("extra", "\(r.extraWords)")
        row("completeness", String(format: "%.3f", r.completeness))
        row("accuracy", String(format: "%.3f", r.accuracy))
        row("coverage", String(format: "%.3f", r.coverage))
        row("syllablesAttempted", "\(r.syllablesAttempted)")

        section("PIPELINE")
        // Sorted so two sessions can be diffed against each other.
        for key in report.diagnostics.keys.sorted() {
            row(key, report.diagnostics[key] ?? "")
        }

        section("HOW TO READ THIS")
        lines.append("""
                          If timingsAreUsable is false, word timings from the
                          recogniser were unusable and blocks/prolongations
                          were not measured at all — the zeros are a failed
                          measurement, not a fluent session.

                          gapsRejected* says why each silence was not called a
                          block: TooShort (or beyond the 1.5s cap), AtBoundary
                          (the paragraph has punctuation there), NotSilent (the
                          gap contained speech), Unnamed (no reference word).

                          longestHoldSeen under 0.30s means no word contained a
                          steady enough stretch to count as a held sound.
                          """)
        return lines.joined(separator: "\n")
    }

    @objc private func copyTapped() {
        UIPasteboard.general.string = textView.text
        let alert = UIAlertController(title: nil, message: "Diagnostics copied", preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { alert.dismiss(animated: true) }
    }

    @objc private func closeTapped() { dismiss(animated: true) }
}
