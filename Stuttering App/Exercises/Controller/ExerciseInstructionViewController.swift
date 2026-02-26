//
//  ExerciseInstructionViewController.swift
//  Stuttering App 1
//
//  Fixed: Proper fetching of example/word for instruction steps
//

import UIKit

class ExerciseInstructionViewController: UIViewController, ExerciseStarting {
    
    enum TransitionDirection {
        case forward
        case backward
    }
    
    var startingSource: ExerciseSource?
    var exerciseName = ""
    var targetWord = ""

    private var currentExercise: LibraryExercises?
    private var currentStepIndex: Int = 0
    private var steps: [ExerciseStep] = []
    
    private var animationController: AnimationController!
    private var exerciseTemplate: ExerciseAnimationTemplate?
    private var currentWord: String = ""

    @IBOutlet weak var stepLabel: UILabel!
    @IBOutlet weak var stepImageView: UIImageView!
    @IBOutlet weak var stepTextLabel: UILabel!
    @IBOutlet weak var targetWordLabel: UILabel!
    @IBOutlet weak var progressView: ProgressBarView!
    
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var prevButton: UIButton!
    @IBOutlet weak var skipButton: UIButton!
    @IBOutlet weak var bottomViewConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var imageContainerStackView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupAnimationController()
        setupDesign()
        loadExerciseData()
        setupInitialState()
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
        
        stepTextLabel.font = .systemFont(ofSize: 17, weight: .medium)
        stepTextLabel.numberOfLines = 0
        stepTextLabel.textAlignment = .center
        
        progressView.barHeight = 10
        progressView.progressColor = UIColor(named: "ButtonTheme") ?? .systemBlue
        progressView.progress = 0.0
        
        skipButton.configuration = .glass()
        skipButton.setTitle("Skip Instructions", for: .normal)
        
        var config = UIButton.Configuration.prominentGlass()
        config.title = "Next"
        config.baseBackgroundColor = UIColor(named: "ButtonTheme")
        nextButton.configuration = config
        
