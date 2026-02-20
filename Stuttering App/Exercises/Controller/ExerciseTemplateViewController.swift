//
//  ExerciseTemplateViewController.swift
//  Stuttering App 1
//
//  Fixed: Enabled dynamic word fetching for Traditional and Text-Only exercises.
//

import UIKit

class ExerciseTemplateViewController: UIViewController, ExerciseStarting, UISheetPresentationControllerDelegate {
    
    enum TransitionDirection {
        case forward
        case backward
    }
    
    var startingSource: ExerciseSource?
    var exerciseName: String = ""
    
    private let sessionTotalTime: TimeInterval = 120.0
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var imageContainerStackView: UIView!
    @IBOutlet weak var stepImageView: UIImageView!
    @IBOutlet weak var stepLabel: UILabel!
    @IBOutlet weak var instructionLabel: UILabel!
    @IBOutlet weak var targetWordLabel: UILabel!
    @IBOutlet weak var progressBarView: ProgressBarView!
    @IBOutlet weak var dashboardBottomConstraint: NSLayoutConstraint!
    
    private var currentExercise: LibraryExercises?
    private var heartbeatTimer: Timer?
    var isPaused: Bool = false
    private let timeInterval: TimeInterval = 0.05
    
    var sessionTimeRemaining: TimeInterval = 120.0
    var currentStepTimeRemaining: TimeInterval = 0.0
    var currentStepTotalTime: TimeInterval = 0.0
    
    private var sortedCategoryKeys: [String] = []
    private var currentCategoryIndex: Int = 0
    private var currentStepIndex: Int = 0
    private var currentWord: String = ""
    
    weak var sheetVC: ControlsTemplateViewController?
    
