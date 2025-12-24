//
//  ExerciseInstructionViewController.swift
//  Stuttering App 1
//
//  Created by SDC-USER on 16/12/25.
//

import UIKit

class ExerciseInstructionViewController: UIViewController {

    // MARK: - Dependencies
    // pass this String from the previous View Controller
    var exerciseID: String = "ex_1_1"
    var exerciseName = "Airflow Practice"
    // Internal State
    private var currentExercise: Exercise1?
    private var currentStepIndex: Int = 0
    private var steps: [ExerciseStep] = []

    // MARK: - IBOutlets
    @IBOutlet weak var stepLabel: UILabel!       // e.g., "Step 1: Posture"
    @IBOutlet weak var stepImageView: UIImageView!
    @IBOutlet weak var stepTextLabel: UILabel!   // e.g., "Sit upright..."
    @IBOutlet weak var targetWordLabel: UILabel! // e.g., "Apple"
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var prevButton: UIButton!
    @IBOutlet weak var skipButton: UIButton!
    @IBOutlet weak var bottomViewConstraint: NSLayoutConstraint!

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupDesign()
        loadExerciseData()
        setupInitialState()
    }

    // MARK: - Setup
    private func setupDesign() {
        targetWordLabel.font = .systemFont(ofSize: 48, weight: .bold)
        targetWordLabel.textColor = .systemIndigo
        targetWordLabel.textAlignment = .center
        targetWordLabel.isHidden = true
        
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
    
    private func startSequenceAnimation() {
        
        UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseOut) {
            self.skipButton.isHidden = true
            self.prevButton.isHidden = false
            self.prevButton.alpha = 1
            self.bottomViewConstraint.constant = 80
        }
        
    }
    private func loadExerciseData() {
        
        // Fetch specific exercise using our Helper
        guard let exercise = ExerciseManager.fetchExercise(id: exerciseID) else {
            // Handle error (e.g., show alert)
            return
        }
        
        self.currentExercise = exercise
        self.steps = exercise.instructionSet.steps
        
        // Initialize UI with the first step
        updateUIForStep(at: 0)
    }

    // MARK: - Main Logic Engine
    private func updateUIForStep(at index: Int) {
        guard let exercise = currentExercise, index < steps.count else { return }
        
        let step = steps[index]
        
        // 1. Text & Labels
        stepLabel.text = "\(step.label)"
        stepTextLabel.text = step.text
        
        // 2. Logic: Target Word
        // We inject the word from 'example_demonstration'
        targetWordLabel.text = exercise.exampleDemonstration.targetWord
        
        // Logic: Show ONLY if current step matches the JSON variable "word_start"
        // Note: steps are usually 1-indexed in JSON, index is 0-indexed in code.
        let currentStepNumber = index + 1
        let shouldShowWord = (currentStepNumber == exercise.wordStartStep)
        
        // Smooth fade animation
        UIView.animate(withDuration: 0.3) {
            self.targetWordLabel.alpha = shouldShowWord ? 1.0 : 0.0
            self.targetWordLabel.isHidden = !shouldShowWord
        }
        
        // 3. Image Handling
        if !step.image.isEmpty {
            stepImageView.image = UIImage(named: step.image)
        } else {
            // Placeholder if JSON has empty string
            stepImageView.image = UIImage(systemName: "figure.mind.and.body")
        }
        
        // 4. Progress Logic
        let totalSteps = Float(steps.count)
        let progress = Float(currentStepNumber) / totalSteps
        progressView.setProgress(progress, animated: true)
        
        // 5. Button State
        if index == steps.count - 1 {
            nextButton.configuration?.title = "Complete"
        } else {
            nextButton.configuration?.title = "Next"
        }
    }

    // MARK: - Interactions
    @IBAction func nextButtonTapped(_ sender: UIButton) {
        
        if currentStepIndex == 0 {
            startSequenceAnimation()
        }
        // Check if we have steps remaining
        if currentStepIndex < steps.count - 1 {
            currentStepIndex += 1
            updateUIForStep(at: currentStepIndex)
        } else if currentStepIndex == steps.count - 1 {
            finishInstructions()
        }
        
    }
    
    @IBAction func prevButtonTapped(_ sender: UIButton) {
        if currentStepIndex < steps.count - 1 && currentStepIndex >= 0 {
            currentStepIndex -= 1
            updateUIForStep(at: currentStepIndex)
        }
    }
    
    @IBAction func skipButtonTapped(_ sender: UIButton) {
        finishInstructions()
    }
    
    private func finishInstructions() {
        let storyboard = UIStoryboard(name: "Exercise", bundle: nil)
        
        guard let VC = storyboard.instantiateViewController(withIdentifier: "AirFlowExerciseViewController") as? AirFlowExerciseViewController else { return
        }
        
        VC.exerciseID = self.exerciseID
        VC.exerciseName = self.exerciseName
        
        self.navigationController?.pushViewController(VC, animated: true)
    }
    
    @IBAction func closeButtonTapped(_ sender: UIButton) {
        
        self.dismiss(animated: true, completion: nil)
    }
}
