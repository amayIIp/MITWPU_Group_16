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
            // Logic A: If LHS is complete and RHS is not, LHS comes first
            if lhs.isCompleted && !rhs.isCompleted {
                return true
            }
            // Logic B: If RHS is complete and LHS is not, RHS comes first
            if !lhs.isCompleted && rhs.isCompleted {
                return false
            }
            
            // Logic C: If BOTH are completed, compare their dates
            if lhs.isCompleted && rhs.isCompleted {
                let date1 = lhs.completionDate ?? Date.distantPast
                let date2 = rhs.completionDate ?? Date.distantPast
                // Returns true if date1 is NEWER than date2 (Descending order)
                return date1 > date2
            }
            
            // Logic D: If BOTH are incomplete, sort by ID for stability (so they don't jump around)
            return lhs.id < rhs.id
        }
        
        // 3. Update data source and reload
        self.awards = fetchedAwards
        self.collectionView.reloadData()
    }
}
