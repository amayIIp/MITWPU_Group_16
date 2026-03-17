//
//  LibraryViewController.swift
//  exerciseTest
//
//  Created by Prathamesh Patil on 22/11/25.
//

import UIKit

class LibraryViewController: UIViewController {
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    var standardGroups: [ExerciseGroup] = []
    var funSection: LibrarySection?
    var headerRegistration: UICollectionView.SupplementaryRegistration<UICollectionViewListCell>!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        loadJSONData()
        view.backgroundColor = .bg
    }
    
    private func setupCollectionView() {
        let exerciseNib = UINib(nibName: ExerciseCollectionViewCell.nibName, bundle: nil)
        collectionView.register(exerciseNib, forCellWithReuseIdentifier: ExerciseCollectionViewCell.identifier)
        
        let funNib = UINib(nibName: FunExerciseCollectionViewCell.nibName, bundle: nil)
        collectionView.register(funNib, forCellWithReuseIdentifier: FunExerciseCollectionViewCell.identifier)
        
        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, layoutEnvironment in
            guard let self = self else { return nil }
            
            if sectionIndex == self.standardGroups.count {
                return self.createFunSectionLayout()
            } else {
                return self.createListSectionLayout(layoutEnvironment: layoutEnvironment)
            }
        }
        
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.collectionViewLayout = layout
        collectionView.backgroundColor = .bg
        
        setupHeaderRegistration()
    }
    
    private func createListSectionLayout(layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        config.headerMode = .supplementary
        config.backgroundColor = .bg
        
        return NSCollectionLayoutSection.list(using: config, layoutEnvironment: layoutEnvironment)
    }
    
    private func createFunSectionLayout() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .absolute(239), heightDimension: .absolute(200))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous
        section.interGroupSpacing = 16
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 24, trailing: 16)
        
        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(44))
        let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
        header.edgeSpacing = NSCollectionLayoutEdgeSpacing(leading: .fixed(16), top: .fixed(0), trailing: .fixed(16), bottom: .fixed(24))
        section.boundarySupplementaryItems = [header]
        
        return section
    }
    
    private func setupHeaderRegistration() {
        headerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(elementKind: UICollectionView.elementKindSectionHeader) { [weak self] (headerView, elementKind, indexPath) in
            guard let self = self else { return }
            
            var titleText = ""
            
            if indexPath.section < self.standardGroups.count {
                titleText = self.standardGroups[indexPath.section].name
            } else {
                titleText = self.funSection?.name ?? "Fun Exercises"
            }
            
            var content = headerView.defaultContentConfiguration()
            content.text = titleText
            content.textProperties.font = .systemFont(ofSize: 20, weight: .semibold)
            content.textProperties.color = .label
            
            headerView.contentConfiguration = content
        }
    }
    
    private func loadJSONData() {
        if let url = Bundle.main.url(forResource: "exerciselogs", withExtension: "json"),
           let data = try? Data(contentsOf: url) {
            do {
                let result = try JSONDecoder().decode(LibraryData.self, from: data)
                
                if let foundationsSection = result.sections.first(where: { $0.id == "section_speech_foundations" }) {
                    self.standardGroups = foundationsSection.groups
                } else {
                    self.standardGroups = result.sections.first?.groups ?? []
                }
                
                self.funSection = result.sections.first(where: { $0.id == "section_fun_exercises" })
                
                collectionView.reloadData()
            } catch {
                print("Parse error: \(error)")
            }
        }
    }
    
    func navigateToExercise(with exerciseName: String) {
        
        let storyboard = UIStoryboard(name: "Exercise", bundle: nil)
        guard let vc = storyboard.instantiateViewController(withIdentifier: "AirFlowInstruction") as? ExerciseInstructionViewController else { return }
        
        vc.startingSource = .exercises
        vc.exerciseName = exerciseName
        
        let ResultNav = UINavigationController(rootViewController: vc)
        ResultNav.modalPresentationStyle = .fullScreen
        self.present(ResultNav, animated: true, completion: nil)
    }
}

extension LibraryViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return standardGroups.count + (funSection != nil ? 1 : 0)
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == standardGroups.count {
            return funSection?.groups.first?.exercises.count ?? 0
        } else {
            return standardGroups[section].exercises.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        return collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        if indexPath.section == standardGroups.count {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FunExerciseCollectionViewCell.identifier, for: indexPath) as! FunExerciseCollectionViewCell
            
            if let exercise = funSection?.groups.first?.exercises[indexPath.row] {
                cell.configure(with: exercise)
            }
            return cell
        }
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ExerciseCollectionViewCell.identifier, for: indexPath) as! ExerciseCollectionViewCell
        
        let group = standardGroups[indexPath.section]
        let exercise = group.exercises[indexPath.row]
        
        cell.configure(with: exercise)
        
        cell.didTapButton = { [weak self] in
            self?.navigateToExercise(with: exercise.name)
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        
        if indexPath.section == standardGroups.count {
            guard let exercise = funSection?.groups.first?.exercises[indexPath.row] else { return }

            navigateToExercise(with: exercise.name)
            
        } else {
            let group = standardGroups[indexPath.section]
            let exercise = group.exercises[indexPath.row]
            
            navigateToExercise(with: exercise.name)
        }
    }
}
