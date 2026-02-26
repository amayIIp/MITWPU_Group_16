//
//  HistoryCell.swift
//  camtest
//
//  Created by SDC-USER on 13/02/26.
//

import UIKit

class HistoryCell: UITableViewCell {
    
    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var headingLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // iOS 26 UI: Soft, continuous corners for thumbnails
        thumbnailImageView.layer.cornerRadius = 12
        thumbnailImageView.layer.cornerCurve = .continuous
        thumbnailImageView.clipsToBounds = true
        thumbnailImageView.contentMode = .scaleAspectFill
        
        // Default styling
        headingLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        dateLabel.textColor = .secondaryLabel
        durationLabel.textColor = .secondaryLabel
        durationLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .regular)
    }
}
