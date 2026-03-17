//
//  AwardMainViewController.swift
//  Stuttering App 1
//

import UIKit

protocol AwardCellDelegate: AnyObject {
    func didTapAwardImage(with award: AwardModel?)
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
    
    // MARK: - Data Setup
    private func fetchData() {
        weeklyAward = AwardsManager.shared.getTopWeeklyChallenge()
        achievedAward = AwardsManager.shared.getTopAchievedAward()
        lockedAward = AwardsManager.shared.getTopLockedAward()
    }
    
    // MARK: - Collection View Setup
    private func setupCollectionView() {
        // Register XIBs - Ensure these strings match your exact .xib file names
        collectionView.register(UINib(nibName: "WeeklyChallengeCell", bundle: nil), forCellWithReuseIdentifier: "WeeklyChallengeCell")
        collectionView.register(UINib(nibName: "AwardStandardCell", bundle: nil), forCellWithReuseIdentifier: "AwardStandardCell")
        
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.backgroundColor = .clear
        collectionView.collectionViewLayout = createCompositionalLayout()
    }
    
    // MARK: - iOS 26 Compositional Layout
    private func createCompositionalLayout() -> UICollectionViewLayout {
        return UICollectionViewCompositionalLayout { (sectionIndex, layoutEnvironment) -> NSCollectionLayoutSection? in
            
            if sectionIndex == 0 {
                // Section 0: Weekly Challenge (Full Width)
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(320))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(320))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
                return section
                
            } else {
                // Section 1: Achieved & Locked (2 Columns)
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
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "WeeklyChallengeCell", for: indexPath) as! WeeklyChallengeCell
            cell.delegate = self // Set the delegate
            cell.configure(with: weeklyAward)
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AwardStandardCell", for: indexPath) as! AwardStandardCell
            cell.delegate = self // Set the delegate
            if indexPath.item == 0 {
                cell.configureAsAchieved(with: achievedAward)
            } else {
                cell.configureAsLocked(with: lockedAward)
            }
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let storyboard = UIStoryboard(name: "Awards", bundle: nil) // Update bundle name if needed
        
        if indexPath.section == 0 {
            // Weekly Challenge Card Tapped
            let vcA = storyboard.instantiateViewController(withIdentifier: "WeeklyChallengesViewController")
            navigationController?.pushViewController(vcA, animated: true)
            
        } else if indexPath.section == 1 {
            if indexPath.item == 0 {
                // Achieved Card Tapped
                let vcB = storyboard.instantiateViewController(withIdentifier: "AchievedViewController")
                navigationController?.pushViewController(vcB, animated: true)
                
            } else if indexPath.item == 1 {
                // Locked Card Tapped
                let vcC = storyboard.instantiateViewController(withIdentifier: "LockedViewController")
                navigationController?.pushViewController(vcC, animated: true)
            }
        }
    }
}

extension AwardMainViewController: AwardCellDelegate {
    
    // Handle tapping the IMAGE specifically
    func didTapAwardImage(with award: AwardModel?) {
        guard let selectedAward = award else { return }
        
        let storyboard = UIStoryboard(name: "Awards", bundle: nil) // Ensure this matches your Storyboard name
        guard let detailVC = storyboard.instantiateViewController(withIdentifier: "AwardDetailViewController") as? AwardDetailViewController else {
            return
        }
        
        // Pass the correct data model
        detailVC.award = selectedAward
        
        // Push the Detail View Controller
        navigationController?.pushViewController(detailVC, animated: true)
    }
}
