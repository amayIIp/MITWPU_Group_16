//
//  ExerciseTabViewController.swift
//  Stuttering App
//
//  Created by sdc - user on 30/03/26.
//

import UIKit

class ExerciseTabViewController: UIViewController {

    @IBOutlet weak var exerciseCollectionView: UICollectionView!

    @IBOutlet weak var libraryButton: UIBarButtonItem!

    // MARK: - Section Management
    enum SectionType {
        case phonemes
        case discovery
        case goTo
        case fun
    }

    var activeSections: [SectionType] = []

    var phonemeExercises: [Exercise] = []
    var discoveryExercise: [Exercise] = []
    var goToExercises: [Exercise] = []
    var funExercises: [Exercise] = []

    var discoverySectionTitle: String = "Try New !!"
    var headerRegistration: UICollectionView.SupplementaryRegistration<UICollectionViewListCell>!

    // Quick lookup dictionary: [Exercise Name : Exercise Model]
    private var allExercisesDict: [String: Exercise] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .bg
        setupCollectionView()
        loadJSONDataAndSync()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(forceRefreshUI),
            name: NSNotification.Name("dailyTasksUpdated"),
            object: nil
        )

        setupOnboardingOverlayIfNeeded()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        forceRefreshUI()
    }

    // MARK: - Onboarding Gate
    private func setupOnboardingOverlayIfNeeded() {
        guard !AppState.isExercisesCompleted else { return }

        // Hide the library button while onboarding is active
        navigationItem.rightBarButtonItem?.isHidden = true

        let features = [
            OnboardingFeature(iconName: "bolt.heart.fill", title: "Personalized Practice", description: "Exercises generated automatically based on words you struggled with previously."),
            OnboardingFeature(iconName: "list.bullet.clipboard", title: "Guided Exercises", description: "Follow along with curated lessons to master different speaking techniques."),
            OnboardingFeature(iconName: "chart.line.uptrend.xyaxis", title: "Progress Tracking", description: "Monitor your improvement as you complete daily exercises.")
        ]

        let overlay = ModuleOnboardingOverlayView(
            subtitle: "Targeted exercises to improve your speech fluency and confidence.",
            features: features,
            footerText: "Progress is synced with your profile. Manage goals in Settings."
        )
        overlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlay)

        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        overlay.onContinue = { [weak self] in
            AppState.isExercisesCompleted = true

            // Restore the library button
            self?.navigationItem.rightBarButtonItem?.isHidden = false

            UIView.animate(withDuration: 0.3, animations: {
                overlay.alpha = 0
            }) { _ in
                overlay.removeFromSuperview()
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup UI
    private func setupCollectionView() {
        let exerciseNib = UINib(nibName: ExerciseCollectionViewCell.nibName, bundle: nil)
        exerciseCollectionView.register(exerciseNib, forCellWithReuseIdentifier: ExerciseCollectionViewCell.identifier)

        let funNib = UINib(nibName: FunExerciseCollectionViewCell.nibName, bundle: nil)
        exerciseCollectionView.register(funNib, forCellWithReuseIdentifier: FunExerciseCollectionViewCell.identifier)

        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, layoutEnvironment in
            guard let self = self else { return nil }

            let sectionType = self.activeSections[sectionIndex]

            if sectionType == .fun {
                return self.createFunSectionLayout()
            } else {
                return self.createListSectionLayout(layoutEnvironment: layoutEnvironment)
            }
        }

        exerciseCollectionView.dataSource = self
        exerciseCollectionView.delegate = self
        exerciseCollectionView.collectionViewLayout = layout
        exerciseCollectionView.backgroundColor = .bg

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
        headerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(elementKind: UICollectionView.elementKindSectionHeader) { [weak self] (headerView, _, indexPath) in
            guard let self = self else { return }

            let sectionType = self.activeSections[indexPath.section]
            var titleText = ""

            switch sectionType {
            case .phonemes: titleText = "Based off your troubled words"
            case .discovery: titleText = self.discoverySectionTitle
            case .goTo: titleText = "Go-To Exercises"
            case .fun: titleText = "Let's do something fun"
            }

            var content = headerView.defaultContentConfiguration()
            content.text = titleText
            content.textProperties.font = .systemFont(ofSize: 20, weight: .semibold)
            content.textProperties.color = .label
            headerView.contentConfiguration = content
        }
    }

    // MARK: - Data Loading
    private func loadJSONDataAndSync() {
        guard let url = Bundle.main.url(forResource: "exerciselogs", withExtension: "json") else {
            print("🛑 DEBUG ERROR: Could not find 'exerciselogs.json' in the app bundle.")
            return
        }

        guard let data = try? Data(contentsOf: url) else {
            print("🛑 DEBUG ERROR: Could read data from 'exerciselogs.json'.")
            return
        }

        do {
            let result = try JSONDecoder().decode(LibraryData.self, from: data)
            var allNamesToSeed: [String] = []

            for section in result.sections {
                for group in section.groups {
                    for exercise in group.exercises {
                        // Crucial: Trim strings when loading the dictionary so exact matches work
                        let cleanName = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        self.allExercisesDict[cleanName] = exercise
                        allNamesToSeed.append(cleanName)
                    }
                }
            }

            print("\n📦 Loaded \(allNamesToSeed.count) exercises from JSON")

            if let funSection = result.sections.first(where: { $0.id == "section_fun_exercises" }) {
                self.funExercises = funSection.groups.first?.exercises ?? []
            }

            DatabaseManager.shared.seedExercisesDatabase(with: allNamesToSeed)
            DatabaseManager.shared.syncLegacyJourneyCompletions()

            forceRefreshUI()

        } catch {
            print("🛑 JSON PARSE ERROR: \(error)")
        }
    }

    // MARK: - UI Refresh Logic
    @objc private func forceRefreshUI() {
        // Enforce main thread to prevent UI lockups and background crashes
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            DatabaseManager.shared.syncLegacyJourneyCompletions()

            if !self.allExercisesDict.isEmpty {
                self.buildSectionsFromDatabase()
            }
        }
    }

    private func buildSectionsFromDatabase() {
        let db = DatabaseManager.shared

        self.activeSections.removeAll()
        self.phonemeExercises.removeAll()
        self.discoveryExercise.removeAll()
        self.goToExercises.removeAll()

        // 1. Phonemes
        let phonemeNames = db.fetchPhonemeBasedExercises()
        self.phonemeExercises = phonemeNames.compactMap { self.allExercisesDict[$0] }
        if !self.phonemeExercises.isEmpty { self.activeSections.append(.phonemes) }

        // 2. Discovery (Try New / Explore Again)
        let discoveryResult = db.fetchDiscoveryExercise()
        self.discoverySectionTitle = discoveryResult.sectionTitle
        if let discName = discoveryResult.exerciseName, let discEx = self.allExercisesDict[discName] {
            self.discoveryExercise = [discEx]
            self.activeSections.append(.discovery)
        }

        // 3. Go-To Exercises
        let goToNames = db.fetchGoToExercises()
        self.goToExercises = goToNames.compactMap { self.allExercisesDict[$0] }
        if !self.goToExercises.isEmpty { self.activeSections.append(.goTo) }

        // 4. Fun Section
        if !self.funExercises.isEmpty { self.activeSections.append(.fun) }

        UIView.transition(with: self.exerciseCollectionView,
                          duration: 0.25,
                          options: [.transitionCrossDissolve, .allowUserInteraction],
                          animations: { self.exerciseCollectionView.reloadData() })
    }

    // MARK: - Navigation
    func navigateToExercise(with exerciseName: String) {
        let storyboard = UIStoryboard(name: "Exercise", bundle: nil)
        guard let vc = storyboard.instantiateViewController(withIdentifier: "AirFlowInstruction") as? ExerciseInstructionViewController else { return }

        vc.startingSource = .exercises
        vc.exerciseName = exerciseName

        let resultNav = UINavigationController(rootViewController: vc)
        resultNav.modalPresentationStyle = .fullScreen
        self.present(resultNav, animated: true, completion: nil)
    }
}

