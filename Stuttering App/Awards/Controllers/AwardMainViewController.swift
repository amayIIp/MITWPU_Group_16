import UIKit

// MARK: - Protocol Definition
protocol AwardCellDelegate: AnyObject {
    func didTapAwardImage(with award: AwardModel?)
    func didTapShowAll(in cell: UICollectionViewCell)
}

class AwardMainViewController: UIViewController {

    // MARK: - Outlets
    @IBOutlet weak var collectionView: UICollectionView!

    // MARK: - Data Models
    private var weeklyAward: AwardModel?
    private var achievedAward: AwardModel?
    private var lockedAward: AwardModel?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        fetchData()
        setupCollectionView()
    }

    private func fetchData() {
        weeklyAward = AwardsManager.shared.getTopWeeklyChallenge()
        achievedAward = AwardsManager.shared.getTopAchievedAward()
        lockedAward = AwardsManager.shared.getTopLockedAward()
    }

    private func setupCollectionView() {
        collectionView.register(UINib(nibName: "WeeklyChallengeCell", bundle: nil), forCellWithReuseIdentifier: "WeeklyChallengeCell")
        collectionView.register(UINib(nibName: "AwardStandardCell", bundle: nil), forCellWithReuseIdentifier: "AwardStandardCell")

        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.backgroundColor = .clear
        collectionView.collectionViewLayout = createCompositionalLayout()
    }

    // MARK: - Unified Navigation Logic
    /// This handles navigation for both Card Taps and Show All button taps
    private func handleNavigation(at indexPath: IndexPath) {
        let storyboard = UIStoryboard(name: "Awards", bundle: nil)

        if indexPath.section == 0 {
            // Weekly Challenge Navigation
            let vcA = storyboard.instantiateViewController(withIdentifier: "WeeklyChallengesViewController")
            navigationController?.pushViewController(vcA, animated: true)

        } else if indexPath.section == 1 {
            if indexPath.item == 0 {
                // Achieved Navigation
                let vcB = storyboard.instantiateViewController(withIdentifier: "AchievedViewController")
                navigationController?.pushViewController(vcB, animated: true)

            } else if indexPath.item == 1 {
                // Locked Navigation
                let vcC = storyboard.instantiateViewController(withIdentifier: "LockedViewController")
                navigationController?.pushViewController(vcC, animated: true)
            }
        }
    }

    private func createCompositionalLayout() -> UICollectionViewLayout {
        return UICollectionViewCompositionalLayout { (sectionIndex, _) -> NSCollectionLayoutSection? in
            if sectionIndex == 0 {
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(320))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(320))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
                return section
            } else {
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5), heightDimension: .estimated(240))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 6)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(240))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 10, bottom: 16, trailing: 10)
                return section
            }
        }
    }
}

// MARK: - UICollectionViewDataSource & Delegate
extension AwardMainViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return section == 0 ? 1 : 2
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == 0 {
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "WeeklyChallengeCell",
                for: indexPath
            ) as? WeeklyChallengeCell else {
                return UICollectionViewCell()
            }
            cell.delegate = self
            cell.configure(with: weeklyAward)
            return cell
        } else {
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "AwardStandardCell",
                for: indexPath
            ) as? AwardStandardCell else {
                return UICollectionViewCell()
            }
            cell.delegate = self
            if indexPath.item == 0 {
                cell.configureAsAchieved(with: achievedAward)
            } else {
                cell.configureAsLocked(with: lockedAward)
            }
            return cell
        }
    }

    // Card Tap
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        handleNavigation(at: indexPath)
    }
}

// MARK: - AwardCellDelegate
extension AwardMainViewController: AwardCellDelegate {

    // Button Tap
    func didTapShowAll(in cell: UICollectionViewCell) {
        if let indexPath = collectionView.indexPath(for: cell) {
            handleNavigation(at: indexPath)
        }
    }

    // Image Tap (Specific Award Detail)
    func didTapAwardImage(with award: AwardModel?) {
        guard let selectedAward = award else { return }
        let storyboard = UIStoryboard(name: "Awards", bundle: nil)
        guard let detailVC = storyboard.instantiateViewController(withIdentifier: "AwardDetailViewController") as? AwardDetailViewController else { return }
        detailVC.award = selectedAward
        navigationController?.pushViewController(detailVC, animated: true)
    }
}
