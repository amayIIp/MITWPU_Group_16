import UIKit

class SetGoalsViewController: UIViewController {

    @IBOutlet weak var exerciseGoalLabel: UILabel!
    @IBOutlet weak var readingGoalLabel: UILabel!
    @IBOutlet weak var convoGoalLabel: UILabel!

    // Live (in-memory) values — only written to DB on ✓ Save
    var exerciseTarget = LogManager.shared.getGoal(name: LogManager.GoalKeys.exercise)
    var readingTarget  = LogManager.shared.getGoal(name: LogManager.GoalKeys.reading)
    var conversationTarget = LogManager.shared.getGoal(name: LogManager.GoalKeys.conversation)

    // Snapshot taken on load so X can fully discard changes
    private var originalExercise: Int = 0
    private var originalReading: Int = 0
    private var originalConversation: Int = 0

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        snapshotOriginalValues()
        setupNavigationButtons()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateAllLabels()
    }

    // MARK: - Setup

    private func snapshotOriginalValues() {
        originalExercise     = exerciseTarget
        originalReading      = readingTarget
        originalConversation = conversationTarget
    }

    private func setupNavigationButtons() {
        // Left — X (discard)
        let closeButton = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(discardTapped)
        )
        closeButton.tintColor = .label

        // Right — ✓ (save)
        let saveButton = UIBarButtonItem(
            image: UIImage(systemName: "checkmark"),
            style: .plain,
            target: self,
            action: #selector(saveTapped)
        )
        saveButton.tintColor = .label

        navigationItem.leftBarButtonItem  = closeButton
        navigationItem.rightBarButtonItem = saveButton
    }

    // MARK: - Nav Bar Actions

    @objc private func discardTapped() {
        // Restore original values without touching the DB
        exerciseTarget     = originalExercise
        readingTarget      = originalReading
        conversationTarget = originalConversation
        dismiss(animated: true)
    }

    @objc private func saveTapped() {
        // Persist all three values only when the user explicitly confirms
        LogManager.shared.updateGoal(name: LogManager.GoalKeys.exercise, value: exerciseTarget)
        LogManager.shared.updateGoal(name: LogManager.GoalKeys.reading, value: readingTarget)
        LogManager.shared.updateGoal(name: LogManager.GoalKeys.conversation, value: conversationTarget)
        NotificationCenter.default.post(name: NSNotification.Name("ProgressDataUpdated"), object: nil)
        dismiss(animated: true)
    }

    // MARK: - Label Update

    private func updateAllLabels() {
        exerciseGoalLabel.text = "\(exerciseTarget)"
        readingGoalLabel.text  = "\(readingTarget)"
        convoGoalLabel.text    = "\(conversationTarget)"
    }

    // MARK: - Stepper Actions (update in-memory only — no DB writes here)

    @IBAction func exerciseIncrementTapped(_ sender: UIButton) {
        exerciseTarget += 1
        updateAllLabels()
    }

    @IBAction func exerciseDecrementTapped(_ sender: UIButton) {
        exerciseTarget -= 1
        updateAllLabels()
    }

    @IBAction func readingIncrementTapped(_ sender: UIButton) {
        readingTarget += 5
        updateAllLabels()
    }

    @IBAction func readingDecrementTapped(_ sender: UIButton) {
        readingTarget -= 5
        updateAllLabels()
    }

    @IBAction func convoIncrementTapped(_ sender: UIButton) {
        conversationTarget += 5
        updateAllLabels()
    }

    @IBAction func convoDecrementTapped(_ sender: UIButton) {
        conversationTarget -= 5
        updateAllLabels()
    }
}
