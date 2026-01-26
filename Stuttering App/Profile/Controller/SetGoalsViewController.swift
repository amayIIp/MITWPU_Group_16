import UIKit

class SetGoalsViewController: UIViewController {

    @IBOutlet weak var exerciseGoalLabel: UILabel!
    @IBOutlet weak var readingGoalLabel: UILabel!
    @IBOutlet weak var convoGoalLabel: UILabel!
    
    var exerciseTarget = LogManager.shared.getGoal(name: LogManager.GoalKeys.exercise)
    var readingTarget = LogManager.shared.getGoal(name: LogManager.GoalKeys.reading)
    var conversationTarget = LogManager.shared.getGoal(name: LogManager.GoalKeys.conversation)
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateAllLabels()
    }

    private func updateAllLabels() {
        exerciseGoalLabel.text = "\(exerciseTarget)"
        readingGoalLabel.text = "\(readingTarget)"
        convoGoalLabel.text = "\(conversationTarget)"
        NotificationCenter.default.post(name: NSNotification.Name("ProgressDataUpdated"), object: nil)
    }
    
    @IBAction func exerciseIncrementTapped(_ sender: UIButton) {
        exerciseTarget += 1
        LogManager.shared.updateGoal(name: LogManager.GoalKeys.exercise, value: exerciseTarget)
        updateAllLabels()
    }
    
    @IBAction func exerciseDecrementTapped(_ sender: UIButton) {
        exerciseTarget -= 1
        LogManager.shared.updateGoal(name: LogManager.GoalKeys.exercise, value: exerciseTarget)
        updateAllLabels()
    }
    
    @IBAction func readingIncrementTapped(_ sender: UIButton) {
        readingTarget += 5
        LogManager.shared.updateGoal(name: LogManager.GoalKeys.reading, value: readingTarget)
        updateAllLabels()
    }
    
    @IBAction func readingDecrementTapped(_ sender: UIButton) {
        readingTarget -= 5
        LogManager.shared.updateGoal(name: LogManager.GoalKeys.reading, value: readingTarget)
        updateAllLabels()
    }
    
    @IBAction func convoIncrementTapped(_ sender: UIButton) {
        conversationTarget += 5
        LogManager.shared.updateGoal(name: LogManager.GoalKeys.conversation, value: conversationTarget)
        updateAllLabels()
    }
    
    @IBAction func convoDecrementTapped(_ sender: UIButton) {
        conversationTarget -= 5
        LogManager.shared.updateGoal(name: LogManager.GoalKeys.conversation, value: conversationTarget)
        updateAllLabels()
    }
}
