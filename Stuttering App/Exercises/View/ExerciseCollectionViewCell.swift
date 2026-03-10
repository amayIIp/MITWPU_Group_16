//
//  ExerciseCollectionViewCell.swift
//  exerciseTest
//
//  Created by Prathamesh Patil on 22/11/25.
//

import UIKit

class ExerciseCollectionViewCell: UICollectionViewCell {
    
    static let identifier = "ExerciseCollectionViewCell"
    static let nibName = "ExerciseCollectionViewCell"

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var captionLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var actionButton: UIButton!
    
    var didTapButton: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }

    private func setupUI() {
        self.contentView.layer.cornerRadius = 12
        self.contentView.layer.cornerCurve = .continuous
        self.contentView.clipsToBounds = true
        self.backgroundColor = .systemBackground
    }

    func configure(with exercise: Exercise) {
        titleLabel.text = exercise.name
        captionLabel.text = exercise.description
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
    
    @IBAction func buttonPressed(_ sender: UIButton) {
        didTapButton?()
    }
    
    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.2) {
                self.contentView.alpha = self.isHighlighted ? 0.7 : 1.0
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.98, y: 0.98) : .identity
            }
        }
    }
}
