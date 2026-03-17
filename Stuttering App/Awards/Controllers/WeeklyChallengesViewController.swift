//
//  WeeklyChallengesViewController.swift
//  Stuttering App 1
//
//  Created by Prathamesh Patil on 15/12/25.
//

import UIKit

class WeeklyChallengesViewController: AwardsBaseViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Weekly Challenges"
    }

    override func loadData() {
        let query = "SELECT * FROM Awards WHERE groupType = 'weekly'"
        var fetchedAwards = AwardsManager.shared.fetchAwards(query: query)
        
        fetchedAwards.sort { (lhs, rhs) -> Bool in
            if lhs.isCompleted && !rhs.isCompleted {
                return true
            }
            
            if !lhs.isCompleted && rhs.isCompleted {
                return false
            }
            
            if lhs.isCompleted && rhs.isCompleted {
                let date1 = lhs.completionDate ?? Date.distantPast
                let date2 = rhs.completionDate ?? Date.distantPast
                return date1 > date2
            }
            
            return lhs.id < rhs.id
        }
        
        self.awards = fetchedAwards
        self.collectionView.reloadData()
    }
}
