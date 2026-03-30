//
//  PracticeViewController.swift
//  Stuttering App
//
//  Created by sdc - user on 26/03/26.
//

import UIKit

class PracticeViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var emptyStateView: UIView!

    @IBOutlet weak var setGoals: UIBarButtonItem!
    private var exerciseLogs: [ExerciseLog] = []
    private var readingLogs: [ExerciseLog] = []
    private var conversationLogs: [ExerciseLog] = []
    
    private var currentDateFilter: Date = Date()
    
    var exerciseTarget = LogManager.shared.getGoal(name: LogManager.GoalKeys.exercise)
    var readingTarget = LogManager.shared.getGoal(name: LogManager.GoalKeys.reading)
    var conversationTarget = LogManager.shared.getGoal(name: LogManager.GoalKeys.conversation)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.dataSource = self
        tableView.delegate = self
        self.navigationItem.largeTitleDisplayMode = .never
        
        emptyStateView.isHidden = true
    }
    
    // MARK: - Navigation Actions

    @IBAction func setGoalsTapped(_ sender: UIBarButtonItem) {
        let setGoalsStoryboard = UIStoryboard(name: "Profile", bundle: nil)
        
        // Ensure "SetGoalsViewController" matches your actual class name
        if let setGoalsVC = setGoalsStoryboard.instantiateViewController(withIdentifier: "SetGoals") as? SetGoalsViewController {
            
            let navController = UINavigationController(rootViewController: setGoalsVC)
            
            // 1. Configure the Sheet (The "Grabber")
            if let sheet = navController.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.prefersGrabberVisible = true
                sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            }
            
            // 2. Add the Cross (Close) Button
            setGoalsVC.title = "Set Goals"
            setGoalsVC.navigationItem.rightBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .close,
                target: self,
                action: #selector(dismissModal) // This now refers to the function below
            )
            
            navController.modalPresentationStyle = .pageSheet
            self.present(navController, animated: true, completion: nil)
        }
    }

    // 3. Move this OUTSIDE of the setGoalsTapped function
    @objc func dismissModal() {
        self.dismiss(animated: true, completion: nil)
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadDataForCurrentDate()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateTableHeaderHeight()
    }
    
    private func loadDataForCurrentDate() {
        exerciseLogs = Array(LogManager.shared.getLogs(for: .exercises, on: self.currentDateFilter).reversed())
        readingLogs = Array(LogManager.shared.getLogs(for: .reading, on: self.currentDateFilter).reversed())
        conversationLogs = Array(LogManager.shared.getLogs(for: .conversation, on: self.currentDateFilter).reversed())
        
        updateEmptyState()
        tableView.reloadData()
    }

    func updateTableHeaderHeight() {
        guard let header = tableView.tableHeaderView else { return }
        let newSize = header.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        
        if header.frame.height != newSize.height {
            header.frame.size.height = newSize.height
            tableView.tableHeaderView = header
        }
    }
    
    private func calculateTotalDuration(for logs: [ExerciseLog]) -> Int {
        let totalSeconds = logs.reduce(0) { (runningTotal, log) -> Int in
            return runningTotal + log.exerciseDuration
        }
        
        let totalMinutes = Int((Double(totalSeconds) / 60.0).rounded())
        return totalMinutes
    }
    
    // MARK: - UITableView DataSource & Delegate
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return exerciseLogs.count
        case 1: return readingLogs.count
        case 2: return conversationLogs.count
        default: return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "LogCell", for: indexPath) as? LogSummaryCell else {
            return UITableViewCell()
        }
        
        let log: ExerciseLog
        
        switch indexPath.section {
        case 0: log = exerciseLogs[indexPath.row]
        case 1: log = readingLogs[indexPath.row]
        case 2: log = conversationLogs[indexPath.row]
        default: return cell
        }
        
        cell.exerciseNameLabel.text = log.exerciseName
        cell.durationLabel.text = formatDuration(log.exerciseDuration)
        
        return cell
    }
    
    func formatDuration(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds) sec"
        } else {
            let minutes = Int((Double(seconds) / 60.0).rounded())
            return "\(minutes) min"
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        var titleText: String?
        var titleText1: String?

        switch section {
        case 0 where !exerciseLogs.isEmpty:
            titleText = "Exercises"
            titleText1 = "\(exerciseLogs.count)/\(exerciseTarget)"
            
        case 1 where !readingLogs.isEmpty:
            let totalReadingMinutes = calculateTotalDuration(for: readingLogs)
            titleText = "Reading"
            titleText1 = "\(totalReadingMinutes)/\(readingTarget) mins"
            
        case 2 where !conversationLogs.isEmpty:
            let totalConvoMinutes = calculateTotalDuration(for: conversationLogs)
            titleText = "Conversation"
            titleText1 = "\(totalConvoMinutes)/\(conversationTarget) mins"
            
        default:
            break
        }

        guard let title = titleText, let subtitle = titleText1 else {
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
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            titleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -8),
            
            countLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 14),
            countLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            countLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -8)
        ])

        return headerView
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let isEmpty: Bool

        switch section {
        case 0: isEmpty = exerciseLogs.isEmpty
        case 1: isEmpty = readingLogs.isEmpty
        case 2: isEmpty = conversationLogs.isEmpty
        default: isEmpty = true
        }

        return isEmpty ? CGFloat.leastNormalMagnitude : UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return CGFloat.leastNormalMagnitude
    }
    
    private func updateEmptyState() {
        let hasAnyData = !exerciseLogs.isEmpty || !readingLogs.isEmpty || !conversationLogs.isEmpty

        tableView.isHidden = !hasAnyData
        emptyStateView.isHidden = hasAnyData
    }
}
