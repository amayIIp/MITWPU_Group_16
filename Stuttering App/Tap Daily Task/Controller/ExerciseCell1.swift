import UIKit

class ExerciseCell1: UITableViewCell {

    // 1. Connect these from your Storyboard prototype cell
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var playButton: UIButton!
    
    // 2. Connect the label *inside* the container
    @IBOutlet weak var durationLabel: UILabel!
    
    
    // This closure remains the same
    

    // 5. This configuration function is still correct
//    func configure(with exercise: Exercise) {
//        nameLabel.text = exercise.name
//        descriptionLabel.text = exercise.description
//        timeLabel.text = exercise.short_time
//    }
    
    // 6. This action remains the same
}