    private var animationController: AnimationController!
    private var exerciseTemplate: ExerciseAnimationTemplate?
    private var isAnimatingStep: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setupAnimationController()
        setupDesign()
        loadData()
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presentWorkoutSheet()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        killTimer()
        animationController.cancelAnimations()
        sheetVC?.dismiss(animated: true)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }
    
    private func setupAnimationController() {
        animationController = AnimationController()
        animationController.delegate = self
    }
    
    private func setupDesign() {
        targetWordLabel.adjustsFontSizeToFitWidth = true
        targetWordLabel.minimumScaleFactor = 0.4
        targetWordLabel.numberOfLines = 2
        targetWordLabel.lineBreakMode = .byTruncatingTail
        targetWordLabel.textAlignment = .center
        targetWordLabel.isHidden = true
        targetWordLabel.font = .systemFont(ofSize: 48, weight: .bold)
        targetWordLabel.textColor = UIColor(named: "ButtonTheme")
        
        stepLabel.font = .systemFont(ofSize: 20, weight: .bold)
        
        instructionLabel.font = .preferredFont(forTextStyle: .headline)
        instructionLabel.textColor = .systemGray
        instructionLabel.numberOfLines = 0
        instructionLabel.textAlignment = .center
        
        stepImageView.contentMode = .scaleAspectFit
        stepImageView.tintColor = .systemGray3
        
        progressBarView.barHeight = 10
        progressBarView.progressColor = UIColor(named: "ButtonTheme") ?? .systemBlue
        progressBarView.progress = 0.0
        
        dashboardBottomConstraint.constant = view.bounds.height * 0.19
    }
    
    private func loadData() {
        if let exercise = ExerciseManager.fetchExercise(title: exerciseName) {
            self.currentExercise = exercise
            self.exerciseTemplate = ExerciseAnimationRegistry.shared.getTemplate(for: exerciseName)
            
            let targets = exercise.dataBank.targets
            sortedCategoryKeys = targets.keys.sorted()
            
            startNewWordCycle()
            startHeartbeat()
        }
    }
    
    func startHeartbeat() {
        killTimer()
        isPaused = false
        
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    
    func pauseHeartbeat() {
        killTimer()
        isPaused = true
    }
    
    func killTimer() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
    
    private func tick() {
        sessionTimeRemaining -= timeInterval
        currentStepTimeRemaining -= timeInterval
        
        syncDataToSheet()
        
        if sessionTimeRemaining <= 0 {
            finishSession()
            return
        }
        
        if !isAnimatingStep && currentStepTimeRemaining <= 0 {
            advanceStep()
        }
    }
    
    // MARK: - Word Cycle Management (FIXED)
    func startNewWordCycle() {
        guard let exercise = currentExercise else { return }
        
        // FIXED: Removed the logic that forced textOnly/imageBased to skip fetching.
        // Now ALL exercises fetch from dataBank if keys exist.
        
        if !sortedCategoryKeys.isEmpty {
            let keyIndex = currentCategoryIndex % sortedCategoryKeys.count
            let categoryKey = sortedCategoryKeys[keyIndex]
            
            if let words = exercise.dataBank.targets[categoryKey], let randomWord = words.randomElement() {
                currentWord = randomWord
            } else {
                // Fallback 1: Try first key
                if let firstKey = sortedCategoryKeys.first,
                   let words = exercise.dataBank.targets[firstKey],
                   let randomWord = words.randomElement() {
                    currentWord = randomWord
                } else {
                    // Fallback 2: Use example demonstration if dataBank fails
                    currentWord = exercise.exampleDemonstration.first?.displayText ?? "Ready"
                }
            }
            currentCategoryIndex += 1
        } else {
            // No data bank (rare), use example
            currentWord = exercise.exampleDemonstration.first?.displayText ?? "Ready"
        }
        
        currentStepIndex = 0
        loadStepUI()
    }
    
    private func advanceStep() {
        guard let exercise = currentExercise else { return }
        
        animationController.cancelAnimations()
        
        if currentStepIndex < exercise.instructionSet.steps.count - 1 {
            currentStepIndex += 1
            transitionToStep(at: currentStepIndex, direction: .forward)
        } else {
            startNewWordCycle()
        }
    }
    
    private func transitionToStep(at index: Int, direction: TransitionDirection) {
        guard let containerView = contentStackView.superview else {
            loadStepUI()
            return
        }
        
        containerView.clipsToBounds = true
        
        guard let snapshot = contentStackView.snapshotView(afterScreenUpdates: false) else {
            loadStepUI()
            return
        }
        
        snapshot.frame = contentStackView.frame
        containerView.addSubview(snapshot)
        
        let offset = containerView.frame.width
        let startTransform = CGAffineTransform(translationX: direction == .forward ? offset : -offset, y: 0)
        let exitTransform = CGAffineTransform(translationX: direction == .forward ? -offset : offset, y: 0)
        
        contentStackView.transform = startTransform
        contentStackView.alpha = 0
        
        loadStepUI()
        containerView.layoutIfNeeded()
        
        UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseInOut, animations: {
            snapshot.transform = exitTransform
            snapshot.alpha = 0
            
            self.contentStackView.transform = .identity
            self.contentStackView.alpha = 1
        }) { _ in
            snapshot.removeFromSuperview()
        }
    }
    
    private func loadStepUI() {
        guard let exercise = currentExercise else { return }
        let step = exercise.instructionSet.steps[currentStepIndex]
        let currentStepNumber = currentStepIndex + 1
        
        stepLabel.text = "\(step.label)"
        instructionLabel.text = step.text
        
        currentStepTotalTime = Double(step.time)
        currentStepTimeRemaining = currentStepTotalTime
        
        let progress = CGFloat(currentStepNumber) / CGFloat(exercise.instructionSet.steps.count)
        progressBarView.setProgress(progress, animated: true)
        
        if let template = exerciseTemplate {
            handleAnimatedExercise(template: template, stepNumber: currentStepNumber, step: step)
        } else {
            handleTraditionalExercise(step: step)
        }
    }
    
    // MARK: - Exercise Handlers (FIXED)
    private func handleAnimatedExercise(template: ExerciseAnimationTemplate, stepNumber: Int, step: ExerciseStep) {
        guard let exercise = currentExercise else { return }
        
        // Text-only exercises (Toolkit, Tongue Twisters)
        if template.exerciseType == .textOnly {
            handleTextOnlyExercise(step: step)
            return
        }
        
        // Image-based exercises with empty configs (Airflow, Light Contacts)
        if template.stepConfigs.isEmpty {
            handleTraditionalExercise(step: step)
            return
        }
        
        // Animation-based and hybrid exercises (Prolongation, Gentle Onset)
        if let stepConfig = template.stepConfigs.first(where: { $0.stepNumber == stepNumber }) {
            
            if stepConfig.showImage {
                // Show image
                showImage(step.image)
                
                // Use currentWord instead of rawText from example
                let textToDisplay = currentWord.isEmpty ? (exercise.exampleDemonstration.first?.displayText ?? "") : currentWord
                
                if textToDisplay.contains("'") || textToDisplay.contains(" ") {
                    targetWordLabel.attributedText = formatToolkitSentence(textToDisplay)
                } else {
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 48, weight: .bold),
                        .foregroundColor: UIColor(named: "ButtonTheme") ?? .systemBlue
                    ]
                    targetWordLabel.attributedText = NSAttributedString(string: textToDisplay, attributes: attributes)
                }
                
                let shouldShowLabel = (stepNumber >= exercise.wordStartStep)
                updateStackLayout(imageViewHidden: false, labelHidden: !shouldShowLabel)
                
                isAnimatingStep = false
                
            } else {
                // Show animated syllable text
                updateStackLayout(imageViewHidden: true)
                isAnimatingStep = true
                animationController.startAnimation(for: stepConfig, word: currentWord)
            }
            
        } else {
            // Fallback for steps not defined in config
            handleTraditionalExercise(step: step)
        }
    }
    
    private func handleTextOnlyExercise(step: ExerciseStep) {
        guard let exercise = currentExercise else { return }
        
        updateStackLayout(imageViewHidden: true, labelHidden: false)
        
        // FIXED: Use currentWord fetched from DataBank
        let textToDisplay = currentWord.isEmpty ? (exercise.exampleDemonstration.first?.displayText ?? "") : currentWord
        
        targetWordLabel.attributedText = formatToolkitSentence(textToDisplay)
        
        targetWordLabel.isHidden = false
        targetWordLabel.alpha = 1.0
        
        isAnimatingStep = false
    }
    
    private func handleTraditionalExercise(step: ExerciseStep) {
        guard let exercise = currentExercise else { return }
        
        showImage(step.image)
        
        // FIXED: Use currentWord fetched from DataBank
        let textToDisplay = currentWord.isEmpty ? (exercise.exampleDemonstration.first?.displayText ?? "") : currentWord
        
        // Check if it's a sentence (contains quotes or spaces) or a single word
        if textToDisplay.contains("'") || textToDisplay.contains(" ") {
            // It's a sentence - format it
            targetWordLabel.attributedText = formatToolkitSentence(textToDisplay)
        } else {
            // It's a single word - display as plain text with theme color
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 48, weight: .bold),
                .foregroundColor: UIColor(named: "ButtonTheme") ?? .systemBlue
            ]
            targetWordLabel.attributedText = NSAttributedString(string: textToDisplay, attributes: attributes)
        }
        
        let isTargetStep = (step.stepNumber >= exercise.wordStartStep)
        updateStackLayout(imageViewHidden: false, labelHidden: !isTargetStep)
        
        isAnimatingStep = false
    }
    
    private func showImage(_ imageName: String) {
        stepImageView.isHidden = false
        if !imageName.isEmpty {
            stepImageView.image = UIImage(named: imageName)
        } else {
            stepImageView.image = UIImage(systemName: "figure.mind.and.body")
        }
    }
    
    private func updateStackLayout(imageViewHidden: Bool, labelHidden: Bool? = nil) {
        if imageViewHidden {
            self.imageContainerStackView.isHidden = true
            self.stepImageView.isHidden = true
        } else {
            self.imageContainerStackView.isHidden = false
            self.stepImageView.isHidden = false
        }
        
        if let labelHide = labelHidden {
            targetWordLabel.isHidden = labelHide
            targetWordLabel.alpha = labelHide ? 0.0 : 1.0
        }
        
        UIView.animate(withDuration: 0.3) {
            self.imageContainerStackView.alpha = imageViewHidden ? 0.0 : 1.0
            self.contentStackView.layoutIfNeeded()
        }
    }
    
    private func formatToolkitSentence(_ text: String) -> NSAttributedString {
        let fullString = NSMutableAttributedString()
        let components = text.components(separatedBy: "'")
        
        // Reduced size slightly for long sentences
        let baseSize: CGFloat = text.count > 20 ? 23 : 30
        let highlightedSize: CGFloat = text.count > 20 ? 28 : 35
        
        let regularAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: baseSize, weight: .bold),
            .foregroundColor: UIColor.label
        ]
        
        let highlightAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: highlightedSize, weight: .bold),
            .foregroundColor: UIColor(named: "ButtonTheme") ?? .systemBlue
        ]
        
        for (i, part) in components.enumerated() {
            fullString.append(NSAttributedString(string: part, attributes: (i % 2 == 0) ? regularAttributes : highlightAttributes))
        }
        
        return fullString
    }

    private func finishSession() {
        killTimer()
        animationController.cancelAnimations()
        sheetVC?.updateTimerLabel(text: "00:00")
        
        let alert = UIAlertController(title: "Session Complete", message: "Great work!", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Finish", style: .default, handler: { _ in
            self.sheetVC?.dismiss(animated: true)
            self.didTapStop()
        }))
        present(alert, animated: true)
    }
}

