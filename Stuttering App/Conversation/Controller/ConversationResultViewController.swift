import UIKit

class ConversationResultViewController: UIViewController {
    
    @IBOutlet var exercisesStackView: UIStackView!
    @IBOutlet weak var troubledWordsStackView: UIStackView!
    @IBOutlet weak var insightsLabel: UILabel!
    @IBOutlet weak var fluencyCircleView: UIView!
    @IBOutlet weak var durationLabel: UILabel!
    
    var conversationDuration: Int = 0
    var stutterAnalysisJSON: String = ""
    
    private var analysisReport: StutterJSONReport?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = "Result"
        
        let closeButton = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(didTapCloseResult)
        )
        closeButton.tintColor = .label
        navigationItem.leftBarButtonItem = closeButton
        
        parseStutterAnalysis()
        setupUI()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let score = analysisReport?.fluencyScore ?? 60
        setupFluencyCircle(score: CGFloat(score))
    }
    
    private func parseStutterAnalysis() {
        print("=== PARSING STUTTER ANALYSIS ===")
        print("JSON Length: \(stutterAnalysisJSON.count)")
        
        guard !stutterAnalysisJSON.isEmpty,
              let jsonData = stutterAnalysisJSON.data(using: .utf8) else {
            print("No stutter analysis data available")
            return
        }
        
        let decoder = JSONDecoder()
        do {
            analysisReport = try decoder.decode(StutterJSONReport.self, from: jsonData)
            print("Successfully parsed stutter analysis:")
            if let report = analysisReport {
                print("   - Fluency Score: \(report.fluencyScore)")
                print("   - Duration: \(report.duration)")
                print("   - Stuttered Words: \(report.stutteredWords)")
                print("   - Blocks: \(report.blocks)")
                print("   - Repetitions: \(report.breakdown.repetition)")
                print("   - Prolongations: \(report.breakdown.prolongation)")
                print("   - Letter Analysis: \(report.letterAnalysis)")
            }
        } catch {
            print("Failed to parse stutter analysis: \(error)")
            print("Raw JSON: \(stutterAnalysisJSON)")
        }
    }
    
    private func setupUI() {
        let minutes = conversationDuration / 60
        let seconds = conversationDuration % 60
        durationLabel.text = minutes > 0 ? "\(minutes) min \(seconds) sec" : "\(seconds) sec"
        
        updateInsights()
        loadTroubledWords()
        loadExercises()
    }
    
    private func updateInsights() {
        guard let report = analysisReport else {
            insightsLabel.text = "Great job practicing your conversation skills!"
            return
        }
        
        let percentages = report.percentages
        
        var insights: [String] = []
        
        if percentages.correct >= 90 {
            insights.append("Excellent fluency! You're speaking very smoothly.")
        } else if percentages.correct >= 70 {
            insights.append("Good progress! Keep practicing to improve fluency.")
        } else {
            insights.append("You're building your skills. Consistent practice helps!")
        }
        
        if percentages.repetition > 10 {
            insights.append("Focus on reducing word repetitions.")
        }
        
        if percentages.prolongation > 10 {
            insights.append("Work on smooth sound transitions.")
        }
        
        if percentages.blocks > 5 {
            insights.append("Practice breathing techniques to reduce blocks.")
        }
        
        if let topLetter = report.letterAnalysis.max(by: { $0.value < $1.value }) {
            if topLetter.value >= 3 {
                insights.append("Words starting with '\(topLetter.key)' need attention.")
            }
        }
        
        insightsLabel.text = insights.isEmpty ? "Keep practicing!" : insights.joined(separator: " ")
    }
    
    func loadTroubledWords() {
        print("\n=== LOADING TROUBLED WORDS ===")
        
        guard let report = analysisReport else {
            print("No analysis report - loading defaults")
            loadDefaultTroubledWords()
            return
        }
        print("Raw stuttered words: \(report.stutteredWords)")

        let uniqueWords = Array(Set(report.stutteredWords))
        print("Unique words: \(uniqueWords)")
        
        let words = Array(uniqueWords.prefix(9))
        print("Display words (max 9): \(words)")
        
        if words.isEmpty {
            print("No stuttered words detected - loading defaults")
            loadDefaultTroubledWords()
            return
        }
        
        let maxPerRow = 3
        
        troubledWordsStackView.arrangedSubviews.forEach { view in
            if !(view is UILabel) {
                troubledWordsStackView.removeArrangedSubview(view)
                view.removeFromSuperview()
            }
        }
        
        var currentRowStack: UIStackView?
        
        for (index, word) in words.enumerated() {
            if index % maxPerRow == 0 {
                currentRowStack = UIStackView()
                currentRowStack?.axis = .horizontal
                currentRowStack?.alignment = .fill
                currentRowStack?.distribution = .fillEqually
                currentRowStack?.spacing = 8
                
                troubledWordsStackView.addArrangedSubview(currentRowStack!)
            }
            
            let chip = createChipLabel(text: word, textColor: .systemRed)
            currentRowStack?.addArrangedSubview(chip)
            print("Added chip for word: \(word)")
        }
        
        if let lastRow = currentRowStack {
            let itemsInLastRow = lastRow.arrangedSubviews.count
            let emptySlots = maxPerRow - itemsInLastRow
            
            for _ in 0..<emptySlots {
                let spacer = UIView()
                spacer.backgroundColor = .clear
                lastRow.addArrangedSubview(spacer)
            }
        }
        
        print("Finished loading troubled words UI")
    }
    
    private func loadDefaultTroubledWords() {
        let words = ResultData.troubledWordsArray
        let maxPerRow = 3
        
        troubledWordsStackView.arrangedSubviews.forEach { view in
            if !(view is UILabel) {
                troubledWordsStackView.removeArrangedSubview(view)
                view.removeFromSuperview()
            }
        }
        
        var currentRowStack: UIStackView?
        
        for (index, word) in words.enumerated() {
            if index % maxPerRow == 0 {
                currentRowStack = UIStackView()
                currentRowStack?.axis = .horizontal
                currentRowStack?.alignment = .fill
                currentRowStack?.distribution = .fillEqually
                currentRowStack?.spacing = 8
                
                troubledWordsStackView.addArrangedSubview(currentRowStack!)
            }
            
            let chip = createChipLabel(text: word, textColor: .systemBlue)
            currentRowStack?.addArrangedSubview(chip)
        }
        
        if let lastRow = currentRowStack {
            let itemsInLastRow = lastRow.arrangedSubviews.count
            let emptySlots = maxPerRow - itemsInLastRow
            
            for _ in 0..<emptySlots {
                let spacer = UIView()
                spacer.backgroundColor = .clear
                lastRow.addArrangedSubview(spacer)
            }
        }
    }
    
    func loadExercises() {
        guard let report = analysisReport else {
            loadDefaultExercises()
            return
        }
        
        var exercises: [String] = []
        let percentages = report.percentages
        
        if percentages.repetition > 10 {
            exercises.append("Slow speech")
            exercises.append("Pausing practice")
        }
        
        if percentages.prolongation > 10 {
            exercises.append("Gentle onset")
            exercises.append("Smooth transitions")
        }
        
        if percentages.blocks > 5 {
            exercises.append("Breathing control")
            exercises.append("Relaxation")
        }
        
        if percentages.correct >= 80 {
            exercises.append("Advanced fluency")
        }
        
        if exercises.isEmpty {
            exercises = ["Continue practice", "Build confidence", "Daily conversation"]
        }
        
        exercises = Array(exercises.prefix(9))
        
        displayExerciseChips(exercises)
    }
    
    private func loadDefaultExercises() {
        let exercises = ResultData.recommendedExercisesArray
        displayExerciseChips(exercises)
    }
    
    private func displayExerciseChips(_ exercises: [String]) {
        let maxPerRow = 3
        
        exercisesStackView.arrangedSubviews.forEach { view in
            if !(view is UILabel) {
                exercisesStackView.removeArrangedSubview(view)
                view.removeFromSuperview()
            }
        }
        
        var currentRowStack: UIStackView?
        
        for (index, exercise) in exercises.enumerated() {
            if index % maxPerRow == 0 {
                currentRowStack = UIStackView()
                currentRowStack?.axis = .horizontal
                currentRowStack?.alignment = .fill
                currentRowStack?.distribution = .fillEqually
                currentRowStack?.spacing = 8
                
                exercisesStackView.addArrangedSubview(currentRowStack!)
            }
            
            let chip = createChipLabel(text: exercise, textColor: .systemGreen)
            currentRowStack?.addArrangedSubview(chip)
        }
        
        if let lastRow = currentRowStack {
            let itemsInLastRow = lastRow.arrangedSubviews.count
            let emptySlots = maxPerRow - itemsInLastRow
            
            for _ in 0..<emptySlots {
                let spacer = UIView()
                spacer.backgroundColor = .clear
                lastRow.addArrangedSubview(spacer)
            }
        }
    }
    
    func createChipLabel(text: String, textColor: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = textColor
        label.backgroundColor = textColor.withAlphaComponent(0.15)
        label.textAlignment = .center
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        
        label.layer.cornerRadius = 16
        label.layer.masksToBounds = true
        
        label.translatesAutoresizingMaskIntoConstraints = false
        label.heightAnchor.constraint(equalToConstant: 32).isActive = true
        
        return label
    }
    
    func setupFluencyCircle(score: CGFloat) {
        fluencyCircleView.layer.sublayers?.forEach { layer in
            if layer is CAShapeLayer {
                layer.removeFromSuperlayer()
            }
        }
        fluencyCircleView.subviews.forEach { $0.removeFromSuperview() }
        
        let center = CGPoint(
            x: fluencyCircleView.bounds.midX,
            y: fluencyCircleView.bounds.midY
        )
        
        let radius: CGFloat = min(
            fluencyCircleView.bounds.width,
            fluencyCircleView.bounds.height
        ) / 2 - 25
        
        let lineWidth: CGFloat = 20
        
        let circlePath = UIBezierPath(
            arcCenter: center,
            radius: radius,
            startAngle: -.pi / 2,
            endAngle: 1.5 * .pi,
            clockwise: true
        )
        
        // Background circle
        let backgroundCircle = CAShapeLayer()
        backgroundCircle.path = circlePath.cgPath
        backgroundCircle.strokeColor = UIColor.systemGray5.cgColor
        backgroundCircle.lineWidth = lineWidth
        backgroundCircle.fillColor = UIColor.clear.cgColor
        backgroundCircle.lineCap = .round
        fluencyCircleView.layer.addSublayer(backgroundCircle)
        
        // Progress circle
        let progressCircle = CAShapeLayer()
        progressCircle.path = circlePath.cgPath
        progressCircle.strokeColor = UIColor.systemBlue.cgColor
        progressCircle.lineWidth = lineWidth
        progressCircle.fillColor = UIColor.clear.cgColor
        progressCircle.lineCap = .round
        progressCircle.strokeEnd = 0
        fluencyCircleView.layer.addSublayer(progressCircle)
        
        // Animate
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.toValue = score / 100
        animation.duration = 1.2
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        progressCircle.add(animation, forKey: "progressAnim")
        
        // Score label
        let scoreLabel = UILabel(frame: fluencyCircleView.bounds)
        scoreLabel.text = "\(Int(score))"
        scoreLabel.textAlignment = .center
        scoreLabel.font = UIFont.systemFont(ofSize: 48, weight: .bold)
        scoreLabel.textColor = .label
        fluencyCircleView.addSubview(scoreLabel)
    }
    
    @objc func didTapCloseResult() {
        dismiss(animated: true, completion: nil)
    }
}
