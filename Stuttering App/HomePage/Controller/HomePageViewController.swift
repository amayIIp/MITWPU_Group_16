//
//  HomeViewController.swift
//  Spasht
//
//  Created by Prathamesh Patil on 16/11/25.
//

import UIKit

class HomePageViewController: UIViewController {
    
    @IBOutlet weak var radialChartView: RadialProgressView!
    @IBOutlet weak var progressBar1: ProgressBarView!
    @IBOutlet weak var progressBar2: ProgressBarView!
    @IBOutlet weak var progressBar3: ProgressBarView!
    
    @IBOutlet weak var taskNameLabel1: UILabel!
    @IBOutlet weak var taskNameLabel2: UILabel!
    @IBOutlet weak var taskNameLabel3: UILabel!
    @IBOutlet weak var taskNameLabel4: UILabel!
    @IBOutlet weak var taskNameLabel5: UILabel!
    
    @IBOutlet weak var taskIcon1: UIImageView!
    @IBOutlet weak var taskIcon2: UIImageView!
    @IBOutlet weak var taskIcon3: UIImageView!
    @IBOutlet weak var taskIcon4: UIImageView!
    @IBOutlet weak var taskIcon5: UIImageView!
    
    @IBOutlet weak var completionStatusLabel: UILabel!
    
    @IBOutlet weak var exerciseStat: UILabel!
    @IBOutlet weak var readingStat: UILabel!
    @IBOutlet weak var convoStat: UILabel!
    
    @IBOutlet weak var userNameLabel: UILabel!
    
    @IBOutlet weak var achievedAwardImage: UIImageView!
    @IBOutlet weak var achievedAwardName: UILabel!
    @IBOutlet weak var achievedAwardDescription: UILabel!
    
        
    private var exerciseLogs: [ExerciseLog] = []
    private var readingLogs: [ExerciseLog] = []
    private var conversationLogs: [ExerciseLog] = []
    
    var currentDailyTasks: [DailyTask] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        progressBar1.progressColor = UIColor(red: 0.4, green: 0.71, blue: 0.84, alpha: 1.0)
        progressBar2.progressColor = UIColor(red: 0.95, green: 0.77, blue: 0.24, alpha: 1.0)
        progressBar3.progressColor = UIColor(red: 0.95, green: 0.55, blue: 0.15, alpha: 1.0)
        radialChartView.chartData = initialChartData
        
