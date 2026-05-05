Chote Chote Chote Choteimport UIKit

class ReadingResultViewController: UIViewController {
    
    @IBOutlet weak var troubledWordsStackView: UIStackView!
    @IBOutlet weak var insightsLabel: UILabel!
    @IBOutlet weak var fluencyCircleView: UIView!
    @IBOutlet weak var repetitionPercentage: UILabel!
    @IBOutlet weak var prolongationPercentage: UILabel!
    @IBOutlet weak var blockPercentage: UILabel!
    @IBOutlet weak var readingTime: UILabel!
    
    var report: StutterJSONReport?
    
    private var hasSavedSession = false
    
    let customBrandBlue = UIColor(red: 0.21, green: 0.32, blue: 0.63, alpha: 1.0)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Result"
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "xmark"), style: .plain, target: self, action: #selector(didTapCloseResult))
        
        troubledWordsStackView.isHidden = false
        troubledWordsStackView.axis = .vertical
        troubledWordsStackView.spacing = 12
        troubledWordsStackView.alignment = .fill
        troubledWordsStackView.distribution = .fill
        
        // Ensure multiline label wraps properly inside stack views
        insightsLabel.numberOfLines = 0
        insightsLabel.lineBreakMode = .byWordWrapping
        
        if let report = report {
            print("REPORT RECEIVED with score: \(report.fluencyScore)")
            setupUIWithReport(report)
        } else {
            print("NO REPORT DATA RECEIVED")
            setupFluencyCircle(score: 0)
            insightsLabel.text = "No audio data recorded."
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let labelWidth = insightsLabel.superview?.bounds.width ?? (view.bounds.width - 72)
        insightsLabel.preferredMaxLayoutWidth = labelWidth
    }
    
    private func updateInsightsLayout() {
        // Recalculate the width for wrapping
        let labelWidth = insightsLabel.superview?.bounds.width ?? (view.bounds.width - 72)
        insightsLabel.preferredMaxLayoutWidth = labelWidth
        insightsLabel.invalidateIntrinsicContentSize()
        
        // Force the entire view hierarchy to re-layout
        insightsLabel.superview?.setNeedsLayout()
        insightsLabel.superview?.superview?.setNeedsLayout()
        view.layoutIfNeeded()
    }
    
    func setupUIWithReport(_ report: StutterJSONReport) {
        
        if !hasSavedSession {
            LogManager.shared.saveReadingSession(report: report)
            
            // 👇 Analyze troubled words and update the database dynamically
            analyzeAndSaveProblemPhonemes(from: report.stutteredWords)
            
            hasSavedSession = true
        }
            
        setupFluencyCircle(score: CGFloat(report.fluencyScore))
        
        Task {
            if let dayReport = await LogManager.shared.getDayReport(for: Date()) {
                await MainActor.run {
                    self.insightsLabel.text = dayReport.insight
                    self.updateInsightsLayout()
                }
            } else {
                await MainActor.run {
                    self.insightsLabel.text = "You showed up and practiced — that matters."
                    self.updateInsightsLayout()
                }
            }
        }
        
        readingTime.text = report.duration
        blockPercentage.text = "\(Int(report.percentages.blocks))"
        repetitionPercentage.text = "\(Int(report.percentages.repetition))"
        prolongationPercentage.text = "\(Int(report.percentages.prolongation))"
        
        loadTroubledWords(words: report.stutteredWords)
        LogManager.shared.saveReadingSession(report: report)
        LogManager.shared.debugPrintAllReadingSessions()

    }
    
    // MARK: - Phoneme Analysis Logic
    private func analyzeAndSaveProblemPhonemes(from words: [String]) {
        let cleanWords = words.filter { !$0.isEmpty }.map { $0.lowercased() }
        if cleanWords.isEmpty { return }

        var plosiveCount = 0
        var fricativeCount = 0
        var vowelVoicedCount = 0

        // Define our target groups based on your JSON setup
        let plosives: Set<Character> = ["p", "b", "t", "d", "k", "g"]
        let fricatives: Set<Character> = ["s", "f"]
        let vowelsVoiced: Set<Character> = ["a", "e", "i", "o", "u", "m", "n", "l"]

        // Tally up the starting letters of the stuttered words
        for word in cleanWords {
            if word.hasPrefix("sh") || word.hasPrefix("th") {
                fricativeCount += 1
                continue
            }
            if let firstChar = word.first {
                if plosives.contains(firstChar) {
                    plosiveCount += 1
                } else if fricatives.contains(firstChar) {
                    fricativeCount += 1
                } else if vowelsVoiced.contains(firstChar) {
                    vowelVoicedCount += 1
                }
            }
        }

        var problemPhonemes: [String] = []

        // If they struggled with a sound type during this session, add it to their problem list
        if plosiveCount > 0 {
            problemPhonemes.append("Plosives (P, B, T, D, K, G)")
        }
        if fricativeCount > 0 {
            problemPhonemes.append("Fricatives (S, F, SH, TH)")
        }
        if vowelVoicedCount > 0 {
            problemPhonemes.append("Vowels (A,E,I,O,U) & Voiced (M,N,L)")
        }

        // Only save if we actually detected recognizable phonemes
        if !problemPhonemes.isEmpty {
            DatabaseManager.shared.saveUserProblemPhonemes(phonemes: problemPhonemes)
            print("Dynamically updated user phonemes based on reading report: \(problemPhonemes)")
        }
    }

    // MARK: - Layout Methods
    func loadTroubledWords(words: [String]) {
        troubledWordsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        troubledWordsStackView.axis = .vertical
        troubledWordsStackView.alignment = .leading
        troubledWordsStackView.distribution = .fill
        troubledWordsStackView.spacing = 12
        troubledWordsStackView.setContentHuggingPriority(.required, for: .vertical)
        
        let cleanWords = words.filter({ !$0.isEmpty })
        
        if cleanWords.isEmpty {
            let noWordsLabel = UILabel()
            noWordsLabel.text = "No Troubled Words."
            noWordsLabel.font = UIFont.systemFont(ofSize: 15, weight: .regular)
            noWordsLabel.textColor = .secondaryLabel
            noWordsLabel.textAlignment = .left
            noWordsLabel.numberOfLines = 1
            troubledWordsStackView.alignment = .fill
            troubledWordsStackView.addArrangedSubview(noWordsLabel)
            return
        }
        
        let screenWidth: CGFloat
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            screenWidth = windowScene.screen.bounds.width
        } else {
            screenWidth = 390
        }
        
        // 20 leading on scrollView content + 20 leading inside the card = 40 each side = 80 total
        let maxWidth = screenWidth - 80
        var currentWidth: CGFloat = 0
        
        var currentRowView = createRowStack()
        troubledWordsStackView.addArrangedSubview(currentRowView)
        
        let displayWords = Array(cleanWords.prefix(12))
        
        for word in displayWords {
            let label = createTagLabel(text: word)
            let labelWidth = label.intrinsicContentSize.width
            
            if currentWidth + labelWidth > maxWidth && currentWidth > 0 {
                currentRowView = createRowStack()
                troubledWordsStackView.addArrangedSubview(currentRowView)
                currentWidth = 0
            }
            
            currentRowView.addArrangedSubview(label)
            currentWidth += (labelWidth + 8)
        }
    }
    
    private func createRowStack() -> UIStackView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .fill
        stack.spacing = 8
        return stack
    }
    
    private func createTagLabel(text: String) -> PaddingLabel {
        let label = PaddingLabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor(red: 0.1, green: 0.2, blue: 0.2, alpha: 1.0)
        label.backgroundColor = UIColor(red: 0.88, green: 0.95, blue: 0.95, alpha: 1.0)
        label.textAlignment = .center
        label.layer.cornerRadius = 12
        label.clipsToBounds = true
        return label
    }
    
    func setupFluencyCircle(score: CGFloat) {
        fluencyCircleView.layoutIfNeeded()
        fluencyCircleView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        
        let center = CGPoint(x: fluencyCircleView.bounds.midX, y: fluencyCircleView.bounds.midY)
        let lineWidth: CGFloat = 26
        let radius: CGFloat = min(fluencyCircleView.bounds.width, fluencyCircleView.bounds.height) / 2 - (lineWidth / 2 + 5)
        
        let circlePath = UIBezierPath(arcCenter: center, radius: radius, startAngle: -.pi / 2, endAngle: 1.5 * .pi, clockwise: true)
        
        let backgroundCircle = CAShapeLayer()
        backgroundCircle.path = circlePath.cgPath
        backgroundCircle.strokeColor = UIColor.systemGray5.cgColor
        backgroundCircle.lineWidth = lineWidth
        backgroundCircle.fillColor = UIColor.clear.cgColor
        backgroundCircle.lineCap = .round
        fluencyCircleView.layer.addSublayer(backgroundCircle)
        
        let progressCircle = CAShapeLayer()
        progressCircle.path = circlePath.cgPath
        progressCircle.strokeColor = customBrandBlue.cgColor
        progressCircle.lineWidth = lineWidth
        progressCircle.fillColor = UIColor.clear.cgColor
        progressCircle.lineCap = .round
        progressCircle.strokeEnd = 0
        fluencyCircleView.layer.addSublayer(progressCircle)
        
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.toValue = score / 100
        animation.duration = 1.2
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        progressCircle.add(animation, forKey: "progressAnim")
        
        let scoreLabel = UILabel(frame: fluencyCircleView.bounds)
        scoreLabel.text = "\(Int(score))"
        scoreLabel.textAlignment = .center
        scoreLabel.font = UIFont.boldSystemFont(ofSize: 42)
        scoreLabel.textColor = .black
        fluencyCircleView.addSubview(scoreLabel)
    }
    
    @objc func didTapCloseResult() {
        if let initialPresenter = self.presentingViewController?.presentingViewController {
            initialPresenter.dismiss(animated: true, completion: nil)
        }
    }
}

class PaddingLabel: UILabel {
    
    var topInset: CGFloat = 6.0
    var bottomInset: CGFloat = 6.0
    var leftInset: CGFloat = 12.0
    var rightInset: CGFloat = 12.0

    override func drawText(in rect: CGRect) {
        let insets = UIEdgeInsets(top: topInset, left: leftInset, bottom: bottomInset, right: rightInset)
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + leftInset + rightInset,
                      height: size.height + topInset + bottomInset)
    }
}
