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

    @IBOutlet weak var radialCardWidthConstraint: NSLayoutConstraint!

    private var exerciseLogs: [ExerciseLog] = []
    private var readingLogs: [ExerciseLog] = []
    private var conversationLogs: [ExerciseLog] = []

    /// Stored handle for the active insight-loading task.
    /// Cancelled before starting a new one to prevent race conditions
    /// when the user switches tabs rapidly.
    private var insightTask: Task<Void, Never>?

    var currentDailyTasks: [DailyTask] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        setupRadialChart()
        loadTaskName()
        achievedAwardsUpdate()
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
        achievedAwardsUpdate()
        loadHomeInsight()
        setupRightBarButtons()

        // Background cloud sync on every home screen visit
        syncFromCloudIfLoggedIn()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // showcaseAnimationIfNeeded()
        requestNotificationPermissionIfNeeded()
    }

    /// Asks for notification permission exactly once — but ONLY after the user has
    /// fully completed onboarding (either as a guest or with their email account).
    /// This prevents the system permission dialog from appearing during the onboarding flow.
    private func requestNotificationPermissionIfNeeded() {
        // Guard: only proceed if onboarding is fully complete
        guard AppState.isOnboardingCompleted else { return }

        let key = "hasRequestedNotificationPermission"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        // Small delay so the home screen is fully settled before the system alert appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            NotificationManager.shared.requestAuthorization()
        }
    }

    // MARK: - First-Launch Showcase Animation
    /*
    // Durations (seconds) — slowed down for a premium feel
    private let showcaseDuration:     CFTimeInterval = 1.5  // rise to full
    private let showcaseHoldDuration: CFTimeInterval = 0.4  // pause at full
    private let showcaseFallDuration: CFTimeInterval = 1.2  // return to zero
    // Stagger offset between consecutive progress bars
    private let showcaseBarStagger:   CFTimeInterval = 0.2

    private var displayLink: CADisplayLink?
    private var showcaseStartTime: CFTimeInterval = 0

    private func showcaseAnimationIfNeeded() {
        let key = "hasShownHomeShowcase"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        // Zero everything out before starting
        radialChartView.updateProgress(for: "Daily Tasks", to: 0)
        progressBar1.setProgress(0, animated: false)
        progressBar2.setProgress(0, animated: false)
        progressBar3.setProgress(0, animated: false)

        showcaseStartTime = CACurrentMediaTime()
        displayLink = CADisplayLink(target: self, selector: #selector(showcaseTick))
        displayLink?.add(to: .main, forMode: .common)
    }

    @objc private func showcaseTick() {
        let elapsed = CACurrentMediaTime() - showcaseStartTime

        // Bar offsets: bar1 = 0s, bar2 = 0.2s, bar3 = 0.4s
        // Ring follows bar1 (offset 0)
        let barOffsets: [CFTimeInterval] = [0, showcaseBarStagger, showcaseBarStagger * 2]
        let bars: [ProgressBarView?] = [progressBar1, progressBar2, progressBar3]

        // Update radial ring (same phase as bar1)
        radialChartView.updateProgress(for: "Daily Tasks", to: showcaseProgress(localTime: elapsed))

        // Update each bar with its own staggered local time
        for (i, bar) in bars.enumerated() {
            let localTime = elapsed - barOffsets[i]
            bar?.setProgress(showcaseProgress(localTime: localTime), animated: false)
        }

        // Animation is finished when the last bar (bar3) has completed its full cycle
        let lastBarEnd = barOffsets[2] + showcaseDuration + showcaseHoldDuration + showcaseFallDuration
        guard elapsed >= lastBarEnd else { return }

        // Tear down and restore real data
        displayLink?.invalidate()
        displayLink = nil
        radialChartView.updateProgress(for: "Daily Tasks", to: 0)
        bars.forEach { $0?.setProgress(0, animated: false) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.loadProgressView()
            self.updateTaskStatus()
        }
    }

    /// Returns progress (0–1) for a given local time, applying the 3-phase curve.
    private func showcaseProgress(localTime: CFTimeInterval) -> CGFloat {
        guard localTime > 0 else { return 0 }

        if localTime < showcaseDuration {
            // Phase 1 — smooth sine ease-in-out rise
            return sineEase(CGFloat(localTime / showcaseDuration))
        } else if localTime < showcaseDuration + showcaseHoldDuration {
            // Phase 2 — hold at full
            return 1.0
        } else if localTime < showcaseDuration + showcaseHoldDuration + showcaseFallDuration {
            // Phase 3 — smooth sine ease-in-out fall
            let t = CGFloat((localTime - showcaseDuration - showcaseHoldDuration) / showcaseFallDuration)
            return 1.0 - sineEase(t)
        } else {
            return 0.0
        }
    }

    /// Sine-based ease-in-out — much smoother than quadratic at entry/exit points.
    private func sineEase(_ t: CGFloat) -> CGFloat {
        return (1 - cos(t * .pi)) / 2
    }
    */

    private func syncFromCloudIfLoggedIn() {
        guard SessionManager.shared.isAccountMode else {
            print("📋 [GUEST] Skipping background cloud sync (guest mode)")
            return
        }

        Task {
            do {
                let hasChanges = try await SupabaseSyncManager.shared.hasPendingCloudChanges()
                guard hasChanges else {
                    print("☁️ Skipping full sync — no new cloud updates detected.")
                    return
                }

                try await SupabaseSyncManager.shared.syncAllDataFromCloud()
                await SupabaseSyncManager.shared.reapplyDailyTaskCompletions()
                let didGenerateJourney = JourneyGenerationEngine.shared.runIfNeeded()

                if didGenerateJourney && DatabaseManager.shared.fetchDailyTasks().isEmpty {
                    let logic = LogicMaker()
                    logic.resetDailyTasks(isFromLogin: true)
                    DatabaseManager.shared.syncLocalDailyTasksToCloud()
                }

                await MainActor.run {
                    self.loadTaskName()
                    self.loadProgressView()
                    self.achievedAwardsUpdate()
                    self.setupRightBarButtons()
                    let streak = DatabaseManager.shared.fetchCurrentStreak()
                    self.streakCount.text = String(streak)
                }

            } catch {
                print("☁️ ❌ Background sync failed: \(error)")
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
        radialCardWidthConstraint.constant = dimensions.cardWidth

        let initialChartData: [RadialData] = [
            RadialData(
                title: "Daily Tasks",
                color: UIColor(named: "ButtonTheme") ?? UIColor(red: 0.28, green: 0.35, blue: 0.63, alpha: 1.0),
                progress: 0.75,
                radius: dimensions.radius,
                lineWidth: dimensions.lineWidth,
                order: 0
            )
        ]

        radialChartView.chartData = initialChartData

        let themeColor = UIColor(named: "ButtonTheme") ?? .systemBlue
        progressBar1.progressColor = themeColor
        progressBar2.progressColor = themeColor
        progressBar3.progressColor = themeColor
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
        // 1. Profile Button Setup
        let profileButton = UIButton(type: .system)
        var profileBtnConfig = UIButton.Configuration.plain()
        profileBtnConfig.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 4)

        let profileConfig = UIImage.SymbolConfiguration(scale: .large)
        let profileImage = UIImage(systemName: "person.crop.circle.fill", withConfiguration: profileConfig)?
            .withTintColor(.buttonTheme, renderingMode: .alwaysOriginal)

        profileBtnConfig.image = profileImage
        profileButton.configuration = profileBtnConfig
        profileButton.addTarget(self, action: #selector(profileTapped), for: .touchUpInside)
        let profileItem = UIBarButtonItem(customView: profileButton)

        // 2. Streak Button Setup
        let streakButton = UIButton(type: .system)
        var config = UIButton.Configuration.plain()
        config.imagePadding = 6
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 2)

        let flameColor = UIColor(red: 1.0, green: 0.329, blue: 0.431, alpha: 1.0)
        let flameConfig = UIImage.SymbolConfiguration(scale: .medium)
        config.image = UIImage(systemName: "flame.fill", withConfiguration: flameConfig)?
            .withTintColor(flameColor, renderingMode: .alwaysOriginal)

        var titleAttr = AttributeContainer()
        titleAttr.font = .systemFont(ofSize: 16, weight: .bold)
        titleAttr.foregroundColor = .label
        config.attributedTitle = AttributedString(String(DatabaseManager.shared.fetchCurrentStreak()), attributes: titleAttr)

        streakButton.configuration = config
        streakButton.addTarget(self, action: #selector(streakTapped), for: .touchUpInside)
        let streakItem = UIBarButtonItem(customView: streakButton)

        // 3. The Fix: Assign as an array (Order is Right-to-Left)
        navigationItem.rightBarButtonItems = [profileItem, streakItem]
    }

    @objc private func profileTapped() {
        let storyboard = UIStoryboard(name: "Profile", bundle: nil)

        if SessionManager.shared.isAccountMode {
            guard let profileNav = storyboard.instantiateViewController(withIdentifier: "ProfileNav") as? UINavigationController else { return }

            profileNav.modalPresentationStyle = .pageSheet
            if let sheet = profileNav.sheetPresentationController {
                sheet.prefersGrabberVisible = true
            }

            present(profileNav, animated: true)

        } else {
            let storyboard = UIStoryboard(name: "Onboarding", bundle: nil)
            let nextModalVC = storyboard.instantiateViewController(withIdentifier: "SignUpViewController")

            // 1. Wrap your destination in a Navigation Controller
            // This allows you to have a navigation bar and push/pop logic inside the modal.
            let navController = UINavigationController(rootViewController: nextModalVC)

            // 2. Enable Large Titles on the Navigation Bar
            navController.navigationBar.prefersLargeTitles = true

            // 3. Configure the Sheet (Modal) behavior
            // We apply the presentation style to the navigation controller itself.
            navController.modalPresentationStyle = .pageSheet
            if let sheet = navController.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
            }

            // 4. Present the Navigation Controller
            present(navController, animated: true)
        }
    }

    @objc private func streakTapped() {
        let storyboard = UIStoryboard(name: "Home", bundle: nil)
        guard let modalVC = storyboard.instantiateViewController(withIdentifier: "Streak") as? StreaksViewController else {
            return
        }

        if let sheet = modalVC.sheetPresentationController {

            sheet.prefersGrabberVisible = true
            let customHeightDetent = UISheetPresentationController.Detent.custom { _ in
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
        // Fast path: use cached insight if available (invalidated when a new session is saved)
        if let cached = LogManager.shared.cachedHomeInsight {
            self.insightLabel.text = cached
            return
        }

        // Show a placeholder immediately so the label doesn't appear blank
        self.insightLabel.text = "Loading your insight…"

        // Cancel any previous in-flight task before starting a new one.
        // Prevents multiple concurrent AI calls from rapid tab switching.
        insightTask?.cancel()
        insightTask = Task {
            let today = Date()

            if let todayReport = await LogManager.shared.getDayReport(for: today) {
                guard !Task.isCancelled else { return }
                LogManager.shared.cachedHomeInsight = todayReport.insight
                await MainActor.run { self.insightLabel.text = todayReport.insight }
                return
            }

            if let lastDate = LogManager.shared.getMostRecentReadingSessionDate(),
               let lastReport = await LogManager.shared.getDayReport(for: lastDate) {
                guard !Task.isCancelled else { return }
                LogManager.shared.cachedHomeInsight = lastReport.insight
                await MainActor.run { self.insightLabel.text = lastReport.insight }
                return
            }

            guard !Task.isCancelled else { return }
            let fallback = "Your speaking practice hasn't started yet today."
            LogManager.shared.cachedHomeInsight = fallback
            await MainActor.run { self.insightLabel.text = fallback }
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
        let circleIcon = UIImage(systemName: "circle.fill")

        var completedCount = 0

        for (index, task) in currentDailyTasks.enumerated() {

            guard index < nameLabels.count, index < iconViews.count else { break }

            nameLabels[index]?.text = task.name

            if task.isCompleted {
                iconViews[index]?.image = checkmarkIcon
                iconViews[index]?.tintColor = UIColor(named: "CompletedGreen")
                completedCount += 1
            } else {
                iconViews[index]?.image = circleIcon
                iconViews[index]?.tintColor = UIColor(red: 0.925, green: 0.933, blue: 0.973, alpha: 1.0)
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

    @IBAction func dailySummaryTapped(_ sender: UIButton) {
        if AppState.isDailyProgressCompleted {
            let storyboard = UIStoryboard(name: "Home", bundle: nil)
            if let detailVC = storyboard.instantiateViewController(withIdentifier: "PracticeViewController") as? PracticeViewController {

                // 1. Enable Large Titles on your current navigation controller
                self.navigationController?.navigationBar.prefersLargeTitles = true

                // 2. (Optional but recommended) Ensure this specific screen shows the large title,
                // especially if the previous screen used a standard small title.
                detailVC.navigationItem.largeTitleDisplayMode = .always

                // 3. Push the view controller as you originally did
                self.navigationController?.pushViewController(detailVC, animated: true)
            }
        } else {
            let storyboard = UIStoryboard(name: "Home", bundle: nil)
            let onboardingVC = storyboard.instantiateViewController(withIdentifier: "DailyProgressOnboarding")
            self.navigationController?.pushViewController(onboardingVC, animated: true)
        }
    }

    @IBAction func awardsTapped(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Awards", bundle: nil)

        if let detailVC = storyboard.instantiateViewController(withIdentifier: "AwardMainViewController") as? AwardMainViewController {

            detailVC.title = "Awards"
            detailVC.loadViewIfNeeded()
            self.navigationController?.pushViewController(detailVC, animated: true)
        }
    }

    @IBAction func dailyTaskTapped(_ sender: UIButton) {
        let targetID = AppState.isDailyChallengesCompleted ? "DailyTasksViewController" : "DailyChallengesOnboarding"

        let storyboard = UIStoryboard(name: "Home", bundle: nil)
        let destinationVC = storyboard.instantiateViewController(withIdentifier: targetID)

        self.navigationController?.pushViewController(destinationVC, animated: true)
    }

    @IBAction func warmUpTapped(_ sender: UIButton) {
        let targetID = AppState.isExercisesCompleted ? "WarmUpListViewController" : "WarmUpOnboarding"

        let storyboard = UIStoryboard(name: "Home", bundle: nil)
        let destinationVC = storyboard.instantiateViewController(withIdentifier: targetID)
        self.navigationController?.pushViewController(destinationVC, animated: true)
    }

    // MARK: - Tab Onboarding Gates

    @IBAction func exerciseTapped(_ sender: UIButton) {
        print("DEBUG [HomePageViewController]: exerciseTapped — isExercisesCompleted=\(AppState.isExercisesCompleted)")
        if AppState.isExercisesCompleted {
            // Already seen onboarding — go straight to Exercise tab
            self.tabBarController?.selectedIndex = 1
        } else {
            let storyboard = UIStoryboard(name: "Home", bundle: nil)
            let onboardingVC = storyboard.instantiateViewController(withIdentifier: "ExerciseOnboarding")
            self.navigationController?.pushViewController(onboardingVC, animated: true)
        }
    }

    @IBAction func readAloudTapped(_ sender: UIButton) {
        print("DEBUG [HomePageViewController]: readAloudTapped — isReadAloudCompleted=\(AppState.isReadAloudCompleted)")
        if AppState.isReadAloudCompleted {
            // Already seen onboarding — go straight to Read Aloud tab
            self.tabBarController?.selectedIndex = 2
        } else {
            let storyboard = UIStoryboard(name: "Home", bundle: nil)
            let onboardingVC = storyboard.instantiateViewController(withIdentifier: "ReadAloudOnboarding")
            self.navigationController?.pushViewController(onboardingVC, animated: true)
        }
    }

    @IBAction func conversationTapped(_ sender: UIButton) {
        print("DEBUG [HomePageViewController]: conversationTapped — isConvoCompleted=\(AppState.isConvoCompleted)")
        if AppState.isConvoCompleted {
            // Already seen onboarding — go straight to Conversation tab
            self.tabBarController?.selectedIndex = 3
        } else {
            let storyboard = UIStoryboard(name: "Home", bundle: nil)
            let onboardingVC = storyboard.instantiateViewController(withIdentifier: "ConversationOnboarding")
            self.navigationController?.pushViewController(onboardingVC, animated: true)
        }
    }

}

extension HomePageViewController {
    func achievedAwardsUpdate() {
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
