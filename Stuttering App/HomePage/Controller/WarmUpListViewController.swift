//
//  WarmUpListViewController.swift
//  Spasht
//
//  Created by Prathamesh Patil on 14/11/25.
//

import UIKit

class WarmUpListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var tableView: UITableView!
    
    var exercises: [Exercise] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.dataSource = self
        tableView.delegate = self
        let customNib = UINib(nibName: "TableViewCell", bundle: nil)
        tableView.register(customNib, forCellReuseIdentifier: "TableViewCell")
        
        loadExercises()
    }
    
    func loadExercises() {
        guard let url = Bundle.main.url(forResource: "WarmUp", withExtension: "json") else {
            print("JSON file not found")
            return
        }
        guard let data = try? Data(contentsOf: url) else {
            print("Could not load data")
            return
        }
    
        do {
            let decoder = JSONDecoder()
            self.exercises = try decoder.decode([Exercise].self, from: data)
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        } catch {
            print("Error decoding JSON: \(error)")
        }
    }
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return exercises.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "TableViewCell", for: indexPath) as? TableViewCell else {
            return UITableViewCell()
        }
        
        let exercise = exercises[indexPath.row]
        cell.configureForWarmUp(with: exercise)
        
        cell.playButtonAction = { [weak self] in
            self?.navigateToExercise(with: exercise.name)
        }
        
        return cell
    }
    
    func navigateToExercise(with exerciseName: String) {
        let storyboard = UIStoryboard(name: "Exercise", bundle: nil)
    
        guard let vc = storyboard.instantiateViewController(withIdentifier: "AirFlowInstruction") as? ExerciseInstructionViewController else {
            print("Error: Could not find ExerciseResult VC")
            return
        }
        
        vc.startingSource = .warmup
        vc.exerciseName = exerciseName
        
        let ResultNav = UINavigationController(rootViewController: vc)
        ResultNav.modalPresentationStyle = .fullScreen
        self.present(ResultNav, animated: true, completion: nil)
    }

}
