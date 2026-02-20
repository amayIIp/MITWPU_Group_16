//
//  DailyTasksViewController.swift
//
//  Created by Prathamesh Patil on 14/11/25.
//

import UIKit

class DailyTasksViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var tableView: UITableView!
    
    var dailyTasks: [DailyTask] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.dataSource = self
        tableView.delegate = self
        
        loadFromDatabase()
        
        NotificationCenter.default.addObserver(self, selector: #selector(loadFromDatabase), name: NSNotification.Name("DailyTasksUpdated"), object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadFromDatabase()
    }
    
    @objc func loadFromDatabase() {
        self.dailyTasks = DatabaseManager.shared.fetchDailyTasks()
        self.tableView.reloadData()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dailyTasks.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "DailyTasksCell", for: indexPath) as? DailyTasksCell else {
                return UITableViewCell()
            }
            
            let task = dailyTasks[indexPath.row]
            cell.configure(with: task)
            
            let firstIncompleteIndex = firstIncompleteTaskIndex()
            let isPlayable = (indexPath.row == firstIncompleteIndex)
            
            // Disable button if not playable
        if task.isCompleted {
            // COMPLETED STATE
            cell.playButton.isEnabled = true
            cell.playButton.alpha = 1.0   // keep full color (green tick)
        }
        else if indexPath.row == firstIncompleteIndex {
            // CURRENT PLAYABLE TASK
            cell.playButton.isEnabled = true
            cell.playButton.alpha = 1.0
        }
        else {
            // LOCKED TASK
            cell.playButton.isEnabled = false
            cell.playButton.alpha = 0.4
        }
            
            cell.playButtonAction = { [weak self] in
                guard isPlayable else { return }
                self?.navigateToExercise(with: task.name)
            }
            
            return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    
    func navigateToExercise(with exerciseName: String) {
        
        let storyboard = UIStoryboard(name: "Exercise", bundle: nil)
    
        guard let vc = storyboard.instantiateViewController(withIdentifier: "AirFlowInstruction") as? ExerciseInstructionViewController else {
            print("Error: Could not find ExerciseResult VC")
            return
        }
        
        vc.startingSource = .dailyTasks
        vc.exerciseName = exerciseName
        
        let ResultNav = UINavigationController(rootViewController: vc)
        ResultNav.modalPresentationStyle = .fullScreen
        self.present(ResultNav, animated: true, completion: nil)
    }
    
    func firstIncompleteTaskIndex() -> Int? {
        return dailyTasks.firstIndex(where: { !$0.isCompleted })
    }

}
