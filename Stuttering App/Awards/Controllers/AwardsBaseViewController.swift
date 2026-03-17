//
//  AwardsBaseViewController.swift
//  Stuttering App 1
//
//  Created by Prathamesh Patil on 15/12/25.
//

import UIKit

class AwardsBaseViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    @IBOutlet weak var collectionView: UICollectionView!
    
    var awards: [AwardModel] = []
    
    let cellWidth: CGFloat = 115
    let cellHeight: CGFloat = 190

    override func viewDidLoad() {
        super.viewDidLoad()
        configureCollectionView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadData()
    }
    
    func loadData() { }

    private func configureCollectionView() {
        collectionView.dataSource = self
        collectionView.delegate = self
        
        let nib = UINib(nibName: "AwardCollectionViewCell", bundle: nil)
        collectionView.register(nib, forCellWithReuseIdentifier: "AwardCell")
        
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        collectionView.collectionViewLayout = layout
        collectionView.contentInset = UIEdgeInsets(top: 20, left: 0, bottom: 20, right: 0)
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return awards.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AwardCell", for: indexPath) as? AwardCollectionViewCell else {
            return UICollectionViewCell()
        }
        cell.configure(with: awards[indexPath.row])
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        let selectedAward = awards[indexPath.row]
    
        let storyboard = UIStoryboard(name: "Awards", bundle: nil)
        guard let detailVC = storyboard.instantiateViewController(withIdentifier: "AwardDetailViewController") as? AwardDetailViewController else {
            return
        }
        
        detailVC.award = selectedAward
        self.navigationController?.pushViewController(detailVC, animated: true)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: cellWidth, height: cellHeight)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        let totalCellWidth = cellWidth * 3
        let totalSpacingWidth = collectionView.frame.width - totalCellWidth
        let spacing = max(0, totalSpacingWidth / 4)
        
        return UIEdgeInsets(top: 10, left: spacing, bottom: 10, right: spacing)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        let totalCellWidth = cellWidth * 3
        let totalSpacingWidth = collectionView.frame.width - totalCellWidth
        return max(0, totalSpacingWidth / 4)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 20
    }
}
