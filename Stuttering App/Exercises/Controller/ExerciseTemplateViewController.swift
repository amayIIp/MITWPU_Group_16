//
//  SmoothFlowViewController.swift
//  Spasht
//
//  Created by Prathamesh Patil on 15/11/25.
//

import UIKit

class ExerciseTemplateViewController: UIViewController, ExerciseStarting {
    
    @IBOutlet weak var exerciceNameLabel: UILabel!
    
    var startingSource: ExerciseSource?
    var exerciseName: String = ""
    var exerciseDuration: Int = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        exerciceNameLabel.text = exerciseName
    }
    
    @IBAction func closeButtonTapped(_ sender: UIButton) {
        // Optional: Add haptic feedback for iOS 26 feel
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func completedButtonTapped(_ sender: UIButton) {
        
        guard let source = startingSource else {
            print("Error: Source is nil. Dismissing.")
            self.dismiss(animated: true)
            return
        }

        if let duration = ExerciseDataManager.shared.getDurationString(for: exerciseName) {
            self.exerciseDuration = duration
        }
        
        LogManager.shared.addLog(
            exerciseName: self.exerciseName,
            source: source,
            exerciseDuration: self.exerciseDuration
        )
        
        DatabaseManager.shared.markTaskComplete(taskName: self.exerciseName)
        
        navigateToResultScreen()
    }
    
    private func navigateToResultScreen() {
        
        let storyboard = UIStoryboard(name: "Exercise", bundle: nil)
        guard let resultVC = storyboard.instantiateViewController(withIdentifier: "DailyExerciseResult") as? ExerciseResultViewController else {
            print("Error: Could not find ExerciseResult VC")
            return
        }
        
        resultVC.exerciseName = self.exerciseName
        resultVC.durationLabelForExercise = self.exerciseDuration
        
        let resultNav = UINavigationController(rootViewController: resultVC)
        resultNav.modalPresentationStyle = .fullScreen
        self.present(resultNav, animated: true, completion: nil)
    }
}
