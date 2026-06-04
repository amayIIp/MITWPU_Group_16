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

    func loadExercises() {
        let dynamicNames = DatabaseManager.shared.fetchWarmupExercises()

        if !dynamicNames.isEmpty {
            let mapped = dynamicNames.compactMap { exerciseCatalogue[$0] }

            if mapped.count == dynamicNames.count {
                exercises = mapped
                print("🔥 [Warmup] Loaded \(exercises.count) phoneme-personalised exercises")
            } else {
                print("⚠️ [Warmup] \(dynamicNames.count - mapped.count) exercises not found. Using fallback.")
                exercises = loadStaticFallback()
            }
        } else {
            exercises = loadStaticFallback()
            print("🔥 [Warmup] No phoneme data. Using static WarmUp.json list.")
        }

        tableView?.reloadData()
    }

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

        // --- FIX: Prevents the cell from staying gray when tapped ---
        cell.selectionStyle = .none

        let exercise = exercises[indexPath.row]
        cell.configureForWarmUp(with: exercise)

        // Handling tap on the specific play button
        cell.playButtonAction = { [weak self] in
            self?.navigateToExercise(with: exercise.name)
        }

        return cell
    }

    // This handles the row tap behavior
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // 1. Deselect immediately (just in case)
        tableView.deselectRow(at: indexPath, animated: true)

        // 2. Trigger the navigation
        let exercise = exercises[indexPath.row]
        navigateToExercise(with: exercise.name)
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

        let resultNav = UINavigationController(rootViewController: vc)
        resultNav.modalPresentationStyle = .fullScreen
        self.present(resultNav, animated: true, completion: nil)
    }

}
