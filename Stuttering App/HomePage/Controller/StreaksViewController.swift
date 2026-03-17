//
//  StreaksViewController.swift
//  Stuttering App
//
//  Created by sdc - user on 10/02/26.
//

import UIKit

class StreaksViewController: UIViewController {

    @IBOutlet weak var streakCountLabel: UILabel!
    @IBOutlet weak var streakTextLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let streak = DatabaseManager.shared.fetchCurrentStreak()
        streakCountLabel.text = String(streak)
        
        if streak == 0 {
            streakTextLabel.text = "You haven't made it to a streak yet!"
        } else {
            streakTextLabel.text = "Daily tasks completed for \(streak) days straight."
        }

    }
}
