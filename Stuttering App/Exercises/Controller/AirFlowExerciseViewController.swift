//
//  AirFlowExerciseViewController.swift
//  Stuttering App 1
//
//  Updated with modular animation system
//

import UIKit

class AirFlowExerciseViewController: UIViewController, ExerciseStarting {
    
    var startingSource: ExerciseSource?
    var exerciseName: String = ""
    
    private let sessionTotalTime: TimeInterval = 120.0
    
    @IBOutlet weak var stepImageView: UIImageView!
    @IBOutlet weak var stepLabel: UILabel!
    @IBOutlet weak var instructionLabel: UILabel!
    @IBOutlet weak var targetWordLabel: UILabel!
    
    @IBOutlet weak var targetLabelBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var targetLabelCenterYConstraint: NSLayoutConstraint!
    
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
    
    weak var sheetVC: AirFlowControlsViewController?
    
    private var animationController: AnimationController!
    private var exerciseTemplate: ExerciseAnimationTemplate?
    private var isAnimatingStep: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setupAnimationController()
        setupDesign()
        loadData()
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
        targetWordLabel.textColor = .systemIndigo
        
        stepLabel.font = .systemFont(ofSize: 20, weight: .bold)
        
        instructionLabel.font = .systemFont(ofSize: 17, weight: .medium)
        instructionLabel.numberOfLines = 0
        instructionLabel.textAlignment = .center
        
        stepImageView.contentMode = .scaleAspectFit
        stepImageView.tintColor = .systemGray3
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
        
        // Don't auto-advance if animation is playing
        if !isAnimatingStep && currentStepTimeRemaining <= 0 {
            advanceStep()
        }
    }
    
    func startNewWordCycle() {
        guard let exercise = currentExercise, !sortedCategoryKeys.isEmpty else { return }
        
        let keyIndex = currentCategoryIndex % sortedCategoryKeys.count
        let categoryKey = sortedCategoryKeys[keyIndex]
        
        if let words = exercise.dataBank.targets[categoryKey], let randomWord = words.randomElement() {
            currentWord = randomWord
        } else {
            currentWord = "Ready"
        }
        
        currentCategoryIndex += 1
        currentStepIndex = 0
        
        loadStepUI()
    }
    
    private func advanceStep() {
        guard let exercise = currentExercise else { return }
        
        // Cancel ongoing animations
        animationController.cancelAnimations()
        
        if currentStepIndex < exercise.instructionSet.steps.count - 1 {
            currentStepIndex += 1
            loadStepUI()
        } else {
            startNewWordCycle()
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
        
        if let template = exerciseTemplate {
            handleAnimatedExercise(template: template, stepNumber: currentStepNumber, step: step)
        } else {
            handleTraditionalExercise(step: step)
        }
    }
    
    private func handleAnimatedExercise(template: ExerciseAnimationTemplate, stepNumber: Int, step: ExerciseStep) {
        // Check for text-only exercise (3.1, 3.2, 3.3)
        if template.exerciseType == .textOnly {
            handleTextOnlyExercise(step: step)
            return
        }
        
        // Find configuration for this step
        if let stepConfig = template.stepConfigs.first(where: { $0.stepNumber == stepNumber }) {
            
            // Update layout constraints based on whether image is shown
            updateLayoutConstraints(showImage: stepConfig.showImage)
            
            if stepConfig.showImage {
                // Show image, hide text
                showImage(step.image)
                targetWordLabel.isHidden = true
                isAnimatingStep = false
            } else {
                // Hide image, show animated text
                stepImageView.isHidden = true
                isAnimatingStep = true
                
                // Start animation sequence
                animationController.startAnimation(for: stepConfig, word: currentWord)
            }
        } else {
            // No config for this step, treat as traditional
            handleTraditionalExercise(step: step)
        }
    }
    
    private func handleTextOnlyExercise(step: ExerciseStep) {
        guard let exercise = currentExercise else { return }
        
        // Hide image, center the text
        updateLayoutConstraints(showImage: false)
        stepImageView.isHidden = true
        
        // Get the sentence data from example demonstration
        let rawText = exercise.exampleDemonstration.first?.displayText ?? currentWord
        
        // Apply sentence formatting with highlighted word
        targetWordLabel.attributedText = formatToolkitSentence(rawText)
        
        // ALWAYS show text for text-only exercises (visible in all steps)
        UIView.animate(withDuration: 0.3) {
            self.targetWordLabel.alpha = 1.0
            self.targetWordLabel.isHidden = false
        }
        
        isAnimatingStep = false
    }
    
    private func handleTraditionalExercise(step: ExerciseStep) {
        guard let exercise = currentExercise else { return }
        
        // Traditional image-based flow
        updateLayoutConstraints(showImage: true)
        showImage(step.image)
        
        // Get the text from example demonstration
        let rawText = exercise.exampleDemonstration.first?.displayText ?? currentWord
        
        // Apply sentence formatting with highlighted word
        targetWordLabel.attributedText = formatToolkitSentence(rawText)
        
        // Show text at the target step along with the image
        let isTargetStep = (step.stepNumber == exercise.wordStartStep)
        
        UIView.animate(withDuration: 0.3) {
            self.targetWordLabel.alpha = isTargetStep ? 1.0 : 0.0
            self.targetWordLabel.isHidden = !isTargetStep
        }
        
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
    
    private func updateLayoutConstraints(showImage: Bool) {
        if showImage {
            // Image Mode: Label at bottom, image visible
            targetLabelCenterYConstraint?.isActive = false
            targetLabelBottomConstraint?.isActive = true
        } else {
            // Centered Mode: Label vertically centered, no image
            targetLabelBottomConstraint?.isActive = false
            targetLabelCenterYConstraint?.isActive = true
        }
        
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
    
    private func formatToolkitSentence(_ text: String) -> NSAttributedString {
        let fullString = NSMutableAttributedString()
        
        // Split text by single quote "'"
        let components = text.components(separatedBy: "'")
        
        // Use a smaller base font for sentences
        let baseSize: CGFloat = 20
        let highlightedSize: CGFloat = 22
        let regularAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: baseSize, weight: .medium),
            .foregroundColor: UIColor.label
        ]
        
        let highlightAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: highlightedSize, weight: .bold),
            .foregroundColor: UIColor.systemIndigo
        ]
        
        for (i, part) in components.enumerated() {
            // Even index parts are outside quotes (Normal)
            // Odd index parts are inside quotes (Highlighted)
            if i % 2 == 0 {
                fullString.append(NSAttributedString(string: part, attributes: regularAttributes))
            } else {
                fullString.append(NSAttributedString(string: part, attributes: highlightAttributes))
            }
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

extension AirFlowExerciseViewController: AnimationControllerDelegate {
    
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
        
        if shouldAutoAdvance {
            // Auto-advance after animation completes
            // The timer will handle advancing after currentStepTimeRemaining hits 0
            // Or you can manually advance here if preferred
        }
    }
    
    func shouldHideTargetLabel(_ hide: Bool) {
        UIView.animate(withDuration: 0.3) {
            self.targetWordLabel.alpha = hide ? 0.0 : 1.0
            self.targetWordLabel.isHidden = hide
        }
    }
}

