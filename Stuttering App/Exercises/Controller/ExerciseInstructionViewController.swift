//
//  ExerciseInstructionViewController.swift
//  Stuttering App 1
//
//  Updated with modular animation system
//

import UIKit

class ExerciseInstructionViewController: UIViewController, ExerciseStarting {
    
    var startingSource: ExerciseSource?
    var exerciseName = ""

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
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var prevButton: UIButton!
    @IBOutlet weak var skipButton: UIButton!
    @IBOutlet weak var bottomViewConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var targetLabelBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var targetLabelCenterYConstraint: NSLayoutConstraint!

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
        targetWordLabel.textColor = .systemIndigo
        
        stepLabel.font = .systemFont(ofSize: 20, weight: .bold)
        
        stepTextLabel.font = .systemFont(ofSize: 17, weight: .medium)
        stepTextLabel.numberOfLines = 0
        stepTextLabel.textAlignment = .center
        
        progressView.progress = 0.0
        progressView.layer.cornerRadius = 4
        progressView.clipsToBounds = true
        
        nextButton.configuration = .prominentGlass()
        nextButton.setTitle("Next", for: .normal)
        skipButton.configuration = .glass()
        skipButton.setTitle("Skip Instructions", for: .normal)
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
        if let twoSyllables = exercise.dataBank.targets["2_syllables"],
           let randomWord = twoSyllables.randomElement() {
            currentWord = randomWord
        } else {
            // Fallback to example demonstration
            currentWord = exercise.exampleDemonstration.first?.displayText ?? "Ba-by"
        }
    }

    private func updateUIForStep(at index: Int) {
        guard let exercise = currentExercise, index < steps.count else { return }
        
        let step = steps[index]
        let currentStepNumber = index + 1
        
        stepLabel.text = "\(step.label)"
        stepTextLabel.text = step.text
        
        let progress = Float(currentStepNumber) / Float(steps.count)
        progressView.setProgress(progress, animated: true)
        
        nextButton.configuration?.title = (index == steps.count - 1) ? "Complete" : "Next"
        
        if let template = exerciseTemplate {
            handleAnimatedExercise(template: template, stepNumber: currentStepNumber, step: step)
        } else {
            handleTraditionalExercise(step: step)
        }
    }
    
    private func handleAnimatedExercise(template: ExerciseAnimationTemplate, stepNumber: Int, step: ExerciseStep) {
        // Check if this is a text-only exercise (3.1, 3.2, 3.3)
        if template.exerciseType == .textOnly {
            handleTextOnlyExercise(step: step)
            return
        }
        
        
        if let stepConfig = template.stepConfigs.first(where: { $0.stepNumber == stepNumber }) {
            
            // Update layout constraints based on whether image is shown
            updateLayoutConstraints(showImage: stepConfig.showImage)
            
            if stepConfig.showImage {
                // Show image, hide text
                showImage(step.image)
                targetWordLabel.isHidden = true
            } else {
                // Hide image, show animated text
                stepImageView.isHidden = true
                
                // Start animation sequence
                animationController.startAnimation(for: stepConfig, word: currentWord)
                
                // Disable next button during auto-advance sequences
                if stepConfig.autoAdvance {
                    nextButton.isEnabled = false
                }
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
    }
    
    private func handleTraditionalExercise(step: ExerciseStep) {
        guard let exercise = currentExercise else { return }
        
        // Traditional image-based flow
        updateLayoutConstraints(showImage: true)
        showImage(step.image)
        
        // Get the text from example demonstration
        let rawText = exercise.exampleDemonstration.first?.displayText ?? ""
        
        // Apply sentence formatting with highlighted word
        targetWordLabel.attributedText = formatToolkitSentence(rawText)
        
        // Show text at the target step along with the image
        let isTargetStep = (step.stepNumber == exercise.wordStartStep)
        
        UIView.animate(withDuration: 0.3) {
            self.targetWordLabel.alpha = isTargetStep ? 1.0 : 0.0
            self.targetWordLabel.isHidden = !isTargetStep
        }
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
            targetLabelCenterYConstraint.isActive = false
            targetLabelBottomConstraint.isActive = true
        } else {
            // Centered Mode: Label vertically centered, no image
            targetLabelBottomConstraint.isActive = false
            targetLabelCenterYConstraint.isActive = true
        }
        
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
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
        
        // Cancel ongoing animations
        animationController.cancelAnimations()
        
        if currentStepIndex < steps.count - 1 {
            currentStepIndex += 1
            updateUIForStep(at: currentStepIndex)
        } else if currentStepIndex == steps.count - 1 {
            finishInstructions()
        }
    }
    
    @IBAction func prevButtonTapped(_ sender: UIButton) {
        if currentStepIndex == 1 { resetSequenceAnimation() }
        
        // Cancel ongoing animations
        animationController.cancelAnimations()
        
        if currentStepIndex > 0 {
            currentStepIndex -= 1
            updateUIForStep(at: currentStepIndex)
        }
    }
    
    @IBAction func skipButtonTapped(_ sender: UIButton) {
        finishInstructions()
    }
    
    private func finishInstructions() {
        
        guard let source = startingSource else {
            print("Error: Source is nil. Dismissing.")
            self.dismiss(animated: true)
            return
        }
        
        let storyboard = UIStoryboard(name: "Exercise", bundle: nil)
        guard let VC = storyboard.instantiateViewController(withIdentifier: "AirFlowExerciseViewController") as? AirFlowExerciseViewController else { return }
        
        VC.exerciseName = self.exerciseName
        VC.startingSource = source
        
        self.navigationController?.pushViewController(VC, animated: true)
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
            .foregroundColor: UIColor.systemIndigo
        ]
        
        for (i, part) in components.enumerated() {
            if i % 2 == 0 {
                fullString.append(NSAttributedString(string: part, attributes: regularAttributes))
            } else {
                fullString.append(NSAttributedString(string: part, attributes: highlightAttributes))
            }
        }
        
        return fullString
    }
    
    @IBAction func closeButtonTapped(_ sender: UIButton) {
        animationController.cancelAnimations()
        self.dismiss(animated: true, completion: nil)
    }
}

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
        // Re-enable next button
        nextButton.isEnabled = true
        
        if shouldAutoAdvance {
            // Auto-advance to next step
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.nextButtonTapped(self!.nextButton)
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
