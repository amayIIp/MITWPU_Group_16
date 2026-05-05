import UIKit

class WeeklyChallengeCell: UICollectionViewCell {
    
    @IBOutlet weak var cardTitleLabel: UILabel!
    @IBOutlet weak var weeklyChallengeImage: UIImageView!
    @IBOutlet weak var weeklyChallengeName: UILabel!
    @IBOutlet weak var weeklyChallengeDescription: UILabel!
    @IBOutlet weak var showAllButton: UIButton? // Optional button outlet
    
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
        weeklyChallengeImage.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(imageTapped))
        weeklyChallengeImage.addGestureRecognizer(tapGesture)
    }

    private func setupButtonAction() {
        showAllButton?.addTarget(self, action: #selector(showAllTapped), for: .touchUpInside)
    }
    
    @objc private func imageTapped() {
        delegate?.didTapAwardImage(with: currentAward)
    }

    @objc private func showAllTapped() {
        delegate?.didTapShowAll(in: self)
    }
    
    func configure(with award: AwardModel?) {
        self.currentAward = award
        cardTitleLabel.text = "Weekly Challenges"
        
        guard let award = award else { return }
        weeklyChallengeImage.image = UIImage(named: award.id)
        weeklyChallengeName.text = award.name
        
        if award.isCompleted {
            if let date = award.completionDate {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d, yyyy"
                weeklyChallengeDescription.text = formatter.string(from: date)
            }
            weeklyChallengeDescription.textColor = .systemGreen
        } else {
            weeklyChallengeDescription.text = award.status
            weeklyChallengeDescription.textColor = .secondaryLabel
        }
    }
}
