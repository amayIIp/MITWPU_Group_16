import UIKit

class DailyTasksCell: UITableViewCell {

    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var timeLabel: UILabel!
    
    
    var playButtonAction: (() -> Void)?
    
    func setCompleted(_ completed: Bool) {
        if completed {
            playButton.tintColor = .systemGreen
            let checkmarkIcon = UIImage(systemName: "checkmark.circle.fill")
            playButton.setImage(checkmarkIcon, for: .normal)
            
        } else {
            playButton.tintColor = UIColor(named: "ButtonTheme") ?? .systemBlue
            let playIcon = UIImage(systemName: "play.circle.fill")
            playButton.setImage(playIcon, for: .normal)
        }
    }

    func configure(with task: DailyTask) {
        nameLabel.text = task.name
        descriptionLabel.text = task.description
        timeLabel.text = formatDuration(task.duration)
        setCompleted(task.isCompleted)
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