        loadTaskName()
        loadUserName()
        AchievedAwardsUpdate()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleProfileUpdate), name: NSNotification.Name("ProfileDataUpdated"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleProfileUpdate), name: NSNotification.Name("ProgressDataUpdated"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleProfileUpdate), name: NSNotification.Name("dailyTasksUpdated"), object: nil)
        
        
        
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)

        updateTaskStatus()
        loadProgressView()
        loadUserName()
        loadTaskName()
        AchievedAwardsUpdate()
    }
    
    @objc func handleProfileUpdate() {
        loadUserName()
        loadProgressView()
        updateTaskStatus()
    }
    
    private func loadUserName() {
        if let name = StorageManager.shared.getName() {
            userNameLabel.text = "\(name)"
        } else {
            userNameLabel.text = "User"
        }
    }
    
    @IBAction func profileButtonTapped(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Profile", bundle: nil)
        
        if AppState.isLoginCompleted {
            guard let profileNav = storyboard.instantiateViewController(withIdentifier: "ProfileNav") as? UINavigationController else { return }
            
            profileNav.modalPresentationStyle = .pageSheet
            if let sheet = profileNav.sheetPresentationController {
                sheet.prefersGrabberVisible = true
            }
            
            present(profileNav, animated: true)
            
        } else {
            guard let guestNav = storyboard.instantiateViewController(withIdentifier: "GuestAuthNav") as? UINavigationController else { return }
            
            guestNav.modalPresentationStyle = .pageSheet
            if let sheet = guestNav.sheetPresentationController {
                sheet.prefersGrabberVisible = true
            }
            
            present(guestNav, animated: true)
        }
    }

    private func calculateTotalDuration(for logs: [ExerciseLog]) -> Int {

        let totalSeconds = logs.reduce(0) { (runningTotal, log) -> Int in
            return runningTotal + log.exerciseDuration
        }
        
        let totalMinutes = Int((Double(totalSeconds) / 60.0).rounded())
        return totalMinutes
    }
        
    func loadTaskName() {
        self.currentDailyTasks = DatabaseManager.shared.fetchDailyTasks()
        self.updateTaskStatus()
    }

    func updateTaskStatus() {
        let nameLabels = [taskNameLabel1, taskNameLabel2, taskNameLabel3, taskNameLabel4, taskNameLabel5]
        let iconViews = [taskIcon1, taskIcon2, taskIcon3, taskIcon4, taskIcon5]
        
        let checkmarkIcon = UIImage(systemName: "checkmark.circle.fill")
        let circleIcon = UIImage(systemName: "circle")
        
        var completedCount = 0
        
        for (index, task) in currentDailyTasks.enumerated() {
            
            guard index < nameLabels.count, index < iconViews.count else { break }
            
            nameLabels[index]?.text = task.name
            
            if task.isCompleted {
                iconViews[index]?.image = checkmarkIcon
                iconViews[index]?.tintColor = .systemGreen
                completedCount += 1
            } else {
                iconViews[index]?.image = circleIcon
                iconViews[index]?.tintColor = .secondaryLabel
            }
        }
        
        completionStatusLabel.text = "\(completedCount)"
        
        guard !currentDailyTasks.isEmpty else {
            self.radialChartView.updateProgress(for: "Daily Tasks", to: 0.0)
            return
        }
        
        let progress = Double(completedCount) / Double(currentDailyTasks.count)
        self.radialChartView.updateProgress(for: "Daily Tasks", to: progress)
    }
        
    
    func formatDuration(_ seconds: Int) -> Int {
        if seconds < 60 {
            return seconds
        } else {
            let minutes = Int((Double(seconds) / 60.0).rounded())
            return minutes
        }
    }
    
    func loadProgressView() {
        let today = Date()
        
        exerciseLogs = LogManager.shared.getLogs(for: .exercises, on: today)
        readingLogs = LogManager.shared.getLogs(for: .reading, on: today)
        conversationLogs = LogManager.shared.getLogs(for: .conversation, on: today)
        
        let exerciseTarget = LogManager.shared.getGoal(name: LogManager.GoalKeys.exercise)
        let readingTarget = LogManager.shared.getGoal(name: LogManager.GoalKeys.reading)
        let conversationTarget = LogManager.shared.getGoal(name: LogManager.GoalKeys.conversation)
        
        // --- Exercise Bar & Label -
        let exCount = exerciseLogs.count
        let exGoal = exerciseTarget
        let exProgress = (exGoal > 0) ? (Double(exCount) / Double(exGoal)) : 0.0
        progressBar1.setProgress(CGFloat(exProgress), animated: true)
        exerciseStat.text = "\(exCount)/\(exGoal)"

        // --- Reading Bar & Label ---
        let readCount = calculateTotalDuration(for: self.readingLogs)
        let readGoal = readingTarget
        let readProgress = (readGoal > 0) ? (Double(readCount) / Double(readGoal)) : 0.0
        progressBar2.setProgress(CGFloat(readProgress), animated: true)
        readingStat.text = "\(readCount)/\(readGoal) min"

        // --- Conversation Bar & Label ---
        let convoCount = calculateTotalDuration(for: self.conversationLogs)
        let convoGoal = conversationTarget
        let convoProgress = (convoGoal > 0) ? (Double(convoCount) / Double(convoGoal)) : 0.0
        progressBar3.setProgress(CGFloat(convoProgress), animated: true)
        convoStat.text = "\(convoCount)/\(convoGoal) min"
    }
    
    @IBAction func DailySummaryTapped(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Summary", bundle: nil)
        
        if let detailVC = storyboard.instantiateViewController(withIdentifier: "SummaryViewController") as? SummaryViewController {
            self.navigationController?.pushViewController(detailVC, animated: true)
        }
    }
    
    @IBAction func AwardsTapped(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Awards", bundle: nil)
        
        if let detailVC = storyboard.instantiateViewController(withIdentifier: "AwardMainViewController") as? AwardMainViewController {
            self.navigationController?.pushViewController(detailVC, animated: true)
        }
    }
    
    @IBAction func showModalButtonTapped(_ sender: UIButton) {
        
        let storyboard = UIStoryboard(name: "Home", bundle: nil)
        guard let modalVC = storyboard.instantiateViewController(withIdentifier: "Streak") as? ViewController else {
            return
        }
        
        if let sheet = modalVC.sheetPresentationController {

            sheet.prefersGrabberVisible = true
            let customHeightDetent = UISheetPresentationController.Detent.custom { context in
                return 500
            }
            sheet.detents = [customHeightDetent]
        }
        present(modalVC, animated: true)
    }
}

extension HomePageViewController {
    func AchievedAwardsUpdate() {
        if let award = AwardsManager.shared.getTopAchievedAward() {
            achievedAwardImage.image = UIImage(named: award.id)
            achievedAwardName.text = award.name
            achievedAwardImage.tintColor = .clear
            
            if let date = award.completionDate {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d, yyyy"
                achievedAwardDescription.text = "\(formatter.string(from: date))"
            }
            achievedAwardDescription.textColor = .secondaryLabel
            
        } else {
            achievedAwardImage.image = UIImage(systemName: "figure.run.circle.fill")
            achievedAwardImage.tintColor = .systemOrange
            achievedAwardName.text = "Start doing exercises!"
            achievedAwardDescription.text = "Your first award awaits"
            achievedAwardDescription.textColor = .secondaryLabel
        }
    }
}
