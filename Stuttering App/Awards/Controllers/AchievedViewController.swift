//
//  AchievedViewController.swift
//  Stuttering App 1
//
//  Created by Prathamesh Patil on 15/12/25.
//

import UIKit

class AchievedViewController: AwardsBaseViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Achieved"
    }
    
    override func loadData() {
        // Fetch awards where progress is 100% (1.0)
        let query = "SELECT * FROM Awards WHERE progress >= 1.0"
        self.awards = AwardsManager.shared.fetchAwards(query: query)
        self.collectionView.reloadData()
    }
}
