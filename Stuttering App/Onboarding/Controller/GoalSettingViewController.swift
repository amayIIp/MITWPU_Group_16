//
//  GoalSettingViewController.swift
//  Stuttering Final
//
//  Created by SDC-USER on 18/02/26.
//

import UIKit

class GoalSettingViewController: UIViewController {
    
    @IBOutlet weak var instructionLabel: UILabel!
    @IBOutlet weak var instructionLabel1: UILabel!
    @IBOutlet weak var continueButton: UIButton!

    override func viewDidLoad() {
            super.viewDidLoad()

            // 1. Prepare initial state
            instructionLabel1.isHidden = true
            instructionLabel1.alpha = 0
            continueButton.isHidden = true
            continueButton.alpha = 0
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)

            // 2. Execute transition after 2 seconds
            UIView.animate(withDuration: 0.5, delay: 2.0, options: .curveEaseInOut, animations: {
                // Fade out the first label
                self.instructionLabel.alpha = 0
                
                // Prepare and fade in the new elements
                self.instructionLabel1.isHidden = false
                self.continueButton.isHidden = false
                self.instructionLabel1.alpha = 1.0
                self.continueButton.alpha = 1.0
            }) { _ in
                // Clean up by hiding the first label completely
                self.instructionLabel.isHidden = true
            }
        }

}