        var config1 = UIButton.Configuration.prominentGlass()
        config1.title = "Previous"
        config1.baseBackgroundColor = UIColor(named: "ButtonTheme")
        prevButton.configuration = config1
    }
    
    private func setupInitialState() {
        prevButton.isHidden = true
        prevButton.alpha = 0
    }

    private func loadExerciseData() {
        guard let exercise = ExerciseManager.fetchExercise(title: exerciseName) else { return }
        self.currentExercise = exercise
        self.steps = exercise.instructionSet.steps
        
        self.exerciseTemplate = ExerciseAnimationRegistry.shared.getTemplate(for: exerciseName)
        
        loadWordData(from: exercise)
        updateUIForStep(at: 0)
    }
    
    private func loadWordData(from exercise: LibraryExercises) {
        // FIXED: Try to fetch a random word for ALL exercise types, fallback to Example.
        
        let targets = exercise.dataBank.targets
        let categoryKeys = targets.keys.sorted()
        
        if let firstKey = categoryKeys.first,
           let words = targets[firstKey],
           let randomWord = words.randomElement() {
            currentWord = randomWord
        } else {
            // Fallback to example demonstration if dataBank is empty
            currentWord = exercise.exampleDemonstration.first?.displayText ?? "Ready"
        }
    }

    private func updateUIForStep(at index: Int) {
        guard let exercise = currentExercise, index < steps.count else { return }
        
        let step = steps[index]
        let currentStepNumber = index + 1
        
        stepLabel.text = "\(step.label)"
        stepTextLabel.text = step.text
        
        let progress = CGFloat(currentStepNumber) / CGFloat(steps.count)
        progressView.setProgress(progress, animated: true)
        
        nextButton.configuration?.title = (index == steps.count - 1) ? "Complete" : "Next"
        
        if let template = exerciseTemplate {
            handleAnimatedExercise(template: template, stepNumber: currentStepNumber, step: step)
        } else {
            handleTraditionalExercise(step: step)
        }
    }
    
    private func transitionToStep(at index: Int, direction: TransitionDirection) {
        guard let containerView = contentStackView.superview else {
            updateUIForStep(at: index)
            return
        }
        
        containerView.clipsToBounds = true
        
        guard let snapshot = contentStackView.snapshotView(afterScreenUpdates: false) else {
            updateUIForStep(at: index)
            return
        }
        
        snapshot.frame = contentStackView.frame
        containerView.addSubview(snapshot)
        
        let offset = containerView.frame.width
        let startTransform = CGAffineTransform(translationX: direction == .forward ? offset : -offset, y: 0)
        let exitTransform = CGAffineTransform(translationX: direction == .forward ? -offset : offset, y: 0)
        
        contentStackView.transform = startTransform
        contentStackView.alpha = 0
        
        updateUIForStep(at: index)
        
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
    
    // MARK: - Exercise Handlers (FIXED)
    private func handleTextOnlyExercise(step: ExerciseStep) {
        guard let _ = currentExercise else { return }
        
        updateStackLayout(imageViewHidden: true, labelHidden: false)

        // FIXED: Use loaded currentWord
        targetWordLabel.attributedText = formatToolkitSentence(currentWord)
        
        self.targetWordLabel.isHidden = false
        self.targetWordLabel.alpha = 1.0
    }
    
    private func handleAnimatedExercise(template: ExerciseAnimationTemplate, stepNumber: Int, step: ExerciseStep) {
        guard let exercise = currentExercise else { return }
        
        // Text-only exercises
        if template.exerciseType == .textOnly {
            handleTextOnlyExercise(step: step)
            return
        }
        
        // Image-based exercises with empty configs
        if template.stepConfigs.isEmpty {
            handleTraditionalExercise(step: step)
            return
        }
        
        // Animation-based and hybrid exercises
        if let stepConfig = template.stepConfigs.first(where: { $0.stepNumber == stepNumber }) {
            
            if stepConfig.showImage {
                // Show image with optional text
                showImage(step.image)
                
                // Check if it's a sentence or single word
                if currentWord.contains("'") || currentWord.contains(" ") {
                    targetWordLabel.attributedText = formatToolkitSentence(currentWord)
                } else {
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 48, weight: .bold),
                        .foregroundColor: UIColor(named: "ButtonTheme") ?? .systemBlue
                    ]
                    targetWordLabel.attributedText = NSAttributedString(string: currentWord, attributes: attributes)
                }
                
                let shouldShowLabel = (stepNumber >= exercise.wordStartStep)
                updateStackLayout(imageViewHidden: false, labelHidden: !shouldShowLabel)
                
            } else {
                // Show animated syllable text
                updateStackLayout(imageViewHidden: true)
                animationController.startAnimation(for: stepConfig, word: currentWord)
                if stepConfig.autoAdvance { nextButton.isEnabled = false }
            }

        } else {
            handleTraditionalExercise(step: step)
        }
    }

    private func handleTraditionalExercise(step: ExerciseStep) {
        guard let exercise = currentExercise else { return }
        
        showImage(step.image)
        
        // Check if it's a sentence (contains quotes or spaces) or a single word
        if currentWord.contains("'") || currentWord.contains(" ") {
            // It's a sentence - format it
            targetWordLabel.attributedText = formatToolkitSentence(currentWord)
        } else {
            // It's a single word - display as plain text with theme color
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 48, weight: .bold),
                .foregroundColor: UIColor(named: "ButtonTheme") ?? .systemBlue
            ]
            targetWordLabel.attributedText = NSAttributedString(string: currentWord, attributes: attributes)
        }
        
        let shouldShowLabel = (step.stepNumber >= exercise.wordStartStep)
        updateStackLayout(imageViewHidden: false, labelHidden: !shouldShowLabel)
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
    
    private func startSequenceAnimation() {
        UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseOut) {
            self.skipButton.isHidden = true
            self.prevButton.isHidden = false
            self.prevButton.alpha = 1
            self.bottomViewConstraint.constant = 80
            self.view.layoutIfNeeded()
        }
    }
    
    private func resetSequenceAnimation() {
        UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseIn) {
            self.skipButton.isHidden = false
            self.prevButton.isHidden = true
            self.prevButton.alpha = 0
            self.bottomViewConstraint.constant = 140
            self.view.layoutIfNeeded()
        }
    }

    @IBAction func nextButtonTapped(_ sender: UIButton) {
        if currentStepIndex == 0 { startSequenceAnimation() }
        
        animationController.cancelAnimations()
        
        if currentStepIndex < steps.count - 1 {
            currentStepIndex += 1
            transitionToStep(at: currentStepIndex, direction: .forward)
        } else if currentStepIndex == steps.count - 1 {
            finishInstructions()
        }
    }
    
    @IBAction func prevButtonTapped(_ sender: UIButton) {
        if currentStepIndex == 1 { resetSequenceAnimation() }
        
        animationController.cancelAnimations()
        
        if currentStepIndex > 0 {
            currentStepIndex -= 1
            transitionToStep(at: currentStepIndex, direction: .backward)
        }
    }
    
    @IBAction func skipButtonTapped(_ sender: UIButton) {
        finishInstructions()
    }
    
    func generateVideoDiaryTopics() {
        // 1. Fetch the Video Diary exercise using the pristine ExerciseManager
        guard let videoDiaryExercise = ExerciseManager.fetchExercise(title: exerciseName) else { return }
        
        // 2. Extract and flatten all category arrays (daily_life, opinions, reflection)
        let allPrompts = videoDiaryExercise.dataBank.targets.values.flatMap { $0 }
        
        // 3. Select a truly random prompt from the entire combined pool
        if let randomPrompt = allPrompts.randomElement() {
            targetWord = randomPrompt
        } else {
            // Fallback to the JSON example demonstration if the data bank is empty
            targetWord = videoDiaryExercise.exampleDemonstration.first?.displayText ?? "Describe something that made you smile today."
        }
        
    }
    
    func generateStoryCues() {
        guard let voiceDiaryExercise = ExerciseManager.fetchExercise(title: "Story Cubes") else { return }
        
        // Flatten all available prompts from the data bank
        let allPrompts = voiceDiaryExercise.dataBank.targets.values.flatMap { $0 }
        
        var selectedWords: [String] = []
        
        // Ensure we have enough prompts to select from; otherwise, fallback to defaults or available prompts
        if allPrompts.count >= 4 {
            // Select 4 random, unique words
            // We shuffle the array and prefix 4 to ensure uniqueness if that's desired.
            // If duplicates are okay, you could just append a random element 4 times.
            selectedWords = Array(allPrompts.shuffled().prefix(4))
        } else if !allPrompts.isEmpty {
             // Fallback: If less than 4 prompts exist, just use what we have, or repeat them.
             // Here we repeat random elements until we have 4.
             for _ in 0..<4 {
                 if let randomWord = allPrompts.randomElement() {
                     selectedWords.append(randomWord)
                 }
             }
        } else {
            // Ultimate Fallback: Default text if the data bank is completely empty
            let fallbackWord = voiceDiaryExercise.exampleDemonstration.first?.displayText ?? "Describe something that made you smile today."
            selectedWords = Array(repeating: fallbackWord, count: 4)
        }
        
        // Join the selected words into a single string separated by commas
        targetWord = selectedWords.joined(separator: ", ")
    }
    
    private func finishInstructions() {
        guard let source = startingSource else {
            print("Error: Source is nil. Dismissing.")
            self.dismiss(animated: true)
            return
        }
        
        if exerciseName == "Video Diary" {
            let storyboard = UIStoryboard(name: "Exercise", bundle: nil)
            guard let VC = storyboard.instantiateViewController(withIdentifier: "VideoDiaryViewController") as? VideoDiaryViewController else { return }
            generateVideoDiaryTopics()
            VC.targetWord = self.targetWord
            
            self.navigationController?.pushViewController(VC, animated: true)
        } else if exerciseName == "Story Cubes" {
            let storyboard = UIStoryboard(name: "Exercise", bundle: nil)
            guard let VC = storyboard.instantiateViewController(withIdentifier: "VoiceDiaryViewController") as? StoryCubesViewController else { return }
            generateStoryCues()
            VC.targetWord = self.targetWord
            self.navigationController?.pushViewController(VC, animated: true)
        } else {
            let storyboard = UIStoryboard(name: "Exercise", bundle: nil)
            guard let VC = storyboard.instantiateViewController(withIdentifier: "ExerciseTemplateViewController") as? ExerciseTemplateViewController else { return }
            
            VC.exerciseName = self.exerciseName
            VC.startingSource = source
            
            self.navigationController?.pushViewController(VC, animated: true)
        }
        
    }
    
    private func formatToolkitSentence(_ text: String) -> NSAttributedString {
        let fullString = NSMutableAttributedString()
        let components = text.components(separatedBy: "'")
        let baseSize: CGFloat = 20
        let highlightedSize: CGFloat = 22
        let regularAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: baseSize, weight: .medium),
            .foregroundColor: UIColor.label
        ]
        let highlightAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: highlightedSize, weight: .bold),
            .foregroundColor: UIColor(named: "ButtonTheme") ?? .blue
        ]
        for (i, part) in components.enumerated() {
            fullString.append(NSAttributedString(string: part, attributes: (i % 2 == 0) ? regularAttributes : highlightAttributes))
        }
        return fullString
    }
    
    @IBAction func closeButtonTapped(_ sender: UIButton) {
        animationController.cancelAnimations()
        self.dismiss(animated: true, completion: nil)
    }
}

// MARK: - Animation Controller Delegate
extension ExerciseInstructionViewController: AnimationControllerDelegate {
    
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
        nextButton.isEnabled = true
        if shouldAutoAdvance {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                self.nextButtonTapped(self.nextButton)
            }
        }
    }
    
    func shouldHideTargetLabel(_ hide: Bool) {
        UIView.animate(withDuration: 0.3) {
            self.targetWordLabel.alpha = hide ? 0.0 : 1.0
            self.targetWordLabel.isHidden = hide
        }
    }
}
