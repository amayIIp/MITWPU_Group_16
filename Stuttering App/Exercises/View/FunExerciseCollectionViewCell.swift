//
//  FunExerciseCollectionViewCell.swift
//  exerciseTest
//
//  Created by Prathamesh Patil on 23/11/25.
//

import UIKit

class FunExerciseCollectionViewCell: UICollectionViewCell {

    static let identifier = "FunExerciseCollectionViewCell"
    static let nibName = "FunExerciseCollectionViewCell"

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var exerciseThumbnail: UIImageView!
    @IBOutlet weak var descriptionLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }

    private func setupUI() {
        contentView.layer.cornerRadius = 20
        contentView.layer.cornerCurve = .continuous
        contentView.backgroundColor = .secondarySystemGroupedBackground

        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOpacity = 0.05
        self.layer.shadowOffset = CGSize(width: 0, height: 2)
        self.layer.shadowRadius = 4
        self.clipsToBounds = false
        self.contentView.clipsToBounds = false

        exerciseThumbnail.clipsToBounds = true
        exerciseThumbnail.layer.cornerRadius = 20
        exerciseThumbnail.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    }

    func configure(with exercise: Exercise) {
        titleLabel.text = exercise.name
        descriptionLabel.text = exercise.description
        exerciseThumbnail.image = UIImage(named: exercise.name) ?? UIImage(systemName: "dumbbell")
    }
}
