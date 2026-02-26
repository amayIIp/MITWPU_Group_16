//
//  AudioHistoryCell.swift
//  Stuttering Final
//
//  Created by SDC-USER on 18/02/26.
//

import UIKit

class AudioHistoryCell: UITableViewCell {

    @IBOutlet weak var headingLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Default styling
        headingLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        dateLabel.textColor = .secondaryLabel
        durationLabel.textColor = .secondaryLabel
        durationLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .regular)
    }
}
