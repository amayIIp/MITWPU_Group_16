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
    
    @IBAction func topAchievedAwarsTapped(_ sender: UIButton) {
        let selectedAward = AwardsManager.shared.getTopAchievedAward()
    
        let storyboard = UIStoryboard(name: "Awards", bundle: nil)
        guard let detailVC = storyboard.instantiateViewController(withIdentifier: "AwardDetailViewController") as? AwardDetailViewController else {
            return
        }
        
        detailVC.award = selectedAward
        self.navigationController?.pushViewController(detailVC, animated: true)
    }
}
