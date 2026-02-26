//  SummaryViewController.swift

import UIKit

enum SummaryFilter: Int {
    case all = 0
    case dailyTasks = 1
    case exercises = 2
    case reading = 3
    case conversation = 4
}

class SummaryViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var allButton: UIButton!
    @IBOutlet weak var dailyTasksButton: UIButton!
    @IBOutlet weak var exercisesButton: UIButton!
    @IBOutlet weak var readingButton: UIButton!
    @IBOutlet weak var conversationButton: UIButton!
    
    @IBOutlet weak var summaryView1: UIView!
    @IBOutlet weak var summaryView2: UIView!
    
    @IBOutlet weak var emptyStateView: UIView!
    
    @IBOutlet weak var fluencyGrowth: UILabel!
    @IBOutlet weak var blocks: UILabel!
    @IBOutlet weak var averageAccuracy: UILabel!
    @IBOutlet weak var improvement: UILabel!
    @IBOutlet weak var insightsLabel: UILabel!
    private var allFilterButtons: [UIButton] = []
    private var currentDateFilter: Date = Date()
    
    private var activeFilter: SummaryFilter = .all

    private var dailyTaskLogs: [ExerciseLog] = []
    private var exerciseLogs: [ExerciseLog] = []
    private var readingLogs: [ExerciseLog] = []
    private var conversationLogs: [ExerciseLog] = []
    var exerciseTarget = LogManager.shared.getGoal(name: LogManager.GoalKeys.exercise)
    var readingTarget = LogManager.shared.getGoal(name: LogManager.GoalKeys.reading)
    var conversationTarget = LogManager.shared.getGoal(name: LogManager.GoalKeys.conversation)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.dataSource = self
        tableView.delegate = self
        
        allFilterButtons = [allButton, dailyTasksButton, exercisesButton, readingButton, conversationButton]
        
        updateButtonStyles()
        updateSummaryViewsVisibility()
        
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        print("DB Path: \(paths[0].path)")
        
        emptyStateView.isHidden = true
        loadDataForCurrentDate()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadDataForCurrentDate()   // ✅ Only this
    }


    
    @IBAction func filterButtonTapped(_ sender: UIButton) {
        let newFilter = SummaryFilter(rawValue: sender.tag) ?? .all
        self.activeFilter = newFilter
        updateButtonStyles()
        updateSummaryViewsVisibility()
        updateEmptyState()        // ✅ First
        tableView.reloadData()    // ✅ Then reload

    }
    
    private func loadAnalyticsSummary() {
        
        Task {
            let dayReport = await LogManager.shared.getDayReport(for: currentDateFilter)
            let overall   = await LogManager.shared.getOverallProgressReport()

            DispatchQueue.main.async {
                
                // 🔹 FLUENCY GROWTH
                if let overall = overall {
                    self.fluencyGrowth.text = "\(Int(overall.fluencyGrowthPercent))%"
                } else {
                    self.fluencyGrowth.text = "--"
                }
                
                // 🔹 BLOCKS
                if let overall = overall {
                    self.blocks.text = "\(Int(overall.avgBlockPercent))%"
                } else {
                    self.blocks.text = "--"
                }
                
                // 🔹 AVERAGE ACCURACY
                if let overall = overall {
                    self.averageAccuracy.text = "\(Int(overall.avgAccuracy))%"
                } else {
                    self.averageAccuracy.text = "--"
                }
                
                // 🔹 IMPROVEMENT
                if let overall = overall {
                    self.improvement.text = "\(Int(overall.improvementPercent))%"
                } else {
                    self.improvement.text = "--"
                }
                
                // 🔹 INSIGHT
                if let dayReport = dayReport {
                    self.insightsLabel.text = dayReport.insight
                } else {
                    self.insightsLabel.text = "All quiet so far. Let's break the silence with some progress."
                }
            }
        }
    }
    
    private func updateFilterButtonsVisibility() {
        
        if dailyTaskLogs.isEmpty {
            dailyTasksButton.isHidden = true
            dailyTasksButton.alpha = 0
        }
        
        if exerciseLogs.isEmpty {
            exercisesButton.isHidden = true
            exercisesButton.alpha = 0
        }
        
        if readingLogs.isEmpty {
            readingButton.isHidden = true
            readingButton.alpha = 0
        }
        
        if conversationLogs.isEmpty {
            conversationButton.isHidden = true
            conversationButton.alpha = 0
        }
        
        // "All" button should only appear if ANY category has data
        let hasAnyData =
            !dailyTaskLogs.isEmpty ||
            !exerciseLogs.isEmpty ||
            !readingLogs.isEmpty ||
            !conversationLogs.isEmpty

        allButton.isHidden = !hasAnyData
    }


    func updateTableHeaderHeight() {
        guard let header = tableView.tableHeaderView else { return }
        
        // 1. Ask the header to calculate its own size based on the stack view's current state
        let newSize = header.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        
        // 2. Only update if the height effectively changed to avoid loops
        if header.frame.height != newSize.height {
            header.frame.size.height = newSize.height
            
        // 3. Re-assigning the header tells the TableView to refresh the layout
        tableView.tableHeaderView = header
            
            
        }
    }
    
    private func loadDataForCurrentDate() {
        dailyTaskLogs = Array(LogManager.shared.getLogs(for: .dailyTasks, on: self.currentDateFilter).reversed())
        exerciseLogs = Array(LogManager.shared.getLogs(for: .exercises, on: self.currentDateFilter).reversed())
        readingLogs = Array(LogManager.shared.getLogs(for: .reading, on: self.currentDateFilter).reversed())
        conversationLogs = Array(LogManager.shared.getLogs(for: .conversation, on: self.currentDateFilter).reversed())

        updateSummaryViewsVisibility()
        updateFilterButtonsVisibility()
        updateEmptyState()        // ✅ Call here
        tableView.reloadData()    // ✅ Then reload
        
        loadAnalyticsSummary()
    }

    
    private func updateButtonStyles() {
        let activeTag = activeFilter.rawValue
        
        for button in allFilterButtons {
            guard var config = button.configuration else { continue }
            var textAttributes = AttributeContainer()

            if button.tag == activeTag {
                config.baseBackgroundColor = .buttonTheme
                config.baseForegroundColor = .white

                textAttributes.font = UIFont.preferredFont(forTextStyle: .caption1)
            } else {
                config.baseBackgroundColor = .systemBackground
                config.baseForegroundColor = .label
                
                textAttributes.font = UIFont.preferredFont(forTextStyle: .caption1)
            }
            
            if let title = config.title {
                config.attributedTitle = AttributedString(title, attributes: textAttributes)
            }

            button.configuration = config
        }
    }
    
    private func updateSummaryViewsVisibility() {
        if self.activeFilter == .all {
            self.summaryView1.isHidden = false
            self.summaryView2.isHidden = false
        } else {
            self.summaryView1.isHidden = true
            self.summaryView2.isHidden = true
        }
        updateTableHeaderHeight()
            
    }
    
    private func calculateTotalDuration(for logs: [ExerciseLog]) -> Int {
        // Reduce the array to a single sum integer
        // We start at 0, and for every log, add its duration to the running total.
        let totalSeconds = logs.reduce(0) { (runningTotal, log) -> Int in
            return runningTotal + log.exerciseDuration
        }
        
        let totalMinutes = Int((Double(totalSeconds) / 60.0).rounded())
        return totalMinutes
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if activeFilter == .all {
            return 4
        } else {
            return 1
        }
    }

    