extension AirFlowExerciseViewController: AirFlowControlsDelegate {

    func presentWorkoutSheet() {
        guard let sheetVC = storyboard?.instantiateViewController(withIdentifier: "AirFlowControlsViewController") as? AirFlowControlsViewController else { return }
        
        sheetVC.delegate = self
        self.sheetVC = sheetVC
        
        sheetVC.isModalInPresentation = true
        
        if let sheet = sheetVC.sheetPresentationController {
            sheet.detents = [
                .custom(identifier: .init("quarter")) { context in 0.25 * context.maximumDetentValue },
                .custom(identifier: .init("half")) { context in 0.45 * context.maximumDetentValue }
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
        } else {
            pauseHeartbeat()
            sheetVC?.setPlayPauseState(isPlaying: false)
        }
    }
    
    func didTapNextWord() {
        startNewWordCycle()
    }
    
    func didTapStop() {
        killTimer()
        animationController.cancelAnimations()
        self.dismiss(animated: true, completion: nil)
        
        guard let source = startingSource else {
            print("Error: Source is nil. Dismissing.")
            self.dismiss(animated: true)
            return
        }
        
        LogManager.shared.addLog(
            exerciseName: self.exerciseName,
            source: source,
            exerciseDuration: Int(self.sessionTotalTime)
        )
        
        DatabaseManager.shared.markTaskComplete(taskName: self.exerciseName)
        
        let storyboard = UIStoryboard(name: "Exercise", bundle: nil)
        guard let ResultVC = storyboard.instantiateViewController(withIdentifier: "ExerciseResult") as? ExerciseResultViewController else {
            return
        }
        
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
        
        let progress = CGFloat(max(currentStepTimeRemaining / currentStepTotalTime, 0.0))
        sheet.updateProgress(value: progress)
    }
}
