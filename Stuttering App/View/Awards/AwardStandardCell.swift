import UIKit

class AwardStandardCell: UICollectionViewCell {

    @IBOutlet weak var cardTitleLabel: UILabel!
    @IBOutlet weak var awardImage: UIImageView!
    @IBOutlet weak var awardName: UILabel!
    @IBOutlet weak var awardDescription: UILabel!
    @IBOutlet weak var showAllButton: UIButton!

    weak var delegate: AwardCellDelegate?
    private var currentAward: AwardModel?

    override func awakeFromNib() {
        super.awakeFromNib()
        setupCardStyle()
        setupImageTapGesture()
        setupButtonAction()
    }

    private func setupCardStyle() {
        contentView.backgroundColor = .systemBackground
        contentView.layer.cornerRadius = 20
        contentView.layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.05
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 10
        layer.masksToBounds = false
    }

    private func setupImageTapGesture() {
        awardImage.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(imageTapped))
        awardImage.addGestureRecognizer(tapGesture)
    }

    private func setupButtonAction() {
        showAllButton.addTarget(self, action: #selector(showAllTapped), for: .touchUpInside)
    }

    @objc private func imageTapped() {
        delegate?.didTapAwardImage(with: currentAward)
    }

    @objc private func showAllTapped() {
        delegate?.didTapShowAll(in: self)
    }

    func configureAsAchieved(with award: AwardModel?) {
        self.currentAward = award
        cardTitleLabel.text = "Achieved"
        awardImage.alpha = 1.0

        if let award = award {
            awardImage.image = UIImage(named: award.id)
            awardImage.tintColor = .clear
            awardName.text = award.name
            if let date = award.completionDate {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d, yyyy"
                awardDescription.text = formatter.string(from: date)
            }
            awardDescription.textColor = .secondaryLabel
        } else {
            awardImage.image = UIImage(systemName: "figure.run.circle.fill")
            awardImage.tintColor = .systemOrange
            awardName.text = "Start exercises!"
            awardDescription.text = "First award awaits"
            awardDescription.textColor = .secondaryLabel
        }
    }

    func configureAsLocked(with award: AwardModel?) {
        self.currentAward = award
        cardTitleLabel.text = "Locked"
        if let award = award {
            awardImage.image = UIImage(named: award.id)
            awardImage.tintColor = .clear
            awardImage.alpha = 0.3
            awardName.text = award.name
            awardDescription.text = award.status
            awardDescription.textColor = .secondaryLabel
        } else {
            awardImage.image = UIImage(systemName: "lock.open.fill")
            awardImage.tintColor = .systemGreen
            awardImage.alpha = 1.0
            awardName.text = "All Unlocked!"
            awardDescription.text = "You have every badge."
            awardDescription.textColor = .secondaryLabel
        }
    }
}
