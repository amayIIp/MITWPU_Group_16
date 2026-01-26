import UIKit

class ExerciseCell: UITableViewCell {

    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var timeLabel: UILabel!
    
    var playButtonAction: (() -> Void)?
        
    func configure(with exercise: Exercise) {
        nameLabel.text = exercise.name
        descriptionLabel.text = exercise.description
        timeLabel.text = formatDuration(exercise.short_time)
    }
    
    func formatDuration(_ seconds: Int) -> String {
        if seconds < 60 {
            return String("\(seconds)s")
        } else {
            let minutes = Int((Double(seconds) / 60.0).rounded())
            return String("\(minutes)m")
        }
    }
    
    @IBAction func playButtonTapped(_ sender: UIButton) {
        playButtonAction?()
    }
}
