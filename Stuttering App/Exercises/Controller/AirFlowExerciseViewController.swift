import UIKit

class AirFlowExerciseViewController: UIViewController {

    var exerciseID: String = "ex_1_1"
    var exerciseName: String = "Airflow Practice"
    private let sessionTotalTime: TimeInterval = 120.0
    var startingSource: ExerciseSource? = .exercises
    
    @IBOutlet weak var stepImageView: UIImageView!
    @IBOutlet weak var stepLabel: UILabel!
    @IBOutlet weak var instructionLabel: UILabel!
    @IBOutlet weak var targetWordLabel: UILabel!
    
    private var currentExercise: Exercise1?
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

    override func viewDidLoad() {
        super.viewDidLoad()
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
        sheetVC?.dismiss(animated: true)
    }

    private func setupDesign() {
        targetWordLabel.font = .systemFont(ofSize: 48, weight: .bold)
        targetWordLabel.textColor = .systemIndigo
        targetWordLabel.textAlignment = .center
        targetWordLabel.isHidden = true
        
        stepLabel.font = .systemFont(ofSize: 20, weight: .bold)
        
        instructionLabel.font = .systemFont(ofSize: 17, weight: .medium)
        instructionLabel.numberOfLines = 0
        instructionLabel.textAlignment = .center
        
        stepImageView.contentMode = .scaleAspectFit
        stepImageView.tintColor = .systemGray3
        
    }
    
    private func loadData() {
        if let exercise = ExerciseManager.fetchExercise(id: exerciseID) {
            self.currentExercise = exercise
            
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
        
        if currentStepTimeRemaining <= 0 {
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
        
        stepLabel.text = "\(step.label)"
        instructionLabel.text = step.text
        targetWordLabel.text = currentWord
        
        currentStepTotalTime = Double(step.time)
        currentStepTimeRemaining = currentStepTotalTime
        
        let isTargetStep = (step.stepNumber == exercise.wordStartStep)
        
        UIView.animate(withDuration: 0.3) {
            self.targetWordLabel.alpha = isTargetStep ? 1.0 : 0.0
            self.targetWordLabel.isHidden = !isTargetStep
        }
        
        if !step.image.isEmpty {
            stepImageView.image = UIImage(named: step.image)
        } else {
            stepImageView.image = UIImage(systemName: "figure.mind.and.body")
        }
    }

    private func finishSession() {
        killTimer()
        sheetVC?.updateTimerLabel(text: "00:00")
        
        let alert = UIAlertController(title: "Session Complete", message: "Great work!", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Finish", style: .default, handler: { _ in
            self.sheetVC?.dismiss(animated: true)
            self.navigationController?.popViewController(animated: true)
        }))
        present(alert, animated: true)
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
