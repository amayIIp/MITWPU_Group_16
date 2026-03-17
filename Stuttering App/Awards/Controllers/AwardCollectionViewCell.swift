//
//  AwardCollectionViewCell.swift
//  Stuttering App 1
//
//  Created by Prathamesh Patil on 15/12/25.
//

import UIKit

class AwardCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var awardImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var progressBar: UIProgressView!

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    func configure(with model: AwardModel) {
        nameLabel.text = model.name
        awardImageView.image = UIImage(named: model.id) ?? UIImage(systemName: "trophy")
        
        if model.isCompleted {
            progressBar.isHidden = true
            awardImageView.alpha = 1.0
            
            if let date = model.completionDate {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d, yyyy"
                dateLabel.text = "\(formatter.string(from: date))"
            } else {
                dateLabel.text = "Completed"
            }
            dateLabel.textColor = .secondaryLabel
            
        } else {
            progressBar.isHidden = false
            progressBar.progress = Float(model.progress)
            awardImageView.alpha = 0.5
            
            dateLabel.text = model.status
            dateLabel.textColor = .secondaryLabel
        }
    }
}
