import UIKit

// MARK: - ReadingResultViewController2 (Programmatic, no storyboard)

class ReadingResultViewController2: UIViewController {

    // MARK: - Input
    var report: StutterJSONReport?
    var preloadedInsight: String?

    // MARK: - State
    private var hasSavedSession = false
    private weak var scoreLabel: UILabel?
    private var scoreDisplayLink: CADisplayLink?
    private var scoreAnimStartTime: CFTimeInterval = 0
    private var scoreAnimFinalScore: Int = 0
    private var scoreAnimTotalTime: CFTimeInterval = 0

    // MARK: - Theme
    private var brandColor: UIColor {
        UIColor(named: "ButtonTheme") ?? UIColor(red: 0.21, green: 0.32, blue: 0.63, alpha: 1.0)
    }

    // MARK: - UI
    private let scrollView   = UIScrollView()
    private let contentStack = UIStackView()

    private let ringContainerView = UIView()
    private let ringView          = UIView()

    private let statsCard        = UIView()
    private let insightCard      = UIView()
    private let troubledCard        = UIView()
    private let troubledCardTitleLabel = UILabel()

    private let insightLabel         = UILabel()
    private let troubledFlowStack    = UIStackView()  // vertical, owns rows
    private let durationLabel        = UILabel()

    private let repValueLabel  = UILabel()
    private let proValueLabel  = UILabel()
    private let blkValueLabel  = UILabel()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "bg") ?? .systemBackground
        setupNavBar()
        buildLayout()
        populate()
        hideForAnimation()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateIn()
        if let r = report { animateRingAndScore(finalScore: CGFloat(r.fluencyScore)) }
    }

    // MARK: - Nav Bar

    private func setupNavBar() {
        title = "Session Result"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain, target: self,
            action: #selector(closeTapped)
        )
        navigationItem.leftBarButtonItem?.tintColor = .label
    }

    // MARK: - Layout

    private func buildLayout() {
        // Scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Content stack
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.alignment = .fill
        scrollView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -32),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])

        buildRingHeader()
        buildInsightCard()
        buildStatsCard()
        buildTroubledCard()
    }

    // ── Ring + Score ──────────────────────────────────────────────────────────

    private func buildRingHeader() {
        ringContainerView.translatesAutoresizingMaskIntoConstraints = false
        ringContainerView.backgroundColor = .clear
        contentStack.addArrangedSubview(ringContainerView)
        ringContainerView.heightAnchor.constraint(equalToConstant: 240).isActive = true

        // Ring circle
        ringView.translatesAutoresizingMaskIntoConstraints = false
        ringContainerView.addSubview(ringView)
        NSLayoutConstraint.activate([
            ringView.centerXAnchor.constraint(equalTo: ringContainerView.centerXAnchor),
            ringView.centerYAnchor.constraint(equalTo: ringContainerView.centerYAnchor, constant: -8),
            ringView.widthAnchor.constraint(equalToConstant: 160),
            ringView.heightAnchor.constraint(equalToConstant: 160)
        ])

        // Subtitle under ring
        let subtitle = UILabel()
        subtitle.text = "Fluency Score"
        subtitle.font = UIFont.preferredFont(forTextStyle: .title3)
        subtitle.textColor = brandColor
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        ringContainerView.addSubview(subtitle)
        NSLayoutConstraint.activate([
            subtitle.topAnchor.constraint(equalTo: ringView.bottomAnchor, constant: 10),
            subtitle.centerXAnchor.constraint(equalTo: ringContainerView.centerXAnchor)
        ])

        // Duration text (no capsule)
        durationLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        durationLabel.textColor = .secondaryLabel
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        ringContainerView.addSubview(durationLabel)
        NSLayoutConstraint.activate([
            durationLabel.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 4),
            durationLabel.centerXAnchor.constraint(equalTo: ringContainerView.centerXAnchor)
        ])
    }

    // ── Stats Card ────────────────────────────────────────────────────────────

    private func buildStatsCard() {
        styleCard(statsCard)
        contentStack.addArrangedSubview(statsCard)

        let title = sectionTitle("Stutter Breakdown")
        let hStack = UIStackView()
        hStack.axis = .horizontal
        hStack.distribution = .fillEqually
        hStack.spacing = 10
        hStack.translatesAutoresizingMaskIntoConstraints = false

        hStack.addArrangedSubview(makeStatTile(valueLabel: repValueLabel, name: "Repetition",   color: brandColor))
        hStack.addArrangedSubview(makeStatTile(valueLabel: proValueLabel, name: "Prolongation", color: brandColor))
        hStack.addArrangedSubview(makeStatTile(valueLabel: blkValueLabel, name: "Blocks",        color: brandColor))

        let vStack = UIStackView(arrangedSubviews: [title, hStack])
        vStack.axis = .vertical
        vStack.spacing = 8
        vStack.translatesAutoresizingMaskIntoConstraints = false
        statsCard.addSubview(vStack)
        NSLayoutConstraint.activate([
            vStack.topAnchor.constraint(equalTo: statsCard.topAnchor, constant: 14),
            vStack.leadingAnchor.constraint(equalTo: statsCard.leadingAnchor, constant: 16),
            vStack.trailingAnchor.constraint(equalTo: statsCard.trailingAnchor, constant: -16),
            vStack.bottomAnchor.constraint(equalTo: statsCard.bottomAnchor, constant: -14)
        ])
    }

    private func makeStatTile(valueLabel: UILabel, name: String, color: UIColor) -> UIView {
        let tile = UIView()
        tile.clipsToBounds = true

        valueLabel.font = .systemFont(ofSize: 28, weight: .bold)
        valueLabel.textColor = .label
        valueLabel.textAlignment = .left
        valueLabel.text = "0%"
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        let nameLabel = UILabel()
        nameLabel.text = name
        nameLabel.font = .systemFont(ofSize: 13, weight: .regular)
        nameLabel.textColor = brandColor
        nameLabel.textAlignment = .left
        nameLabel.numberOfLines = 2
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        tile.addSubview(valueLabel)
        tile.addSubview(nameLabel)
        NSLayoutConstraint.activate([
            valueLabel.topAnchor.constraint(equalTo: tile.topAnchor, constant: 16),
            valueLabel.leadingAnchor.constraint(equalTo: tile.leadingAnchor, constant: 4),
            valueLabel.trailingAnchor.constraint(equalTo: tile.trailingAnchor, constant: -4),
            nameLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 4),
            nameLabel.leadingAnchor.constraint(equalTo: tile.leadingAnchor, constant: 6),
            nameLabel.trailingAnchor.constraint(equalTo: tile.trailingAnchor, constant: -6),
            nameLabel.bottomAnchor.constraint(equalTo: tile.bottomAnchor, constant: -14)
        ])
        return tile
    }

    // ── Insight Card ──────────────────────────────────────────────────────────

    private func buildInsightCard() {
        // Custom background: filled with brandColor (not the default card style)
        insightCard.translatesAutoresizingMaskIntoConstraints = false
        insightCard.backgroundColor    = brandColor
        insightCard.layer.cornerRadius = 20
        insightCard.layer.shadowColor   = UIColor.black.cgColor
        insightCard.layer.shadowOpacity = 0.10
        insightCard.layer.shadowOffset  = CGSize(width: 0, height: 4)
        insightCard.layer.shadowRadius  = 10
        insightCard.clipsToBounds = false
        contentStack.addArrangedSubview(insightCard)

        let titleLabel = UILabel()
        titleLabel.text      = "Insight"
        titleLabel.font      = .systemFont(ofSize: 17, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        insightLabel.font          = .systemFont(ofSize: 15, weight: .regular)
        insightLabel.textColor     = UIColor.white.withAlphaComponent(0.85)
        insightLabel.numberOfLines = 0
        insightLabel.lineBreakMode = .byWordWrapping
        insightLabel.translatesAutoresizingMaskIntoConstraints = false

        let vStack = UIStackView(arrangedSubviews: [titleLabel, insightLabel])
        vStack.axis    = .vertical
        vStack.spacing = 10
        vStack.translatesAutoresizingMaskIntoConstraints = false
        insightCard.addSubview(vStack)
        NSLayoutConstraint.activate([
            vStack.topAnchor.constraint(equalTo: insightCard.topAnchor, constant: 18),
            vStack.leadingAnchor.constraint(equalTo: insightCard.leadingAnchor, constant: 18),
            vStack.trailingAnchor.constraint(equalTo: insightCard.trailingAnchor, constant: -18),
            vStack.bottomAnchor.constraint(equalTo: insightCard.bottomAnchor, constant: -18)
        ])
    }

    // ── Troubled Words Card ───────────────────────────────────────────────────

    private func buildTroubledCard() {
        styleCard(troubledCard)
        contentStack.addArrangedSubview(troubledCard)

        troubledCardTitleLabel.text = "Troubled Words"
        troubledCardTitleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        troubledCardTitleLabel.textColor = brandColor
        troubledCardTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        // troubledFlowStack is a self-sizing UIStackView — no wrapper UIView needed
        troubledFlowStack.axis        = .vertical
        troubledFlowStack.spacing     = 8
        troubledFlowStack.alignment   = .leading
        troubledFlowStack.distribution = .fill
        troubledFlowStack.translatesAutoresizingMaskIntoConstraints = false

        let vStack = UIStackView(arrangedSubviews: [troubledCardTitleLabel, troubledFlowStack])
        vStack.axis = .vertical
        vStack.spacing = 14
        vStack.translatesAutoresizingMaskIntoConstraints = false
        troubledCard.addSubview(vStack)
        NSLayoutConstraint.activate([
            vStack.topAnchor.constraint(equalTo: troubledCard.topAnchor, constant: 18),
            vStack.leadingAnchor.constraint(equalTo: troubledCard.leadingAnchor, constant: 18),
            vStack.trailingAnchor.constraint(equalTo: troubledCard.trailingAnchor, constant: -18),
            vStack.bottomAnchor.constraint(equalTo: troubledCard.bottomAnchor, constant: -18)
        ])
    }

    // MARK: - Populate Data

    private func populate() {
        guard let r = report else {
            insightLabel.text = "No audio data recorded."
            durationLabel.text = "0 sec"
            repValueLabel.text = "0%"
            proValueLabel.text = "0%"
            blkValueLabel.text = "0%"
            buildTroubledChips(words: [])
            return
        }

        if !hasSavedSession {
            _ = LogManager.shared.saveReadingSession(report: r, insight: preloadedInsight)
            analyzeAndSaveProblemPhonemes(from: r.stutteredWords)
            hasSavedSession = true
        }

        insightLabel.text = preloadedInsight ?? "You showed up and practiced — that matters."
        durationLabel.text = "Duration: \(r.duration)"
        repValueLabel.text = "\(Int(r.percentages.repetition))%"
        proValueLabel.text = "\(Int(r.percentages.prolongation))%"
        blkValueLabel.text = "\(Int(r.percentages.blocks))%"
        buildTroubledChips(words: r.stutteredWords)
    }

    // MARK: - Troubled Chips (Wrapping Flow)

    private func buildTroubledChips(words: [String]) {
        // Clear previous rows
        troubledFlowStack.arrangedSubviews.forEach {
            troubledFlowStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let clean = words.filter { !$0.isEmpty }

        if clean.isEmpty {
            troubledCardTitleLabel.text      = "No Troubled Words "
            troubledCardTitleLabel.textColor = .label
            troubledFlowStack.isHidden = true
            return
        }

        troubledCardTitleLabel.text      = "Troubled Words"
        troubledCardTitleLabel.textColor = .label
        troubledFlowStack.isHidden = false

        // Card inner width: screen width - outer padding (40) - card insets (36)
        let chipFont = UIFont.systemFont(ofSize: 13, weight: .semibold)
        let chipHPad: CGFloat = 24   // 12 left + 12 right inside pill
        let chipSpacing: CGFloat = 8
        let maxRowWidth = view.bounds.width - 40 - 36

        var currentRow = makeChipRow()
        troubledFlowStack.addArrangedSubview(currentRow)
        var rowWidth: CGFloat = 0

        for word in Array(clean.prefix(14)) {
            // Measure text width without needing a layout pass
            let textW = (word as NSString).size(
                withAttributes: [.font: chipFont]
            ).width.rounded(.up)
            let chipW = textW + chipHPad

            if rowWidth > 0 && rowWidth + chipSpacing + chipW > maxRowWidth {
                // Finish row with a spacer so chips stay left-aligned
                let spacer = UIView()
                spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
                currentRow.addArrangedSubview(spacer)

                currentRow = makeChipRow()
                troubledFlowStack.addArrangedSubview(currentRow)
                rowWidth = 0
            }

            currentRow.addArrangedSubview(makeChip(text: word))
            rowWidth += (rowWidth == 0 ? 0 : chipSpacing) + chipW
        }

        // Trailing spacer on last row
        let trailSpacer = UIView()
        trailSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        currentRow.addArrangedSubview(trailSpacer)
    }

    private func makeChipRow() -> UIStackView {
        let s = UIStackView()
        s.axis = .horizontal
        s.spacing = 8
        s.alignment = .center
        s.distribution = .fill
        return s
    }

    private func makeChip(text: String) -> UIView {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false

        let pill = UIView()
        pill.backgroundColor = brandColor.withAlphaComponent(0.12)
        pill.layer.cornerRadius = 12
        pill.clipsToBounds = true
        pill.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: pill.topAnchor, constant: 6),
            label.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -6),
            label.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -12)
        ])
        return pill
    }

    // MARK: - Fluency Ring (programmatic CAShapeLayer)

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        setupRingIfNeeded()
    }

    private var ringBuilt = false
    private func setupRingIfNeeded() {
        guard !ringBuilt, ringView.bounds.width > 0 else { return }
        ringBuilt = true

        let center    = CGPoint(x: ringView.bounds.midX, y: ringView.bounds.midY)
        let lineWidth: CGFloat = 18
        let radius    = min(ringView.bounds.width, ringView.bounds.height) / 2 - lineWidth / 2
        let path      = UIBezierPath(arcCenter: center, radius: radius,
                                     startAngle: -.pi / 2, endAngle: 1.5 * .pi, clockwise: true)

        // Track
        let track = CAShapeLayer()
        track.path        = path.cgPath
        track.strokeColor = brandColor.withAlphaComponent(0.12).cgColor
        track.lineWidth   = lineWidth
        track.fillColor   = UIColor.clear.cgColor
        track.lineCap     = .round
        ringView.layer.addSublayer(track)

        // Progress
        let progress = CAShapeLayer()
        progress.path        = path.cgPath
        progress.strokeColor = brandColor.cgColor
        progress.lineWidth   = lineWidth
        progress.fillColor   = UIColor.clear.cgColor
        progress.lineCap     = .round
        progress.strokeEnd   = 0
        ringView.layer.addSublayer(progress)

        // Score label
        let lbl = UILabel(frame: ringView.bounds)
        lbl.text          = "0"
        lbl.textAlignment = .center
        lbl.font          = .systemFont(ofSize: 42, weight: .bold)
        lbl.textColor     = .label
        ringView.addSubview(lbl)
        scoreLabel = lbl
    }

    // MARK: - Ring Animation

    private let ringRiseDuration: CFTimeInterval = 1.4
    private let ringHoldDuration: CFTimeInterval = 0.4
    private let ringFallDuration: CFTimeInterval = 0.9

    private func animateRingAndScore(finalScore: CGFloat) {
        guard let progressLayer = ringView.layer.sublayers?
            .compactMap({ $0 as? CAShapeLayer })
            .first(where: { $0.fillColor == UIColor.clear.cgColor && $0.strokeEnd == 0 }) else { return }

        let target    = finalScore / 100.0
        let isNearFull = finalScore >= 95
        let anim: CAPropertyAnimation
        let totalTime: CFTimeInterval

        if isNearFull {
            totalTime = ringRiseDuration
            let basic  = CABasicAnimation(keyPath: "strokeEnd")
            basic.fromValue = 0.0
            basic.toValue   = Double(target)
            basic.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            anim = basic
        } else {
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
        progressLayer.add(anim, forKey: "ringAnim")

        scoreAnimFinalScore = Int(finalScore)
        scoreAnimTotalTime  = totalTime
        scoreAnimStartTime  = CACurrentMediaTime()
        scoreDisplayLink?.invalidate()
        let link = CADisplayLink(target: self, selector: #selector(scoreAnimTick))
        link.add(to: .main, forMode: .common)
        scoreDisplayLink = link
    }

    @objc private func scoreAnimTick() {
        let elapsed = CACurrentMediaTime() - scoreAnimStartTime
        let t       = min(elapsed / scoreAnimTotalTime, 1.0)
        let eased   = 1 - pow(1 - t, 3)
        scoreLabel?.text = "\(Int(Double(scoreAnimFinalScore) * eased))"
        if t >= 1.0 {
            scoreDisplayLink?.invalidate()
            scoreDisplayLink = nil
            scoreLabel?.text = "\(scoreAnimFinalScore)"
        }
    }

    // MARK: - Entry Animation

    private func hideForAnimation() {
        [statsCard, insightCard, troubledCard].forEach {
            $0.alpha = 0
            $0.transform = CGAffineTransform(translationX: 0, y: 24)
        }
        ringContainerView.alpha = 0
        ringContainerView.transform = CGAffineTransform(translationX: 0, y: 20)
    }

    private func animateIn() {
        UIView.animate(withDuration: 0.55, delay: 0.05,
                       usingSpringWithDamping: 0.8, initialSpringVelocity: 0,
                       options: .curveEaseOut) {
            self.ringContainerView.alpha = 1
            self.ringContainerView.transform = .identity
        }
        let cards: [UIView] = [statsCard, insightCard, troubledCard]
        for (i, card) in cards.enumerated() {
            UIView.animate(withDuration: 0.5, delay: 0.2 + Double(i) * 0.1,
                           usingSpringWithDamping: 0.82, initialSpringVelocity: 0,
                           options: .curveEaseOut) {
                card.alpha = 1
                card.transform = .identity
            }
        }
    }

    // MARK: - Phoneme Analysis

    private func analyzeAndSaveProblemPhonemes(from words: [String]) {
        let clean = words.filter { !$0.isEmpty }.map { $0.lowercased() }
        guard !clean.isEmpty else { return }

        let plosives:    Set<Character> = ["p","b","t","d","k","g"]
        let fricatives:  Set<Character> = ["s","f"]
        let vowelsVoiced: Set<Character> = ["a","e","i","o","u","m","n","l"]

        var plos = 0, fric = 0, vowV = 0
        for word in clean {
            if word.hasPrefix("sh") || word.hasPrefix("th") { fric += 1; continue }
            if let c = word.first {
                if plosives.contains(c)    { plos += 1 }
                else if fricatives.contains(c) { fric += 1 }
                else if vowelsVoiced.contains(c) { vowV += 1 }
            }
        }
        var phonemes: [String] = []
        if plos > 0 { phonemes.append("Plosives (P, B, T, D, K, G)") }
        if fric > 0 { phonemes.append("Fricatives (S, F, SH, TH)") }
        if vowV > 0 { phonemes.append("Vowels (A,E,I,O,U) & Voiced (M,N,L)") }
        if !phonemes.isEmpty { DatabaseManager.shared.saveUserProblemPhonemes(phonemes: phonemes) }
    }

    // MARK: - Navigation

    @objc private func closeTapped() {
        if let presenter = presentingViewController?.presentingViewController {
            presenter.dismiss(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    // MARK: - Builder Helpers

    private func styleCard(_ card: UIView) {
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor     = UIColor(named: "CardBG") ?? .secondarySystemBackground
        card.layer.cornerRadius  = 20
        card.layer.shadowColor   = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.06
        card.layer.shadowOffset  = CGSize(width: 0, height: 4)
        card.layer.shadowRadius  = 10
        card.clipsToBounds = false
    }

    private func sectionTitle(_ text: String) -> UILabel {
        makeLabel(text, size: 17, weight: .semibold, color: .label)
    }

    private func makeLabel(_ text: String, size: CGFloat, weight: UIFont.Weight, color: UIColor) -> UILabel {
        let l = UILabel()
        l.text      = text
        l.font      = .systemFont(ofSize: size, weight: weight)
        l.textColor = color
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }


}
