import UIKit

class ReadingResultViewController: UIViewController {

    // MARK: - IBOutlets (storyboard connections — do not rename)
    @IBOutlet weak var TroubledWordsLabel: UILabel!
    @IBOutlet weak var troubledWordsStackView: UIStackView!
    @IBOutlet weak var insightsLabel: UILabel!
    @IBOutlet weak var fluencyCircleView: UIView!
    @IBOutlet weak var repetitionPercentage: UILabel!
    @IBOutlet weak var prolongationPercentage: UILabel!
    @IBOutlet weak var blockPercentage: UILabel!
    @IBOutlet weak var readingTime: UILabel!

    // MARK: - Input — both set by DetailViewController before presenting
    var report: StutterJSONReport?
    /// Pre-fetched insight — set by caller so there is zero async pop-in on this screen.
    var preloadedInsight: String?

    // MARK: - Private state
    private var hasSavedSession = false

    private weak var scoreLabel: UILabel?

    let customBrandBlue = UIColor(named: "ButtonTheme") ?? UIColor(red: 0.21, green: 0.32, blue: 0.63, alpha: 1.0)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = "Result"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"), style: .plain,
            target: self, action: #selector(didTapCloseResult)
        )



        troubledWordsStackView.isHidden = false
        troubledWordsStackView.axis = .vertical
        troubledWordsStackView.spacing = 12
        troubledWordsStackView.alignment = .fill
        troubledWordsStackView.distribution = .fill

        insightsLabel.numberOfLines = 0
        insightsLabel.lineBreakMode = .byWordWrapping
        insightsLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        insightsLabel.setContentHuggingPriority(.required, for: .vertical)

        if let report = report {
            // Insight is pre-fetched — show it immediately with no placeholder
            insightsLabel.text = preloadedInsight ?? "You showed up and practiced — that matters."
            setupUIWithReport(report)
        } else {
            setupFluencyCircle(score: 0)
            insightsLabel.text = "No audio data recorded."
        }

        // Hide all cards initially for staggered entry
        cardViews().forEach { $0.alpha = 0; $0.transform = CGAffineTransform(translationX: 0, y: 28) }
        fluencyCircleView.superview?.alpha = 0
        fluencyCircleView.superview?.transform = CGAffineTransform(translationX: 0, y: 20)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateContentIn()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let labelWidth = insightsLabel.superview?.bounds.width ?? (view.bounds.width - 72)
        insightsLabel.preferredMaxLayoutWidth = labelWidth
    }



    // MARK: - Staggered Entry Animation

    private func cardViews() -> [UIView] {
        // Walk up from each IBOutlet to find the card container (2 levels up = card UIView)
        var cards: [UIView] = []
        func card(from view: UIView?) -> UIView? { view?.superview?.superview }
        if let c = card(from: insightsLabel) { cards.append(c) }
        if let c = card(from: blockPercentage) { cards.append(c) }
        if let c = card(from: troubledWordsStackView) { cards.append(c) }
        return cards
    }

    private func animateContentIn() {
        // Score circle slides up first
        UIView.animate(withDuration: 0.55, delay: 0.05,
                       usingSpringWithDamping: 0.8, initialSpringVelocity: 0,
                       options: .curveEaseOut) {
            self.fluencyCircleView.superview?.alpha = 1
            self.fluencyCircleView.superview?.transform = .identity
        }

        // Cards stagger in
        for (i, card) in cardViews().enumerated() {
            UIView.animate(withDuration: 0.5, delay: 0.18 + Double(i) * 0.12,
                           usingSpringWithDamping: 0.82, initialSpringVelocity: 0,
                           options: .curveEaseOut) {
                card.alpha = 1
                card.transform = .identity
            }
        }

        // Ring showcase + synced score count-up
        if let report = report {
            animateRingAndScore(finalScore: CGFloat(report.fluencyScore))
        }
    }

    // MARK: - Ring Showcase + Score Count-Up

    private var scoreDisplayLink: CADisplayLink?
    private var scoreAnimStartTime: CFTimeInterval = 0
    private var scoreAnimFinalScore: Int = 0
    private var scoreAnimTotalTime:  CFTimeInterval = 0  // set per-animation so label syncs with ring
    private let ringRiseDuration:  CFTimeInterval = 1.4
    private let ringHoldDuration:  CFTimeInterval = 0.4
    private let ringFallDuration:  CFTimeInterval = 0.9

    /// Animates the ring: 0 → full → actual score, and counts the label from 0 → actual score.
    /// For scores ≥ 95 the overshoot-to-full showcase is skipped to avoid the ugly near-complete
    /// ring rendering (tiny gap + round-cap overlap on the track).
    private func animateRingAndScore(finalScore: CGFloat) {
        // Locate the progress CAShapeLayer (clear fill = arc, not the track)
        let progressLayer = fluencyCircleView.layer.sublayers?
            .compactMap { $0 as? CAShapeLayer }
            .first { $0.fillColor == UIColor.clear.cgColor }
        guard let progressLayer = progressLayer else { return }

        let target = finalScore / 100.0
        let isNearFull = finalScore >= 95  // overshoot looks bad when gap is tiny

        let anim: CAPropertyAnimation
        let totalTime: CFTimeInterval

        if isNearFull {
            // Simple straight rise: 0 → target — clean at any near-100 score
            totalTime = ringRiseDuration
            let basic = CABasicAnimation(keyPath: "strokeEnd")
            basic.fromValue = 0.0
            basic.toValue   = Double(target)
            basic.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            anim = basic
        } else {
            // 3-phase showcase: 0 → full → hold → target
            totalTime = ringRiseDuration + ringHoldDuration + ringFallDuration
            let kf = CAKeyframeAnimation(keyPath: "strokeEnd")
            kf.values   = [0.0, 1.0, 1.0, Double(target)]
            kf.keyTimes = [
                0,
                NSNumber(value: ringRiseDuration / totalTime),
                NSNumber(value: (ringRiseDuration + ringHoldDuration) / totalTime),
                1.0
            ]
            kf.timingFunctions = [
                CAMediaTimingFunction(name: .easeInEaseOut),
                CAMediaTimingFunction(name: .linear),
                CAMediaTimingFunction(name: .easeInEaseOut)
            ]
            anim = kf
        }

        anim.duration              = totalTime
        anim.fillMode              = .forwards
        anim.isRemovedOnCompletion = false
        progressLayer.add(anim, forKey: "showcaseRingAnim")

        // --- CADisplayLink drives the score label (0 → finalScore) ---
        scoreAnimFinalScore = Int(finalScore)
        scoreAnimTotalTime  = totalTime   // keep in sync with whichever path was taken
        scoreAnimStartTime  = CACurrentMediaTime()
        scoreDisplayLink?.invalidate()
        let link = CADisplayLink(target: self, selector: #selector(scoreAnimTick))
        link.add(to: .main, forMode: .common)
        scoreDisplayLink = link
    }

    @objc private func scoreAnimTick() {
        let elapsed = CACurrentMediaTime() - scoreAnimStartTime
        let t       = min(elapsed / scoreAnimTotalTime, 1.0)
        let eased   = 1 - pow(1 - t, 3)   // ease-out cubic
        scoreLabel?.text = "\(Int(Double(scoreAnimFinalScore) * eased))"
        if t >= 1.0 {
            scoreDisplayLink?.invalidate()
            scoreDisplayLink = nil
            scoreLabel?.text = "\(scoreAnimFinalScore)"
        }
    }

    // MARK: - UI Setup

    func setupUIWithReport(_ report: StutterJSONReport) {
        if !hasSavedSession {
            let sessionId = LogManager.shared.saveReadingSession(report: report)
            analyzeAndSaveProblemPhonemes(from: report.stutteredWords)
            hasSavedSession = true

            // Store the pre-fetched insight in the DB for future recall — no UI block
            if let sessionId = sessionId, let insight = preloadedInsight {
                LogManager.shared.updateSessionInsight(sessionId: sessionId, insight: insight)
            }
        }

        setupFluencyCircle(score: CGFloat(report.fluencyScore))

        readingTime.text = report.duration
        blockPercentage.text = "\(Int(report.percentages.blocks))"
        repetitionPercentage.text = "\(Int(report.percentages.repetition))"
        prolongationPercentage.text = "\(Int(report.percentages.prolongation))"

        loadTroubledWords(words: report.stutteredWords)
        LogManager.shared.debugPrintAllReadingSessions()
    }

    private func updateInsightsLayout() {
        let containerWidth = insightsLabel.superview?.bounds.width ?? (view.bounds.width - 72)
        insightsLabel.preferredMaxLayoutWidth = containerWidth - 28
        insightsLabel.invalidateIntrinsicContentSize()
        insightsLabel.superview?.setNeedsLayout()
        insightsLabel.superview?.superview?.setNeedsLayout()
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    // MARK: - Phoneme Analysis

    private func analyzeAndSaveProblemPhonemes(from words: [String]) {
        let cleanWords = words.filter { !$0.isEmpty }.map { $0.lowercased() }
        guard !cleanWords.isEmpty else { return }

        let plosives: Set<Character>    = ["p", "b", "t", "d", "k", "g"]
        let fricatives: Set<Character>  = ["s", "f"]
        let vowelsVoiced: Set<Character> = ["a", "e", "i", "o", "u", "m", "n", "l"]

        var plosiveCount = 0, fricativeCount = 0, vowelVoicedCount = 0

        for word in cleanWords {
            if word.hasPrefix("sh") || word.hasPrefix("th") { fricativeCount += 1; continue }
            if let first = word.first {
                if plosives.contains(first)    { plosiveCount += 1 }
                else if fricatives.contains(first) { fricativeCount += 1 }
                else if vowelsVoiced.contains(first) { vowelVoicedCount += 1 }
            }
        }

        var problemPhonemes: [String] = []
        if plosiveCount   > 0 { problemPhonemes.append("Plosives (P, B, T, D, K, G)") }
        if fricativeCount > 0 { problemPhonemes.append("Fricatives (S, F, SH, TH)") }
        if vowelVoicedCount > 0 { problemPhonemes.append("Vowels (A,E,I,O,U) & Voiced (M,N,L)") }

        if !problemPhonemes.isEmpty {
            DatabaseManager.shared.saveUserProblemPhonemes(phonemes: problemPhonemes)
        }
    }

    // MARK: - Troubled Words

    func loadTroubledWords(words: [String]) {
        troubledWordsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        troubledWordsStackView.axis      = .vertical
        troubledWordsStackView.alignment = .leading
        troubledWordsStackView.distribution = .fill
        troubledWordsStackView.spacing   = 12
        troubledWordsStackView.setContentHuggingPriority(.required, for: .vertical)

        let cleanWords = words.filter { !$0.isEmpty }

        if cleanWords.isEmpty {
            let noWordsLabel = UILabel()
            noWordsLabel.text = "No troubled words detected."
            noWordsLabel.font = UIFont.systemFont(ofSize: 15, weight: .regular)
            noWordsLabel.textColor = .secondaryLabel
            noWordsLabel.textAlignment = .center
            noWordsLabel.numberOfLines = 1
            troubledWordsStackView.alignment = .fill
            troubledWordsStackView.addArrangedSubview(noWordsLabel)
            return
        }

        let screenWidth: CGFloat = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.first?.screen.bounds.width ?? 390
        let maxWidth = screenWidth - 80
        var currentWidth: CGFloat = 0

        var currentRowView = createRowStack()
        troubledWordsStackView.addArrangedSubview(currentRowView)

        for word in Array(cleanWords.prefix(12)) {
            let label = createTagLabel(text: word)
            let labelWidth = label.intrinsicContentSize.width

            if currentWidth + labelWidth > maxWidth && currentWidth > 0 {
                let spacer = UIView()
                spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
                currentRowView.addArrangedSubview(spacer)
                currentRowView = createRowStack()
                troubledWordsStackView.addArrangedSubview(currentRowView)
                currentWidth = 0
            }

            currentRowView.addArrangedSubview(label)
            currentWidth += (labelWidth + 8)
        }

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        currentRowView.addArrangedSubview(spacer)
    }

    private func createRowStack() -> UIStackView {
        let stack = UIStackView()
        stack.axis = .horizontal; stack.alignment = .center
        stack.distribution = .fill; stack.spacing = 8
        return stack
    }

    private func createTagLabel(text: String) -> PaddingLabel {
        let label = PaddingLabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = customBrandBlue
        label.backgroundColor = customBrandBlue.withAlphaComponent(0.15)
        label.textAlignment = .center
        label.layer.cornerRadius = 12
        label.clipsToBounds = true
        return label
    }

    // MARK: - Fluency Circle

    func setupFluencyCircle(score: CGFloat) {
        fluencyCircleView.layoutIfNeeded()
        fluencyCircleView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        fluencyCircleView.subviews.forEach { $0.removeFromSuperview() }

        let center    = CGPoint(x: fluencyCircleView.bounds.midX, y: fluencyCircleView.bounds.midY)
        let lineWidth: CGFloat = 26
        let radius    = min(fluencyCircleView.bounds.width, fluencyCircleView.bounds.height) / 2 - (lineWidth / 2 + 5)
        let circlePath = UIBezierPath(arcCenter: center, radius: radius,
                                      startAngle: -.pi / 2, endAngle: 1.5 * .pi, clockwise: true)

        // Track
        let trackLayer = CAShapeLayer()
        trackLayer.path        = circlePath.cgPath
        trackLayer.strokeColor = CGColor(red: 0.925, green: 0.933, blue: 0.973, alpha: 1.0)
        trackLayer.lineWidth   = lineWidth
        trackLayer.fillColor   = (UIColor(named: "bg") ?? UIColor(white: 0.96, alpha: 1)).cgColor
        trackLayer.lineCap     = .round
        fluencyCircleView.layer.addSublayer(trackLayer)

        // Progress arc — starts at 0; animated by animateRingAndScore in viewDidAppear
        let progressLayer = CAShapeLayer()
        progressLayer.path        = circlePath.cgPath
        progressLayer.strokeColor = customBrandBlue.cgColor
        progressLayer.lineWidth   = lineWidth
        progressLayer.fillColor   = UIColor.clear.cgColor
        progressLayer.lineCap     = .round
        progressLayer.strokeEnd   = 0   // animation starts from viewDidAppear
        fluencyCircleView.layer.addSublayer(progressLayer)

        // Score label — start at 0, count up in viewDidAppear
        let label = UILabel(frame: fluencyCircleView.bounds)
        label.text          = "0"
        label.textAlignment = .center
        label.font          = UIFont.systemFont(ofSize: 46, weight: .bold)
        label.textColor     = .label
        fluencyCircleView.addSubview(label)
        scoreLabel = label  // keep a weak ref for the count-up animation
    }

    // MARK: - Navigation

    @objc func didTapCloseResult() {
        if let initialPresenter = self.presentingViewController?.presentingViewController {
            initialPresenter.dismiss(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}

// MARK: - PaddingLabel

class PaddingLabel: UILabel {
    var topInset:    CGFloat = 6
    var bottomInset: CGFloat = 6
    var leftInset:   CGFloat = 12
    var rightInset:  CGFloat = 12

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: UIEdgeInsets(
            top: topInset, left: leftInset, bottom: bottomInset, right: rightInset
        )))
    }

    override var intrinsicContentSize: CGSize {
        let s = super.intrinsicContentSize
        return CGSize(width: s.width + leftInset + rightInset,
                      height: s.height + topInset + bottomInset)
    }
}
