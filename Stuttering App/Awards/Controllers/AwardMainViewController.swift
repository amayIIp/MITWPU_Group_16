//
//  AwardMainViewController.swift
//  Stuttering App 1
//
//  Created by Prathamesh Patil on 16/12/25.
//

import UIKit

class AwardMainViewController: UIViewController {
    
    @IBOutlet weak var weeklyChallengeImage: UIImageView!
    @IBOutlet weak var weeklyChallengeName: UILabel!
    @IBOutlet weak var weeklyChallengeDescription: UILabel!
    
    @IBOutlet weak var achievedAwardImage: UIImageView!
    @IBOutlet weak var achievedAwardName: UILabel!
    @IBOutlet weak var achievedAwardDescription: UILabel!
    
    @IBOutlet weak var lockedAwardImage: UIImageView!
    @IBOutlet weak var lockedAwardName: UILabel!
    @IBOutlet weak var lockedAwardDescription: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        WeeklyChallangeUpdate()
        AchievedAwardsUpdate()
        LockedAwardsUpdate()
    }
    
    func WeeklyChallangeUpdate() {
        if let award = AwardsManager.shared.getTopWeeklyChallenge() {
            
            weeklyChallengeImage.image = UIImage(named: award.id)
            weeklyChallengeName.text = award.name
            
            if award.isCompleted {
                if let date = award.completionDate {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "MMM d, yyyy"
                    weeklyChallengeDescription.text = "\(formatter.string(from: date))"
                }
                weeklyChallengeDescription.textColor = .systemGreen
            } else {
                weeklyChallengeDescription.text = award.status
                weeklyChallengeDescription.textColor = .secondaryLabel
            }
        }
    }
    
    func AchievedAwardsUpdate() {
        if let award = AwardsManager.shared.getTopAchievedAward() {
            achievedAwardImage.image = UIImage(named: award.id)
            achievedAwardName.text = award.name
            achievedAwardImage.tintColor = .clear
            
            if let date = award.completionDate {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d, yyyy"
                achievedAwardDescription.text = "\(formatter.string(from: date))"
            }
            achievedAwardDescription.textColor = .secondaryLabel
            
        } else {
            achievedAwardImage.image = UIImage(systemName: "figure.run.circle.fill")
            achievedAwardImage.tintColor = .systemOrange
            achievedAwardName.text = "Start doing exercises!"
            achievedAwardDescription.text = "Your first award awaits"
            achievedAwardDescription.textColor = .secondaryLabel
        }
    }
    
    func LockedAwardsUpdate() {
        
        if let award = AwardsManager.shared.getTopLockedAward() {
            lockedAwardImage.image = UIImage(named: award.id)
            lockedAwardName.text = award.name
            lockedAwardDescription.text = award.status
            lockedAwardDescription.textColor = .secondaryLabel
            lockedAwardImage.alpha = 0.5
            lockedAwardImage.tintColor = .clear
            
        } else {
            lockedAwardImage.image = UIImage(systemName: "lock.open.fill")
            lockedAwardImage.tintColor = .systemGreen
            lockedAwardImage.alpha = 1.0
            lockedAwardName.text = "All Unlocked!"
            lockedAwardDescription.text = "You have collected every badge."
            lockedAwardDescription.textColor = .secondaryLabel
        }
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
