//
//  WarmUpListViewController.swift
//  Spasht
//
//  Created by Prathamesh Patil on 14/11/25.
//  Updated: Phoneme-based dynamic warmup selection.
//

import UIKit

class WarmUpListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var tableView: UITableView!
    
    /// The 5 exercises shown in the table — always exactly 5.
    var exercises: [Exercise] = []
    
    /// Quick-lookup dict built from exerciselogs.json (the master catalogue).
    private var exerciseCatalogue: [String: Exercise] = [:]

    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.largeTitleDisplayMode = .always
        tableView.dataSource = self
        tableView.delegate = self
        let customNib = UINib(nibName: "TableViewCell", bundle: nil)
        tableView.register(customNib, forCellReuseIdentifier: "TableViewCell")
        
        buildCatalogue()
        loadExercises()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Refresh so that lastCompleted ordering updates after a warmup session finishes.
        loadExercises()
    }
    
    // MARK: - Data Loading
    
    /// Builds a name→Exercise dictionary from the master exerciselogs.json catalogue.
    private func buildCatalogue() {
        guard let url = Bundle.main.url(forResource: "exerciselogs", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("⚠️ [Warmup] Could not load exerciselogs.json for catalogue")
            return
        }
        do {
            let result = try JSONDecoder().decode(LibraryData.self, from: data)
            for section in result.sections {
                for group in section.groups {
                    for exercise in group.exercises {
                        let key = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        exerciseCatalogue[key] = exercise
                    }
                }
            }
            print("✅ [Warmup] Catalogue built with \(exerciseCatalogue.count) exercises")
        } catch {
            print("⚠️ [Warmup] Catalogue parse error: \(error)")
        }
    }
    
    /// Loads exactly 5 exercises, phoneme-personalised if possible, otherwise static fallback.
    func loadExercises() {
        let dynamicNames = DatabaseManager.shared.fetchWarmupExercises()
        
        if !dynamicNames.isEmpty {
            // Map names → Exercise structs using the catalogue.
            // Any name not found in the catalogue is skipped (shouldn't happen in practice).
            let mapped = dynamicNames.compactMap { exerciseCatalogue[$0] }
            
            if mapped.count == dynamicNames.count {
                exercises = mapped
                print("🔥 [Warmup] Loaded \(exercises.count) phoneme-personalised exercises")
            } else {
                // Some names didn't resolve — fill remaining slots from static list
                print("⚠️ [Warmup] \(dynamicNames.count - mapped.count) exercises not found in catalogue. Using static fallback.")
                exercises = loadStaticFallback()
            }
        } else {
            // No phoneme data saved — show the default static list
            exercises = loadStaticFallback()
            print("🔥 [Warmup] No phoneme data. Using static WarmUp.json list.")
        }
        
        tableView?.reloadData()
    }
    
    /// Loads the original static WarmUp.json list (5 hand-picked exercises).
    private func loadStaticFallback() -> [Exercise] {
        guard let url = Bundle.main.url(forResource: "WarmUp", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Exercise].self, from: data) else {
            print("⚠️ [Warmup] Could not load WarmUp.json fallback")
            return []
        }
        return decoded
    }
    
    // MARK: - Table View
    
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
    
    // MARK: - Navigation
    
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
