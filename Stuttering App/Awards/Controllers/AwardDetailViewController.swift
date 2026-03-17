//
//  AwardDetailViewController.swift
//  Stuttering App 1
//
//  Created by Prathamesh Patil on 15/12/25.
//

import UIKit

class AwardDetailViewController: UIViewController {
    
    @IBOutlet weak var awardImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var progressBar: UIProgressView!
    
    var award: AwardModel?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        populateData()
    }
    
    private func setupUI() {
        nameLabel.font = .systemFont(ofSize: 28, weight: .bold)
        descriptionLabel.textColor = .secondaryLabel
    }
    
    private func populateData() {
        guard let award = award else { return }
        
        nameLabel.text = award.name
        descriptionLabel.text = award.description
        awardImageView.image = UIImage(named: award.id) ?? UIImage(systemName: "trophy")
        
        if award.isCompleted {
            progressBar.isHidden = true
            awardImageView.alpha = 1.0
            
            if let date = award.completionDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .long
                dateLabel.text = "Earned on " + formatter.string(from: date)
            } else {
                dateLabel.text = "Completed"
            }
            
        } else {
            progressBar.isHidden = false
            progressBar.progress = Float(award.progress)
            awardImageView.alpha = 0.5
            dateLabel.text = award.status
        }
    }
}
