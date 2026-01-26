//
//  WarmUpListViewController.swift
//  Spasht
//
//  Created by Prathamesh Patil on 14/11/25.
//

import UIKit

class WarmUpListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var tableView1: UITableView!
    
    var exercises: [Exercise] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView1.dataSource = self
        tableView1.delegate = self
        
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
                self.tableView1.reloadData()
            }
        } catch {
            print("Error decoding JSON: \(error)")
        }
    }
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return exercises.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "ExerciseCell", for: indexPath) as? ExerciseCell else {
            return UITableViewCell()
        }
        
        let exercise = exercises[indexPath.row]
        cell.configure(with: exercise)
        
        cell.playButtonAction = { [weak self] in
            self?.navigateToExercise(with: exercise.name)
        }
        
        return cell
    }
    
    func navigateToExercise(with exerciseName: String) {
        
//        let storyboard = UIStoryboard(name: "Exercise", bundle: nil)
//        let vc = storyboard.instantiateViewController(withIdentifier: exerciseName)
//            
//            print("Error: Could not find VC with ID \(exerciseName)")
//            print("OR that VC does not conform to the 'ExerciseStarting' protocol.")
//            return
//        
//        
//        vc.startingSource = .warmup
//        vc.exerciseName = exerciseName
//        
//        vc.modalPresentationStyle = .fullScreen
//        present(vc, animated: true, completion: nil)
        
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
