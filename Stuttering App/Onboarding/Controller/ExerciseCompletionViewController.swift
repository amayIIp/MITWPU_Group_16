//
//  ExerciseCompletionViewController.swift
//  Stuttering Final
//
//  Created by SDC-USER on 18/02/26.
//

import UIKit

class ExerciseCompletionViewController: UIViewController, ExerciseStarting {
    
    var startingSource: ExerciseSource?
    var exerciseName: String = "Gentle Onset"
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func startExercise(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Exercise", bundle: nil)
        // 1. Try to find a VC in the Storyboard with ID == Exercise Name
        // We cast to 'ExerciseStarting' to pass data (if your protocol exists)
        // If your Fun VCs don't use the protocol, you can remove the cast or use a base class
        guard let vc = storyboard.instantiateViewController(withIdentifier: "AirFlowInstruction") as? ExerciseInstructionViewController else { return }
        
        // 2. Pass Data if the VC conforms to the protocol
        
        vc.startingSource = .dailyTasks
        vc.exerciseName = exerciseName
        
        
        let ResultNav = UINavigationController(rootViewController: vc)
        ResultNav.modalPresentationStyle = .fullScreen
        self.present(ResultNav, animated: true, completion: nil)
    }
    
    
}
