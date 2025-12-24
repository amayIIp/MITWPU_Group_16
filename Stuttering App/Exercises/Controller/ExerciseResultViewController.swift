//
//  ExerciseResultViewController.swift
//  Spasht
//
//  Created by Prathamesh Patil on 15/11/25.
//

import UIKit

class ExerciseResultViewController: UIViewController {
    
    var exerciseName: String = ""
    var durationLabelForExercise: Int = 0
    
    @IBOutlet weak var exerciceNameLabel: UILabel!
    @IBOutlet weak var exerciseDurationLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        exerciceNameLabel.text = exerciseName
        exerciseDurationLabel.text = formatDuration(durationLabelForExercise)


    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }
    
    func formatDuration(_ seconds: Int) -> String {
        if seconds < 60 {
            return String("\(seconds) Sec")
        } else {
            let minutes = Int((Double(seconds) / 60.0).rounded())
            return String("\(minutes) Min")
        }
    }
    
    @IBAction func tapToMainScreen(_ sender: Any) {
        if let initialPresenter = self.presentingViewController?.presentingViewController {
                initialPresenter.dismiss(animated: true, completion: nil)
            }
    }
    
    @IBAction func RepeatTheExercise(_ sender: Any) {
        
        if exerciseName == "Airflow Practice" {
            guard let navPresenter = self.presentingViewController as? UINavigationController ?? self.presentingViewController?.navigationController else {
                        print("Error: Could not find the underlying Navigation Controller.")
                        self.dismiss(animated: true) // Safety fallback
                        return
                    }

                    // Step 2: Dismiss this 3rd View Controller
                    self.dismiss(animated: true) {
                        // Step 3: executed ONLY after the modal is fully gone
                        // This ensures animations do not conflict
                        navPresenter.popToRootViewController(animated: true)
                    }
        } else {
            self.dismiss(animated: true, completion: nil)
        }
        
    }
    

}
           
