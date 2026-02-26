//
//  LibraryViewController.swift
//  exerciseTest
//
//  Created by Prathamesh Patil on 22/11/25.
//

import UIKit

class LibraryViewController: UIViewController {
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    // MARK: - Data Source Properties
    // We isolate the groups from the first section to act as our main sections
    var standardGroups: [ExerciseGroup] = []
    
    // We keep a reference to the specific Fun section
    var funSection: LibrarySection?
    
    var headerRegistration: UICollectionView.SupplementaryRegistration<UICollectionViewListCell>!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        loadJSONData()
        view.backgroundColor = .bg
    }
    
    private func setupCollectionView() {
        // 1. Register Cells
        // Replaced GroupCollectionViewCell with ExerciseCollectionViewCell
        let exerciseNib = UINib(nibName: ExerciseCollectionViewCell.nibName, bundle: nil)
        collectionView.register(exerciseNib, forCellWithReuseIdentifier: ExerciseCollectionViewCell.identifier)
        
        // Fun Section Cells (Kept as is)
        let funNib = UINib(nibName: FunExerciseCollectionViewCell.nibName, bundle: nil)
        collectionView.register(funNib, forCellWithReuseIdentifier: FunExerciseCollectionViewCell.identifier)
        
        // 2. Create Compositional Layout
        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, layoutEnvironment in
            guard let self = self else { return nil }
            
            // Check if this is the last section (The Fun Section)
            if sectionIndex == self.standardGroups.count {
                return self.createFunSectionLayout()
            } else {
                // All other sections are Standard Lists displaying Exercises directly
                return self.createListSectionLayout(layoutEnvironment: layoutEnvironment)
            }
        }
        
        collectionView.collectionViewLayout = layout
        collectionView.backgroundColor = .bg
        
        // 3. Setup Header Logic
        setupHeaderRegistration()
        
        collectionView.dataSource = self
        collectionView.delegate = self
    }
    
    // MARK: - Layout Generators
    
    // Layout for Standard Sections (Now displaying Exercises directly)
    private func createListSectionLayout(layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        config.headerMode = .supplementary
        config.backgroundColor = .bg
        
        return NSCollectionLayoutSection.list(using: config, layoutEnvironment: layoutEnvironment)
    }
    
    // Layout for Fun Section (Horizontal Cards - Unchanged)
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
        header.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 24, trailing: 16)
        section.boundarySupplementaryItems = [header]
        
        return section
    }
    
    private func setupHeaderRegistration() {
        headerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(elementKind: UICollectionView.elementKindSectionHeader) { [weak self] (headerView, elementKind, indexPath) in
            guard let self = self else { return }
            
            var titleText = ""
            
            // Logic: Is this a Standard Group or the Fun Section?
            if indexPath.section < self.standardGroups.count {
                // It is a Standard Group (e.g., "Breathing And Relaxation")
                titleText = self.standardGroups[indexPath.section].name
            } else {
                // It is the Fun Section
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
                
                // 1. Get the First Section (Speech Foundations) and extract its Groups
                if let foundationsSection = result.sections.first(where: { $0.id == "section_speech_foundations" }) {
                    self.standardGroups = foundationsSection.groups
                } else {
                    // Fallback if specific ID not found, just take the first one
                    self.standardGroups = result.sections.first?.groups ?? []
                }
                
                // 2. Get the Fun Section specifically
                self.funSection = result.sections.first(where: { $0.id == "section_fun_exercises" })
                
                collectionView.reloadData()
            } catch {
                print("Parse error: \(error)")
            }
        }
    }
    
    // MARK: - Navigation Logic
    // Moved directly here since we no longer use ExerciseListViewController
    func navigateToExercise(with exerciseName: String) {
        
        let storyboard = UIStoryboard(name: "Exercise", bundle: nil)
        // 1. Try to find a VC in the Storyboard with ID == Exercise Name
        // We cast to 'ExerciseStarting' to pass data (if your protocol exists)
        // If your Fun VCs don't use the protocol, you can remove the cast or use a base class
        guard let vc = storyboard.instantiateViewController(withIdentifier: "AirFlowInstruction") as? ExerciseInstructionViewController else { return }
        
        // 2. Pass Data if the VC conforms to the protocol
        if let exerciseVC = vc as? ExerciseStarting {
            exerciseVC.startingSource = .exercises
            exerciseVC.exerciseName = exerciseName
        }
        
        let ResultNav = UINavigationController(rootViewController: vc)
        ResultNav.modalPresentationStyle = .fullScreen
        self.present(ResultNav, animated: true, completion: nil)
    }
}

// MARK: - DataSource & Delegate
extension LibraryViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        // Count of Standard Groups + 1 for the Fun Section (if it exists)
        return standardGroups.count + (funSection != nil ? 1 : 0)
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // Check if this is the Fun Section (last section)
        if section == standardGroups.count {
            return funSection?.groups.first?.exercises.count ?? 0
        } else {
            // It's a standard group, return number of exercises in this group
            return standardGroups[section].exercises.count
        }
    }
    
    // Header View
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        return collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        // MARK: Fun Section
        if indexPath.section == standardGroups.count {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FunExerciseCollectionViewCell.identifier, for: indexPath) as! FunExerciseCollectionViewCell
            
            if let exercise = funSection?.groups.first?.exercises[indexPath.row] {
                cell.configure(with: exercise)
            }
            return cell
        }
        
        // MARK: Standard Section (Now Exercises)
        // We now display the ExerciseCollectionViewCell directly here
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ExerciseCollectionViewCell.identifier, for: indexPath) as! ExerciseCollectionViewCell
        
        // Get the specific exercise from the specific group
        let group = standardGroups[indexPath.section]
        let exercise = group.exercises[indexPath.row]
        
        cell.configure(with: exercise)
        
        // Handle the button tap inside the cell
        cell.didTapButton = { [weak self] in
            self?.navigateToExercise(with: exercise.name)
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        
        if indexPath.section == standardGroups.count {
            // MARK: Fun Section Tapped
            // 1. Get the Fun Exercise Data
            guard let exercise = funSection?.groups.first?.exercises[indexPath.row] else { return }
            
            print("Tapped Fun Exercise: \(exercise.name)")
            
            // 2. Navigate using the same logic as the list
            navigateToExercise(with: exercise.name)
            
        } else {
            // MARK: Standard Section Tapped
            // (Optional: You can keep this if you want row taps to also open the exercise,
            // separate from the 'Play' button inside the cell)
            let group = standardGroups[indexPath.section]
            let exercise = group.exercises[indexPath.row]
            
            navigateToExercise(with: exercise.name)
        }
    }
}
