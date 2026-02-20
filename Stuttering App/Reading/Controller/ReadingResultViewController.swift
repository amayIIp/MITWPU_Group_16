import UIKit

class ReadingResultViewController: UIViewController {
    
    @IBOutlet var exercisesStackView: UIStackView!
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
        
        if let report = report {
            print("REPORT RECEIVED with score: \(report.fluencyScore)")
            setupUIWithReport(report)
        } else {
            print("NO REPORT DATA RECEIVED")
            setupFluencyCircle(score: 0)
            insightsLabel.text = "No audio data recorded."
        }
    }
    
//    func setupUIWithReport(_ report: StutterJSONReport) {
//        // 1. Score
//        setupFluencyCircle(score: CGFloat(report.fluencyScore))
//        
//        // 2. Insight Message
//        insightsLabel.text = "Your /r/ and /s/ sounds have improved 12% today !!"
//        
//        // 3. Set Percentages & Time
//        readingTime.text = report.duration
//        blockPercentage.text = "\(Int(report.percentages.blocks))%"
//        repetitionPercentage.text = "\(Int(report.percentages.repetition))%"
//        prolongationPercentage.text = "\(Int(report.percentages.prolongation))%"
//        
//        // 4. Troubled Words
//        loadTroubledWords(words: report.stutteredWords)
//        
//        // 5. Exercises
//        var recommended: [String] = []
//        if report.percentages.blocks > 5.0 { recommended.append("Easy Onset") }
//        if report.percentages.repetition > 5.0 { recommended.append("Pull-outs") }
//        if report.percentages.prolongation > 5.0 { recommended.append("Light Contact") }
//        
//        if recommended.isEmpty {
//            recommended.append("Breathing Control")
//            recommended.append("Slow Reading")
//        }
//        
//        loadExercises(exercises: recommended)
//    }

    func setupUIWithReport(_ report: StutterJSONReport) {
        
        // ✅ SAVE SESSION (only once)
        if !hasSavedSession {
            LogManager.shared.saveReadingSession(report: report)
            hasSavedSession = true
        }
        
        // 1. Score
        setupFluencyCircle(score: CGFloat(report.fluencyScore))
        
        // 2. Insight Message
        //insightsLabel.text = "Your /r/ and /s/ sounds have improved 12% today !!"
        
        // 2. Insight Message (Dynamic)
        Task {
            if let dayReport = await LogManager.shared.getDayReport(for: Date()) {
                await MainActor.run {
                    self.insightsLabel.text = dayReport.insight
                }
            } else {
                await MainActor.run {
                    self.insightsLabel.text = "You showed up and practiced — that matters."
                }
            }
        }
        
        // 3. Set Percentages & Time
        readingTime.text = report.duration
        blockPercentage.text = "\(Int(report.percentages.blocks))%"
        repetitionPercentage.text = "\(Int(report.percentages.repetition))%"
        prolongationPercentage.text = "\(Int(report.percentages.prolongation))%"
        
        // 4. Troubled Words
        loadTroubledWords(words: report.stutteredWords)
        
        // 5. Exercises
        var recommended: [String] = []
        if report.percentages.blocks > 5.0 { recommended.append("Easy Onset") }
        if report.percentages.repetition > 5.0 { recommended.append("Pull-outs") }
        if report.percentages.prolongation > 5.0 { recommended.append("Light Contact") }
        
        if recommended.isEmpty {
            recommended.append("Breathing Control")
            recommended.append("Slow Reading")
        }
        
        loadExercises(exercises: recommended)
        LogManager.shared.saveReadingSession(report: report)
        LogManager.shared.debugPrintAllReadingSessions()

    }

    
    func loadTroubledWords(words: [String]) {
        troubledWordsStackView.arrangedSubviews.forEach { view in
            if view is UIStackView || (view as? UILabel)?.text == "None! Great job." {
                view.removeFromSuperview()
            }
        }
        
        let cleanWords = words.filter({ !$0.isEmpty })
        
        if cleanWords.isEmpty {
            let label = UILabel()
            label.text = "None! Great job."
            label.textColor = .secondaryLabel
            label.font = UIFont.systemFont(ofSize: 14)
            troubledWordsStackView.addArrangedSubview(label)
            return
        }
        
        let maxPerRow = 3
        var currentRowStack: UIStackView?
        let displayWords = Array(cleanWords.prefix(9))
        
        for (index, word) in displayWords.enumerated() {
            if index % maxPerRow == 0 {
                currentRowStack = UIStackView()
                currentRowStack?.axis = .horizontal
                currentRowStack?.alignment = .leading
                currentRowStack?.distribution = .fillProportionally
                currentRowStack?.spacing = 12
                troubledWordsStackView.addArrangedSubview(currentRowStack!)
            }
            let chip = createChipLabel(text: word, textColor: customBrandBlue)
            currentRowStack?.addArrangedSubview(chip)
        }
        view.layoutIfNeeded()
    }
    
    func loadExercises(exercises: [String]) {
        exercisesStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let maxPerRow = 3
        var currentRowStack: UIStackView?
        
        for (index, exercise) in exercises.enumerated() {
            if index % maxPerRow == 0 {
                currentRowStack = UIStackView()
                currentRowStack?.axis = .horizontal
                currentRowStack?.alignment = .leading
                currentRowStack?.distribution = .fillProportionally
                currentRowStack?.spacing = 12
                exercisesStackView.addArrangedSubview(currentRowStack!)
            }
            let chip = createChipLabel(text: exercise, textColor: .systemGreen)
            currentRowStack?.addArrangedSubview(chip)
        }
    }
    
    func createChipLabel(text: String, textColor: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = textColor
        label.backgroundColor = textColor.withAlphaComponent(0.12)
        label.textAlignment = .center
        label.numberOfLines = 1
        label.layer.cornerRadius = 14
        label.layer.masksToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        label.heightAnchor.constraint(equalToConstant: 28).isActive = true
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.text = "  \(text)  "
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