// MARK: - Animation Delegate
extension ExerciseTemplateViewController: AnimationControllerDelegate {
    
    func didUpdateText(_ attributedText: NSAttributedString) {
        UIView.transition(
            with: targetWordLabel,
            duration: 0.3,
            options: .transitionCrossDissolve,
            animations: {
                self.targetWordLabel.attributedText = attributedText
            }
        )
    }
    
    func didCompleteStep(shouldAutoAdvance: Bool) {
        isAnimatingStep = false
    }
    
    func shouldHideTargetLabel(_ hide: Bool) {
        UIView.animate(withDuration: 0.3) {
            self.targetWordLabel.alpha = hide ? 0.0 : 1.0
            self.targetWordLabel.isHidden = hide
        }
    }
}

// MARK: - Sheet Delegate
extension ExerciseTemplateViewController: AirFlowControlsDelegate {

    func presentWorkoutSheet() {
        guard let sheetVC = storyboard?.instantiateViewController(withIdentifier: "AirFlowControlsViewController") as? ControlsTemplateViewController else { return }
        
        sheetVC.delegate = self
        self.sheetVC = sheetVC
        sheetVC.isModalInPresentation = true
        
        if let sheet = sheetVC.sheetPresentationController {
            sheet.delegate = self
            sheet.detents = [
                .custom(identifier: .init("quarter")) { context in 0.20 * context.maximumDetentValue },
                .custom(identifier: .init("half")) { context in 0.35 * context.maximumDetentValue }
            ]
            sheet.selectedDetentIdentifier = .init("quarter")
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            sheet.largestUndimmedDetentIdentifier = .init("quarter")
            sheet.preferredCornerRadius = 20
        }
        
        sheetVC.view.layer.cornerRadius = 20
        sheetVC.view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        sheetVC.view.clipsToBounds = true
        
        present(sheetVC, animated: true)
    }
    
