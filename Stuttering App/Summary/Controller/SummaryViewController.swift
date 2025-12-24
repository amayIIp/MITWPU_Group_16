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
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
        loadDataForCurrentDate()
    }

    
    @IBAction func filterButtonTapped(_ sender: UIButton) {
        let newFilter = SummaryFilter(rawValue: sender.tag) ?? .all
        self.activeFilter = newFilter
        updateButtonStyles()
        updateSummaryViewsVisibility()
        self.tableView.reloadData()
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
    
        tableView.reloadData()
        
        updateSummaryViewsVisibility()
        updateEmptyStateVisibility()
    }
    
    private func updateButtonStyles() {
        let activeTag = activeFilter.rawValue
        
        for button in allFilterButtons {
            guard var config = button.configuration else { continue }
            var textAttributes = AttributeContainer()

            if button.tag == activeTag {
                config.baseBackgroundColor = .systemBlue
                config.baseForegroundColor = .white

                textAttributes.font = UIFont.systemFont(ofSize: 12, weight: .regular)
            } else {
                config.baseBackgroundColor = .systemBackground
                config.baseForegroundColor = .label
                
                textAttributes.font = UIFont.systemFont(ofSize: 12, weight: .regular)
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
        // 1. Reduce the array to a single sum integer
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
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {

        let headerView = UIView()
        headerView.backgroundColor = .bg

        let titleLabel = UILabel()
        titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        titleLabel.textColor = .secondaryLabel
        
        let titleText: String
        
        switch activeFilter {
            
        case .all:
            switch section {
            case 0:
                titleText = "Daily Tasks   \(dailyTaskLogs.count)/5"
            case 1:
                titleText = "Exercises   \(exerciseLogs.count)/\(exerciseTarget)"
            case 2:
                let totalReadingMinutes = calculateTotalDuration(for: self.readingLogs)
                titleText = "Reading   \(totalReadingMinutes)/\(readingTarget)"
            case 3:
                let totalConvoMinutes = calculateTotalDuration(for: self.conversationLogs)
                titleText = "Conversation   \(totalConvoMinutes)/\(conversationTarget)"
            default:
                titleText = ""
            }
            
        case .dailyTasks:
            titleText = "Daily Tasks   \(dailyTaskLogs.count)/5"
        case .exercises:
            titleText = "Exercises   \(exerciseLogs.count)/\(exerciseTarget)"
        case .reading:
            let totalReadingMinutes = calculateTotalDuration(for: self.readingLogs)
            titleText = "Reading   \(totalReadingMinutes)/\(readingTarget)"
        case .conversation:
            let totalConvoMinutes = calculateTotalDuration(for: self.conversationLogs)
            titleText = "Conversation   \(totalConvoMinutes)/\(conversationTarget)"
        }
        
        titleLabel.text = titleText
        
        headerView.addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 8.0),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16.0),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16.0),
            titleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -8.0)
        ])
        
        return headerView
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    private func updateEmptyStateVisibility() {
        let hasNoData = dailyTaskLogs.isEmpty &&
                        exerciseLogs.isEmpty &&
                        readingLogs.isEmpty &&
                        conversationLogs.isEmpty
        
        self.tableView.isHidden = hasNoData
        self.emptyStateView.isHidden = !hasNoData
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
