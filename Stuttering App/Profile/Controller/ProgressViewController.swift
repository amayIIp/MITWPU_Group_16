import UIKit

class ProgressViewController: UIViewController {

    // MARK: - Section 1: Top Bar
    @IBOutlet weak var daysGoalsCompletedLabel: UILabel!
    @IBOutlet weak var activeStreakLabel: UILabel!
    @IBOutlet weak var totalHoursLabel: UILabel!

    // MARK: - Section 2: Key Metrics
    @IBOutlet weak var avgFluencyLabel: UILabel!
    @IBOutlet weak var bestFluencyLabel: UILabel!
    @IBOutlet weak var totalAwardsLabel: UILabel!

    // MARK: - Section 3: Exercises
    @IBOutlet weak var totalExercisesPracticedLabel: UILabel!
    @IBOutlet weak var totalExerciseTimeLabel: UILabel!
    @IBOutlet weak var mostPracticedLabel: UILabel!

    // MARK: - Section 4: Reading
    @IBOutlet weak var totalReadingSectionsLabel: UILabel!
    @IBOutlet weak var avgReadingDurationLabel: UILabel!
    @IBOutlet weak var longestSmoothParagraphLabel: UILabel!

    // MARK: - Section 5: Conversation
    @IBOutlet weak var totalConversationSessionsLabel: UILabel!
    @IBOutlet weak var avgConvoDurationLabel: UILabel!
    @IBOutlet weak var longestSmoothTalkLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        loadProgressData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadProgressData()
    }

    // MARK: - Data Loading

    private func loadProgressData() {
        Task {
            let report = await LogManager.shared.getOverallProgressReport()

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                if let report = report {
                    // Section 1: Top Bar
                    self.daysGoalsCompletedLabel.text = "\(report.daysGoalsCompleted)"
                    self.activeStreakLabel.text = "\(report.activeStreak)"
                    self.totalHoursLabel.text = "\(Int(report.totalHours))"

                    // Section 2: Key Metrics
                    if let userId = LogManager.shared.getCurrentUserId() {
                        let avgFluency = LogManager.shared.getAverageFluency(userId: userId)
                        self.avgFluencyLabel.text = "\(Int(avgFluency))"
                        let bestFluency = LogManager.shared.getBestFluency(userId: userId)
                        self.bestFluencyLabel.text = "\(Int(bestFluency))"
                    } else {
                        self.avgFluencyLabel.text = "--"
                        self.bestFluencyLabel.text = "--"
                    }
                    self.totalAwardsLabel.text = "\(AwardsManager.shared.getAchievedAwardsCount())"

                    // Section 3: Exercises
                    self.totalExercisesPracticedLabel.text = "\(report.totalExercisesPracticed)"
                    self.totalExerciseTimeLabel.text = "\(report.totalExerciseMinutesThisWeek)"
                    self.mostPracticedLabel.text = report.mostPracticedTechnique

                    // Section 4: Reading
                    self.totalReadingSectionsLabel.text = "\(report.totalReadingSessions)"
                    self.avgReadingDurationLabel.text = self.formatDuration(report.avgReadingDuration)
                    self.longestSmoothParagraphLabel.text = "\(report.longestSmoothParagraph)"

                    // Section 5: Conversation
                    self.totalConversationSessionsLabel.text = "\(report.totalConversationSessions)"
                    self.avgConvoDurationLabel.text = self.formatDuration(report.avgConversationDuration)
                    self.longestSmoothTalkLabel.text = "\(report.longestSmoothTalk)"
                } else {
                    // No data — show defaults
                    self.daysGoalsCompletedLabel.text = "0"
                    self.activeStreakLabel.text = "0"
                    self.totalHoursLabel.text = "0"

                    self.avgFluencyLabel.text = "0"
                    self.bestFluencyLabel.text = "0"
                    self.totalAwardsLabel.text = "0"

                    self.totalExercisesPracticedLabel.text = "0"
                    self.totalExerciseTimeLabel.text = "0"
                    self.mostPracticedLabel.text = "—"

                    self.totalReadingSectionsLabel.text = "0"
                    self.avgReadingDurationLabel.text = "0:00"
                    self.longestSmoothParagraphLabel.text = "0"

                    self.totalConversationSessionsLabel.text = "0"
                    self.avgConvoDurationLabel.text = "0:00"
                    self.longestSmoothTalkLabel.text = "0"
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return "\(minutes):\(String(format: "%02d", secs))"
    }
}