//    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
//        switch activeFilter {
//        case .all:
//            switch section {
//            case 0: return dailyTaskLogs.count
//            case 1: return exerciseLogs.count
//            case 2: return readingLogs.count
//            case 3: return conversationLogs.count
//            default: return 0
//            }
//        case .dailyTasks:
//            return dailyTaskLogs.count
//        case .exercises:
//            return exerciseLogs.count
//        case .reading:
//            return readingLogs.count
//        case .conversation:
//            return conversationLogs.count
//        }
//    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        switch activeFilter {

        case .all:
            switch section {
            case 0: return dailyTaskLogs.count
            case 1: return exerciseLogs.count
            case 2: return readingLogs.count
            case 3: return conversationLogs.count
            default: return 0
            }

        case .dailyTasks:
            return dailyTaskLogs.count

        case .exercises:
            return exerciseLogs.count

        case .reading:
            return readingLogs.count

        case .conversation:
            return conversationLogs.count
        }
    }

    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "LogCell", for: indexPath) as? LogSummaryCell else {
            return UITableViewCell()
        }
        
        let log: ExerciseLog
        
        switch activeFilter {
        case .all:
            switch indexPath.section {
            case 0: log = dailyTaskLogs[indexPath.row]
            case 1: log = exerciseLogs[indexPath.row]
            case 2: log = readingLogs[indexPath.row]
            case 3: log = conversationLogs[indexPath.row]
            default:
                return cell
            }
        case .dailyTasks:
            log = dailyTaskLogs[indexPath.row]
        case .exercises:
            log = exerciseLogs[indexPath.row]
        case .reading:
            log = readingLogs[indexPath.row]
        case .conversation:
            log = conversationLogs[indexPath.row]
        }
        
        cell.exerciseNameLabel.text = log.exerciseName
        cell.durationLabel.text = formatDuration(log.exerciseDuration)

        return cell
    }
    
    func formatDuration(_ seconds: Int) -> String {
        if seconds < 60 {
            return String("\(seconds) sec")
        } else {
            let minutes = Int((Double(seconds) / 60.0).rounded())
            return String("\(minutes) min")
        }
    }
    
