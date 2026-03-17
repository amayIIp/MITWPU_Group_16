//
//  LockedViewController.swift
//  Stuttering App 1
//
//  Created by Prathamesh Patil on 15/12/25.
//

import UIKit

class LockedViewController: AwardsBaseViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Locked Awards"
    }
    
    override func loadData() {
        // Fetch 'normal' awards that are NOT complete
        let query = "SELECT * FROM Awards WHERE groupType = 'normal' AND progress < 1.0"
        self.awards = AwardsManager.shared.fetchAwards(query: query)
        self.collectionView.reloadData()
    }
}