// MARK: - Collection View Delegate & DataSource
extension ExerciseTabViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return activeSections.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch activeSections[section] {
        case .phonemes: return phonemeExercises.count
        case .discovery: return discoveryExercise.count
        case .goTo: return goToExercises.count
        case .fun: return funExercises.count
        }
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        return collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        let sectionType = activeSections[indexPath.section]
        var currentExercise: Exercise!

        switch sectionType {
        case .phonemes: currentExercise = phonemeExercises[indexPath.row]
        case .discovery: currentExercise = discoveryExercise[indexPath.row]
        case .goTo: currentExercise = goToExercises[indexPath.row]
        case .fun: currentExercise = funExercises[indexPath.row]
        }

        if sectionType == .fun {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FunExerciseCollectionViewCell.identifier, for: indexPath) as! FunExerciseCollectionViewCell
            cell.configure(with: currentExercise)
            return cell
        }

        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ExerciseCollectionViewCell.identifier, for: indexPath) as! ExerciseCollectionViewCell
        cell.configure(with: currentExercise)

        cell.didTapButton = { [weak self] in
            self?.navigateToExercise(with: currentExercise.name)
        }

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        let sectionType = activeSections[indexPath.section]
        var currentExercise: Exercise!

        switch sectionType {
        case .phonemes: currentExercise = phonemeExercises[indexPath.row]
        case .discovery: currentExercise = discoveryExercise[indexPath.row]
        case .goTo: currentExercise = goToExercises[indexPath.row]
        case .fun: currentExercise = funExercises[indexPath.row]
        }

        navigateToExercise(with: currentExercise.name)
    }
}