//    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
//
//        let headerView = UIView()
//        headerView.backgroundColor = .bg
//
//        let titleLabel = UILabel()
//        titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
//        titleLabel.textColor = .label
//        
//        let titleLabel1 = UILabel()
//        titleLabel1.font = UIFont.preferredFont(forTextStyle: .headline)
//        titleLabel1.textColor = .label
//        titleLabel1.textAlignment = .right
//        
//        let titleText: String
//        let titleText1: String
//        
//        switch activeFilter {
//            
//        case .all:
//            switch section {
//            case 0:
//                if !dailyTaskLogs.isEmpty {
//                    titleText = "Daily Tasks"
//                    titleText1 = "\(dailyTaskLogs.count)/5"
//                }
//            case 1:
//                if !exerciseLogs.isEmpty {
//                    titleText = "Exercises"
//                    titleText1 = "\(exerciseLogs.count)/\(exerciseTarget)"
//                    
//                }
//                
//            case 2:
//                let totalReadingMinutes = calculateTotalDuration(for: self.readingLogs)
//                if totalReadingMinutes == 0 {
//                    titleText = "Reading"
//                    titleText1 = "\(totalReadingMinutes)/\(readingTarget)"
//                    
//                }
//                
//            case 3:
//                let totalConvoMinutes = calculateTotalDuration(for: self.conversationLogs)
//                if totalConvoMinutes == 0 {
//                    titleText = "Conversation"
//                    titleText1 = "\(totalConvoMinutes)/\(conversationTarget)"
//                }
//            default:
//                titleText = ""
//                titleText1 = ""
//            }
//            
//        case .dailyTasks:
//            if !dailyTaskLogs.isEmpty {
//                titleText = "Daily Tasks"
//                titleText1 = "\(dailyTaskLogs.count)/5"
//            }
//        case .exercises:
//            if !exerciseLogs.isEmpty {
//                titleText = "Exercises"
//                titleText1 = "\(exerciseLogs.count)/\(exerciseTarget)"
//                
//            }
//        case .reading:
//            let totalReadingMinutes = calculateTotalDuration(for: self.readingLogs)
//            if totalReadingMinutes == 0 {
//                titleText = "Reading"
//                titleText1 = "\(totalReadingMinutes)/\(readingTarget)"
//                
//            }
//        case .conversation:
//            let totalConvoMinutes = calculateTotalDuration(for: self.conversationLogs)
//            if totalConvoMinutes == 0 {
//                titleText = "Conversation"
//                titleText1 = "\(totalConvoMinutes)/\(conversationTarget)"
//            }
//        }
//        
//        titleLabel.text = titleText
//        titleLabel1.text = titleText1
//        
//        headerView.addSubview(titleLabel)
//        titleLabel.translatesAutoresizingMaskIntoConstraints = false
//        
//        NSLayoutConstraint.activate([
//            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 8.0),
//            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16.0),
//            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16.0),
//            titleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -8.0)
//        ])
//        
//        headerView.addSubview(titleLabel1)
//        titleLabel1.translatesAutoresizingMaskIntoConstraints = false
//        
//        NSLayoutConstraint.activate([
//            titleLabel1.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 8.0),
//            titleLabel1.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16.0),
//            titleLabel1.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16.0),
//            titleLabel1.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -8.0)
//        ])
//        
//        return headerView
//    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {

        var titleText: String?
        var titleText1: String?

        switch activeFilter {

        case .all:
            switch section {

            case 0 where !dailyTaskLogs.isEmpty:
                titleText = "Daily Tasks"
                titleText1 = "\(dailyTaskLogs.count)/5"

            case 1 where !exerciseLogs.isEmpty:
                titleText = "Exercises"
                titleText1 = "\(exerciseLogs.count)/\(exerciseTarget)"

            case 2 where !readingLogs.isEmpty:
                let totalReadingMinutes = calculateTotalDuration(for: readingLogs)
                titleText = "Reading"
                titleText1 = "\(totalReadingMinutes)/\(readingTarget)"
                
            case 3 where !conversationLogs.isEmpty:
                let totalConvoMinutes = calculateTotalDuration(for: conversationLogs)
                titleText = "Conversation"
                titleText1 = "\(totalConvoMinutes)/\(conversationTarget)"

            default:
                break
            }

        case .dailyTasks:
            guard !dailyTaskLogs.isEmpty else { return nil }
            titleText = "Daily Tasks"
            titleText1 = "\(dailyTaskLogs.count)/5"

        case .exercises:
            guard !exerciseLogs.isEmpty else { return nil }
            titleText = "Exercises"
            titleText1 = "\(exerciseLogs.count)/\(exerciseTarget)"

        case .reading:
            let totalReadingMinutes = calculateTotalDuration(for: readingLogs)
            guard !readingLogs.isEmpty else { return nil }
            titleText = "Reading"
            titleText1 = "\(totalReadingMinutes)/\(readingTarget)"

        case .conversation:
            let totalConvoMinutes = calculateTotalDuration(for: conversationLogs)
            guard !conversationLogs.isEmpty else { return nil }
            titleText = "Conversation"
            titleText1 = "\(totalConvoMinutes)/\(conversationTarget)"
        }

        guard let title = titleText,
              let subtitle = titleText1 else {
            return nil
        }

        let headerView = UIView()
        headerView.backgroundColor = .bg

        let titleLabel = UILabel()
        titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        titleLabel.textColor = .label
        titleLabel.text = title

        let countLabel = UILabel()
        countLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        countLabel.textColor = .label
        countLabel.textAlignment = .right
        countLabel.text = subtitle

        headerView.addSubview(titleLabel)
        headerView.addSubview(countLabel)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            titleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -8),

            countLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 8),
            countLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            countLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -8)
        ])

        return headerView
    }


    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return UITableView.automaticDimension
    }
    
