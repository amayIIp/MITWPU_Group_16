//
//  TestViewController.swift
//  Stuttering App 1
//
//  Created by Prathamesh Patil on 15/12/25.
//

import UIKit

class Test11ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    @IBAction func ab(_ sender: Any) {
        // --- Normal Awards ---
        AwardsManager.shared.updateAwardProgress(id: "nm_001", progress: 1.0, newStatus: "1 of 1 completed")
        AwardsManager.shared.updateAwardProgress(id: "nm_002", progress: 0.6, newStatus: "3 of 5 days")
        AwardsManager.shared.updateAwardProgress(id: "nm_003", progress: 0.25, newStatus: "5 of 20 exercises")
        AwardsManager.shared.updateAwardProgress(id: "nm_005", progress: 0.8, newStatus: "8 of 10 days")
        AwardsManager.shared.updateAwardProgress(id: "nm_006", progress: 0.1, newStatus: "5 of 50 exercises")
        AwardsManager.shared.updateAwardProgress(id: "nm_007", progress: 0.5, newStatus: "5 of 10 sessions")
        AwardsManager.shared.updateAwardProgress(id: "nm_009", progress: 0.33, newStatus: "1 of 3 hours")

        // --- Weekly Awards ---
        AwardsManager.shared.updateAwardProgress(id: "wk_001", progress: 0.57, newStatus: "4 of 7 days")
        AwardsManager.shared.updateAwardProgress(id: "wk_002", progress: 1.0, newStatus: "7 of 7 days")
        AwardsManager.shared.updateAwardProgress(id: "wk_003", progress: 0.75, newStatus: "45 of 60 minutes")
        AwardsManager.shared.updateAwardProgress(id: "wk_005", progress: 0.2, newStatus: "1 of 5 days")
        AwardsManager.shared.updateAwardProgress(id: "wk_008", progress: 0.4, newStatus: "4 of 10 exercises")
    }
    
}
