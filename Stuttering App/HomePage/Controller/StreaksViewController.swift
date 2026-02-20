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
        }else {
            streakTextLabel.text = "Daily tasks completed for \(streak) days straight."
        }

        // Do any additional setup after loading the view.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
