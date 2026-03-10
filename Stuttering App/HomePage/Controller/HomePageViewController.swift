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
    
    @IBOutlet weak var achievedAwardImage: UIImageView!
    @IBOutlet weak var achievedAwardName: UILabel!
    @IBOutlet weak var achievedAwardDescription: UILabel!
    
    @IBOutlet weak var quoteText: UILabel!
    
    @IBOutlet weak var insightLabel: UILabel!
    @IBOutlet weak var streakCount: UILabel!
    
    @IBOutlet weak var RadialCardWidthConstraint: NSLayoutConstraint!
    
    private var exerciseLogs: [ExerciseLog] = []
    private var readingLogs: [ExerciseLog] = []
    private var conversationLogs: [ExerciseLog] = []
    
    var currentDailyTasks: [DailyTask] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        loadTaskName()
        AchievedAwardsUpdate()
        setupRadialChart()
        configureNavigationBar()
        displayRandomQuote()
        setupNotificationCentre()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let currentStreak = DatabaseManager.shared.fetchCurrentStreak()
        streakCount.text = String(currentStreak)
        
        updateTaskStatus()
        loadProgressView()
        loadTaskName()
        AchievedAwardsUpdate()
        loadHomeInsight()
        setupRightBarButtons()
        
        // Background cloud sync on every home screen visit
        syncFromCloudIfLoggedIn()
    }
    
    private func syncFromCloudIfLoggedIn() {
        guard AppState.isLoginCompleted else { return }
        
        SupabaseSyncManager.shared.syncAllDataFromCloud { [weak self] _ in
            DispatchQueue.main.async {
                // Re-apply daily task completions that checkForNewDay may have wiped
                SupabaseSyncManager.shared.reapplyDailyTaskCompletions {
                    DispatchQueue.main.async {
                        // Push finalized local state back to cloud
                        DatabaseManager.shared.syncLocalDailyTasksToCloud()
                        
                        // Refresh all UI elements
                        self?.loadTaskName()
                        self?.loadProgressView()
                        self?.AchievedAwardsUpdate()
                        self?.setupRightBarButtons()
                        
                        let streak = DatabaseManager.shared.fetchCurrentStreak()
                        self?.streakCount.text = String(streak)
                    }
                }
            }
        }
    }
    
    func setupNotificationCentre() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleProfileUpdate), name: NSNotification.Name("ProgressDataUpdated"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleProfileUpdate), name: NSNotification.Name("dailyTasksUpdated"), object: nil)
    }
    
    @objc func handleProfileUpdate() {
        loadProgressView()
        loadTaskName()
    }
    
    func getRadialChartDimensions(for screenWidth: CGFloat) -> (radius: CGFloat, lineWidth: CGFloat, cardWidth: CGFloat) {
        // Reference points based on design requirements
        let baseScreenWidth: CGFloat = 402.0  // iPhone 17
        let maxScreenWidth: CGFloat = 440.0   // iPhone 17 Pro Max
        let baseCardWidth: CGFloat = 140.0
        let maxCardWidth: CGFloat = 180.0
        
        // 1. Interpolate the dynamic card width based on current screen width
        // This ensures a smooth scale even on intermediate devices like standard Pro models.
        let widthRatio = (screenWidth - baseScreenWidth) / (maxScreenWidth - baseScreenWidth)
        let dynamicCardWidth = baseCardWidth + ((maxCardWidth - baseCardWidth) * widthRatio)
        
        // 2. Apply the established 1:3 design ratio
        // Total Width = (Radius * 2) + LineWidth
        // Total Width = (3x * 2) + 1x = 7x
        let lineWidth = dynamicCardWidth / 7.0
        let radius = lineWidth * 3.0
        let cardWidth = (radius * 2.0) + lineWidth
        
        return (radius, lineWidth, cardWidth)
    }
    
    func setupRadialChart() {
        let screenWidth = view.bounds.width
        let dimensions = getRadialChartDimensions(for: screenWidth)
        RadialCardWidthConstraint.constant = dimensions.cardWidth
        
        let initialChartData: [RadialData] = [
            RadialData(
                title: "Daily Tasks",
                color: UIColor(red: 0.28, green: 0.35, blue: 0.63, alpha: 1.0),
                progress: 0.75,
                radius: dimensions.radius,
                lineWidth: dimensions.lineWidth,
                order: 0
            )
        ]
        
        radialChartView.chartData = initialChartData
        
        progressBar1.progressColor = UIColor(red: 0.4, green: 0.71, blue: 0.84, alpha: 1.0)
        progressBar2.progressColor = UIColor(red: 0.95, green: 0.77, blue: 0.24, alpha: 1.0)
        progressBar3.progressColor = UIColor(red: 0.95, green: 0.55, blue: 0.15, alpha: 1.0)
    }

    private func configureNavigationBar() {
        setupLeftTitle()
        setupRightBarButtons()
    }

    private func setupLeftTitle() {
        let titleLabel = UILabel()
        titleLabel.text = "Home"
        titleLabel.font = .systemFont(ofSize: 30, weight: .bold)
        titleLabel.textColor = .label
        
        let container = UIView()
        container.addSubview(titleLabel)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor)
        ])
        
        navigationItem.titleView = container
    }

    private func setupRightBarButtons() {
        let profileButton = UIButton(type: .system)
        var profileBtnConfig = UIButton.Configuration.plain()
        
        profileBtnConfig.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 4)
        
        let profileConfig = UIImage.SymbolConfiguration(scale: .large)
        let profileImage = UIImage(systemName: "person.crop.circle.fill", withConfiguration: profileConfig)?
            .withTintColor(.buttonTheme, renderingMode: .alwaysOriginal)
        
        profileBtnConfig.image = profileImage
        profileButton.configuration = profileBtnConfig
        profileButton.addTarget(self, action: #selector(profileTapped), for: .touchUpInside)
        
        let streakButton = UIButton(type: .system)
        var config = UIButton.Configuration.plain()
        config.imagePadding = 6
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 2)
        
        let flameColor = UIColor(red: 1.0, green: 0.435, blue: 0.212, alpha: 1.0)
        let flameConfig = UIImage.SymbolConfiguration(scale: .medium)
        config.image = UIImage(systemName: "flame.fill", withConfiguration: flameConfig)?
            .withTintColor(flameColor, renderingMode: .alwaysOriginal)
        
        var titleAttr = AttributeContainer()
        titleAttr.font = .systemFont(ofSize: 16, weight: .bold)
        titleAttr.foregroundColor = .label
        config.attributedTitle = AttributedString(String(DatabaseManager.shared.fetchCurrentStreak()), attributes: titleAttr)
        
        streakButton.configuration = config
        streakButton.addTarget(self, action: #selector(streakTapped), for: .touchUpInside)
        
        let rightStackView = UIStackView(arrangedSubviews: [streakButton, profileButton])
        rightStackView.axis = .horizontal
        rightStackView.spacing = 16
        rightStackView.alignment = .center
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: rightStackView)
    }

    @objc private func profileTapped() {
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

    @objc private func streakTapped() {
        let storyboard = UIStoryboard(name: "Home", bundle: nil)
        guard let modalVC = storyboard.instantiateViewController(withIdentifier: "Streak") as? StreaksViewController else {
            return
        }
        
        if let sheet = modalVC.sheetPresentationController {

            sheet.prefersGrabberVisible = true
            let customHeightDetent = UISheetPresentationController.Detent.custom { context in
                return 250
            }
            sheet.detents = [customHeightDetent]
        }
        present(modalVC, animated: true)
    }
    
    func displayRandomQuote() {
        quoteText.text = quotes.randomElement()
        quoteText.numberOfLines = 0
        quoteText.textAlignment = .center
    }
    
    private func loadHomeInsight() {
        Task {
            let today = Date()
            
            if let todayReport = await LogManager.shared.getDayReport(for: today) {
                DispatchQueue.main.async {
                    self.insightLabel.text = todayReport.insight
                }
                return
            }

            if let lastDate = LogManager.shared.getMostRecentReadingSessionDate(),
               let lastReport = await LogManager.shared.getDayReport(for: lastDate) {

                DispatchQueue.main.async {
                    self.insightLabel.text = lastReport.insight
                }
                return
            }

            DispatchQueue.main.async {
                self.insightLabel.text = "Your speaking practice hasn't started yet today."
            }
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
