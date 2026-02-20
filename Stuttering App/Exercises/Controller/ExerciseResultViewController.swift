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
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Execute closure after 2.0 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.goToMainScreen()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }
    
    func formatDuration(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds) Sec"
        } else {
            // Using modern rounding style
            let minutes = Int((Double(seconds) / 60.0).rounded())
            return "\(minutes) Min"
        }
    }
    
    func goToMainScreen() {
        if let initialPresenter = self.presentingViewController?.presentingViewController {
            initialPresenter.dismiss(animated: true, completion: nil)
        }
    }
}