    func didTapPlayPause() {
        if isPaused {
            startHeartbeat()
            sheetVC?.setPlayPauseState(isPlaying: true)
            if let sheet = sheetVC?.sheetPresentationController {
                sheet.animateChanges { sheet.selectedDetentIdentifier = .init("quarter") }
                sheetVC?.setExpandedState(isExpanded: false)
            }
        } else {
            pauseHeartbeat()
            sheetVC?.setPlayPauseState(isPlaying: false)
            if let sheet = sheetVC?.sheetPresentationController {
                sheet.animateChanges { sheet.selectedDetentIdentifier = .init("half") }
                sheetVC?.setExpandedState(isExpanded: true)
            }
        }
    }
    
    func didTapNextWord() {
        startNewWordCycle()
    }
    
    func didTapStop() {
        killTimer()
        animationController.cancelAnimations()
        self.dismiss(animated: true, completion: nil)
        
        guard let source = startingSource else { return }
        
        LogManager.shared.addLog(
            exerciseName: self.exerciseName,
            source: source,
            exerciseDuration: Int(self.sessionTotalTime)
        )
        
        if source == .dailyTasks {
            DatabaseManager.shared.markTaskComplete(taskName: self.exerciseName)
        }
        
        let storyboard = UIStoryboard(name: "Exercise", bundle: nil)
        guard let ResultVC = storyboard.instantiateViewController(withIdentifier: "ExerciseResult") as? ExerciseResultViewController else { return }
        
        ResultVC.exerciseName = self.exerciseName
        ResultVC.durationLabelForExercise = Int(self.sessionTotalTime)
        
        let ResultNav = UINavigationController(rootViewController: ResultVC)
        ResultNav.modalPresentationStyle = .fullScreen
        self.present(ResultNav, animated: true, completion: nil)
    }
    
    func syncDataToSheet() {
        guard let sheet = self.sheetVC else { return }
        let time = max(sessionTimeRemaining, 0)
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let timeString = String(format: "%02d:%02d", minutes, seconds)
        sheet.updateTimerLabel(text: timeString)
    }
    
    func sheetPresentationControllerDidChangeSelectedDetentIdentifier(_ sheet: UISheetPresentationController) {
        guard let identifier = sheet.selectedDetentIdentifier else { return }
        let isExpanded = (identifier == .init("half"))
        sheetVC?.setExpandedState(isExpanded: isExpanded)
        
        if isExpanded && !isPaused { didTapPlayPause() }
        else if !isExpanded && isPaused { didTapPlayPause() }
    }
}
