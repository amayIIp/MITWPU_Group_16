import UIKit

class WarmupCell: UITableViewCell {

    // MARK: - Outlets
    // 1. Connect these from your Storyboard prototype cell
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var playButton: UIButton!
    
    // 2. Connect the label *inside* the gray container
    @IBOutlet weak var durationLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
    }
}
