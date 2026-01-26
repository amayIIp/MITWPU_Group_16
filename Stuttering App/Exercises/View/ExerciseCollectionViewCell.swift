//
//  ExerciseCollectionViewCell.swift
//  exerciseTest
//
//  Created by Prathamesh Patil on 22/11/25.
//

import UIKit

class ExerciseCollectionViewCell: UICollectionViewCell {
    
    // MARK: - Identifiers
    static let identifier = "ExerciseCollectionViewCell"
    static let nibName = "ExerciseCollectionViewCell" // Ensure your XIB file has this name

    // MARK: - Outlets
    // Connect these to your labels in the XIB file
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var captionLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var actionButton: UIButton!
    @IBOutlet weak var exerciseLogo: UIImageView!
    
    var didTapButton: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }

    // MARK: - UI Setup
    private func setupUI() {
        // iOS 16+ Aesthetic: Clean corners and smooth font rendering
        self.contentView.layer.cornerRadius = 12
        self.contentView.layer.cornerCurve = .continuous
        self.contentView.clipsToBounds = true
        self.backgroundColor = .systemBackground
        
        // Optional: Add a subtle background color if your XIB is transparent
        // self.contentView.backgroundColor = .secondarySystemGroupedBackground
    }

    // MARK: - Configuration
    func configure(with exercise: Exercise) {
        titleLabel.text = exercise.name
        captionLabel.text = exercise.description
        exerciseLogo.image = UIImage(named: exercise.name) ?? UIImage(systemName: "dumbbell")
        // Formatting the time label to stand out (e.g., pills or distinct color)
        timeLabel.text = formatDuration(exercise.short_time)
        
        // Accessibility hints for VoiceOver users
        
    }
    
    func formatDuration(_ seconds: Int) -> String {
        if seconds < 60 {
            return String("\(seconds)s")
        } else {
            let minutes = Int((Double(seconds) / 60.0).rounded())
            return String("\(minutes)m")
        }
    }
    
    @IBAction func buttonPressed(_ sender: UIButton) {
        // Trigger the callback when pressed
        didTapButton?()
    }
    
    // MARK: - Selection State
    // Adds a visual touch feedback when the user taps the cell
    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.2) {
                self.contentView.alpha = self.isHighlighted ? 0.7 : 1.0
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.98, y: 0.98) : .identity
            }
        }
    }
}