//    private func updateEmptyStateVisibility() {
//        let hasNoData = dailyTaskLogs.isEmpty &&
//                        exerciseLogs.isEmpty &&
//                        readingLogs.isEmpty &&
//                        conversationLogs.isEmpty
//        
//        self.tableView.isHidden = hasNoData
//        self.emptyStateView.isHidden = !hasNoData
//    }
    private func updateEmptyState() {

        let hasAnyData =
            !dailyTaskLogs.isEmpty ||
            !exerciseLogs.isEmpty ||
            !readingLogs.isEmpty ||
            !conversationLogs.isEmpty

        // Show table only if there is data
        tableView.isHidden = !hasAnyData

        // Show empty state only if there is NO data
        emptyStateView.isHidden = hasAnyData

        // Optional: hide filter buttons when completely empty
        for button in allFilterButtons {
            button.isHidden = !hasAnyData
        }
    }



}

extension SummaryViewController: CalendarDateDelegate {
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showCalendar" {
            guard let calendarVC = segue.destination as? CalendarViewController else { return }
            calendarVC.delegate = self
            calendarVC.selectedDate = self.currentDateFilter
        }
    }
    
    func didSelectDate(_ date: Date) {
        self.currentDateFilter = date
        self.title = date.formatted(date: .abbreviated, time: .omitted)
        loadDataForCurrentDate()
    }
}
