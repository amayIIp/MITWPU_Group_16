//
//  InstructionsViewController.swift
//  Stuttering App 1
//
//  Created by Prathamesh Patil on 09/12/25.
//

import UIKit

class OnboardingInstructionsViewController: UIViewController {
    
    @IBOutlet weak var continueButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        //setupButton()
    }
    
    func setupButton() {
        continueButton.configuration = .prominentGlass()
        continueButton.configuration?.title = "Continue"
    }

}
