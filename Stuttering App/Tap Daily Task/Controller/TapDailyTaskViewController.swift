//
//  TapDailyTaskViewController.swift
//  Stuttering App
//
//  Created by SDC-USER on 27/11/25.
//

import UIKit

class TapDailyTaskViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet weak var tableView: UITableView!
    
    var exercises: [Exercise] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        fetchExercisesFromJSON()
    }
    
    private func fetchExercisesFromJSON() {
        guard let url = Bundle.main.url(forResource: "exercises", withExtension: "json") else {
            print("Error: exercises.json not found.")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            self.exercises = try JSONDecoder().decode([Exercise].self, from: data)
            DispatchQueue.main.async { self.tableView.reloadData() }
        } catch {
            print("Error parsing JSON: \(error)")
        }
    }
    
    // MARK: - TableView Data Source
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return exercises.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "ExerciseCell1", for: indexPath) as? ExerciseCell1 else {
            return UITableViewCell()
        }

        let exercise = exercises[indexPath.row]
        
        // 1. Text
        cell.titleLabel.text = exercise.title
        cell.descriptionLabel.text = exercise.description
        cell.durationLabel.text = exercise.duration
        
        // 2. Button Color
//        if var config = cell.playButton.configuration {
//            config.baseBackgroundColor = exercise.isCompleted ? .systemGreen : .systemBlue
//            config.baseForegroundColor = .white
//            cell.playButton.configuration = config
//        }
//
        

        return cell
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
