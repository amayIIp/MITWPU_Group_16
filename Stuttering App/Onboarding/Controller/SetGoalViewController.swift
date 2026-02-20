import UIKit

class SetGoalViewController: UIViewController {

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
    
    @IBAction func continueTapped(_ sender: UIButton) {
        AppState.isOnboardingCompleted = true
            AwardsManager.shared.updateAwardProgress(id: "nm_001", progress: 1.0, newStatus: "1 of 1 completed")
            
            // 1. Setup the new View Controller
        let storyboard = UIStoryboard(name: "Home", bundle: nil)
        let homeVC = storyboard.instantiateViewController(withIdentifier: "HomeVC")

        guard let window = view.window else { return }

        // 1. Set the window's background to your target color
        // (e.g., .white or homeVC's background color)
        window.backgroundColor = .bg

        // 2. Phase 1: Fade out the current view
        UIView.animate(withDuration: 0.3, animations: {
            window.rootViewController?.view.alpha = 0
        }) { _ in
            // 3. Switch the Root View Controller
            homeVC.view.alpha = 0
            window.rootViewController = homeVC
            
            // 4. Phase 2: Fade the new view back in
            UIView.animate(withDuration: 0.3) {
                homeVC.view.alpha = 1
            }
        }
    }
}
