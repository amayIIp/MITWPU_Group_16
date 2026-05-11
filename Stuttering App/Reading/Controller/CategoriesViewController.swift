import UIKit

class CategoriesViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    @IBOutlet weak var collectionView: UICollectionView!
    
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var DafButton: UIButton!
    
    weak var delegate: WorkoutSheetDelegate?
    var currentDAFDelay: Double = 0.0
    
    let categories = ["Science", "Space", "Astronomy", "Mindset", "Sports"]
    
    // MARK: - State Variables
    // Rule 2: Strict Accordion. We only need ONE variable to track expansion now.
    // If Random is expanded, Custom is closed. If Random is closed, Custom is expanded.
    var isRandomExpanded = true
    
    // Selection Tracking
    var selectedSubcategoryIndex: Int? = nil
    var isCustomSelected = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        setupButtons()
    }
    
    private func setupButtons() {
        DafButton?.configuration = .glass()
        DafButton?.setImage(UIImage(systemName: "ear.badge.checkmark"), for: .normal)
        configureMenu()
    }
    
    func configureMenu() {
        let offAction = UIAction(title: "Off", state: currentDAFDelay == 0 ? .on : .off) { [weak self] _ in
            self?.currentDAFDelay = 0
            self?.delegate?.didUpdateDAFDelay(0)
            self?.configureMenu()
        }
        
        let delayOptions = [0.05, 0.1, 0.25, 0.5, 0.75, 1.0, 1.5]
        
        let menuActions = delayOptions.map { delay in
            UIAction(title: "\(delay)s", state: delay == currentDAFDelay ? .on : .off) { [weak self] action in
                self?.currentDAFDelay = delay
                self?.delegate?.didUpdateDAFDelay(delay)
                self?.configureMenu()
            }
        }
        
        let delaysMenu = UIMenu(options: .displayInline, children: menuActions)
        
        let menu = UIMenu(
            title: "DAF plays your voice back to you with a slight delay to help improve speech fluency.",
            image: UIImage(systemName: "speedometer"),
            children: [offAction, delaysMenu]
        )
        
        DafButton?.menu = menu
        DafButton?.showsMenuAsPrimaryAction = true
    }
    
    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        layout.minimumLineSpacing = 9
        layout.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 20, right: 16)
        
        layout.headerReferenceSize = CGSize(width: view.bounds.width, height: 50)
        layout.footerReferenceSize = CGSize(width: view.bounds.width, height: 60)
        
        collectionView.collectionViewLayout = layout
        collectionView.backgroundColor = .bg
        
        // MARK: - Enable Scrolling & Bounce Behavior
        collectionView.isScrollEnabled = true
        collectionView.alwaysBounceVertical = true
        collectionView.showsVerticalScrollIndicator = true
        
        collectionView.delegate = self
        collectionView.dataSource = self
        
        // Register standard cells
        collectionView.register(RandomCardCell.self, forCellWithReuseIdentifier: "RandomCardCell")
        collectionView.register(CustomCardCell.self, forCellWithReuseIdentifier: "CustomCardCell")
        
        // Register Supplementary Views (Header and Footer)
        collectionView.register(TitleHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: TitleHeaderView.identifier)
        collectionView.register(CaptionFooterView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: CaptionFooterView.identifier)
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 2
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        if indexPath.item == 0 {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "RandomCardCell", for: indexPath) as! RandomCardCell
            
            cell.setExpanded(isRandomExpanded, animated: false)
            
            // Rule 1: The "Random" header is ONLY selected if no subcategory is chosen AND Custom isn't selected
            let isRandomHeaderSelected = !isCustomSelected && (selectedSubcategoryIndex == nil)
            cell.updateHeaderSelection(isSelected: isRandomHeaderSelected)
            cell.updateSubcategorySelection(selectedIndex: isCustomSelected ? nil : selectedSubcategoryIndex)
            
            // Handle Header Tap
            cell.onHeaderTapped = { [weak self] in
                guard let self = self else { return }
                self.handleHeaderTap() // Triggers the accordion
            }
            
            // Handle Subcategory Tap
            cell.onSubcategoryTapped = { [weak self] index in
                guard let self = self else { return }
                let feedback = UIImpactFeedbackGenerator(style: .light)
                feedback.impactOccurred()
                
                self.selectedSubcategoryIndex = index
                self.isCustomSelected = false
                
                // Rule 1: Deselect the Random header visually in-place
                cell.updateSubcategorySelection(selectedIndex: index)
                cell.updateHeaderSelection(isSelected: false)
                
                // Ensure Custom is deselected
                if let customCell = self.collectionView.cellForItem(at: IndexPath(item: 1, section: 0)) as? CustomCardCell {
                    customCell.updateSelectionState(isSelected: false)
                }
            }
            
            return cell
            
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CustomCardCell", for: indexPath) as! CustomCardCell
            
            // Custom is always the exact opposite of Random
            cell.setExpanded(!isRandomExpanded, animated: false)
            cell.updateSelectionState(isSelected: isCustomSelected)
            
            cell.onHeaderTapped = { [weak self] in
                guard let self = self else { return }
                self.handleHeaderTap() // Triggers the accordion
            }
            
            return cell
        }
    }

    // MARK: - Animation & Logic Control
    
    // Rule 2 Logic: Tapping ANY header flips the seesaw.
    private func handleHeaderTap() {
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.impactOccurred()
        
        // Flip the accordion state
        isRandomExpanded.toggle()
        
        // Force the selection to match the newly expanded card
        if isRandomExpanded {
            isCustomSelected = false
            selectedSubcategoryIndex = nil // Reset so the "Random" header gets the blue dot
        } else {
            isCustomSelected = true
            selectedSubcategoryIndex = nil
        }
        
        triggerAnimation()
    }

    private func triggerAnimation() {
        let randomCell = collectionView.cellForItem(at: IndexPath(item: 0, section: 0)) as? RandomCardCell
        let customCell = collectionView.cellForItem(at: IndexPath(item: 1, section: 0)) as? CustomCardCell
        
        // Update Random Cell
        randomCell?.setExpanded(isRandomExpanded, animated: true)
        let isRandomHeaderSelected = !isCustomSelected && (selectedSubcategoryIndex == nil)
        randomCell?.updateHeaderSelection(isSelected: isRandomHeaderSelected)
        randomCell?.updateSubcategorySelection(selectedIndex: isCustomSelected ? nil : selectedSubcategoryIndex)
        
        // Update Custom Cell
        customCell?.setExpanded(!isRandomExpanded, animated: true)
        customCell?.updateSelectionState(isSelected: isCustomSelected)
        
        // Animate the Collection View Heights
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.1, options: .curveEaseInOut, animations: {
            self.collectionView.performBatchUpdates(nil, completion: nil)
        }, completion: nil)
    }
    
    @IBAction func didTapContinueButton(_ sender: UIButton) {
        view.endEditing(true)
        
        var topicToGenerate = ""
        
        if isCustomSelected {
            let customIndexPath = IndexPath(item: 1, section: 0)
            if let cell = collectionView.cellForItem(at: customIndexPath) as? CustomCardCell,
               let text = cell.customTextView.text {
                
                let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if trimmedText.isEmpty || trimmedText.count < 50 {
                    showEmptyInputAlert()
                    return
                }
                
                showDetailScreen(title: "Custom Story", text: trimmedText)
                return
            } else {
                showEmptyInputAlert()
                return
            }
        } else if let index = selectedSubcategoryIndex {
            if index < categories.count {
                topicToGenerate = categories[index]
            } else {
                topicToGenerate = "General"
            }
        } else {
            // Random Header Selected
            let validPresets = presetTitles.filter { $0 != "Custom" }
            topicToGenerate = validPresets.randomElement() ?? "General"
        }
        
        generateAIStory(topic: topicToGenerate)
    }
    
    func generateAIStory(topic: String) {
        print("DEBUG: Generating AI Story for topic: \(topic)")
        let troubledLetters = LogManager.shared.getTopStruggledLetters(limit: 5)
        
        // Show spinner — awaitParagraph handles cache, in-flight, and on-demand generation
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.center = self.view.center
        activityIndicator.color = .gray
        activityIndicator.hidesWhenStopped = true
        self.view.addSubview(activityIndicator)
        activityIndicator.startAnimating()
        self.view.isUserInteractionEnabled = false
        
        Task {
            let paragraph = await BackgroundParagraphManager.shared.awaitParagraph(
                for: topic, troubledLetters: troubledLetters
            )
            
            await MainActor.run {
                activityIndicator.stopAnimating()
                activityIndicator.removeFromSuperview()
                self.view.isUserInteractionEnabled = true
                
                if let paragraph = paragraph {
                    print("DEBUG: AI Generation Success. Length: \(paragraph.count)")
                    self.showDetailScreen(title: topic, text: paragraph)
                } else {
                    // All AI tiers failed — use phoneme-based fallback
                    print("DEBUG: All AI tiers failed. Using phoneme fallback.")
                    let phonemeFallback = PhonemeContent.generateLongFormContent(for: troubledLetters)
                    self.showDetailScreen(title: topic, text: phonemeFallback)
                }
            }
        }
    }
    
    func getFallbackContent(for topic: String) -> String {
        let normalized = topic.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        if let index = presetTitles.firstIndex(where: { $0.lowercased() == normalized }) {
            if index < presetContent.count { return presetContent[index] }
        }
        
        if normalized.contains("space") || normalized.contains("moon") || normalized.contains("star") || normalized.contains("planet") {
             if let index = presetTitles.firstIndex(of: "Science"), index < presetContent.count { return presetContent[index] }
        }
        
        if normalized.contains("fest") || normalized.contains("party") || normalized.contains("celebrat") {
             if let index = presetTitles.firstIndex(of: "Festival"), index < presetContent.count { return presetContent[index] }
        }
        
        if normalized.contains("happy") || normalized.contains("sad") || normalized.contains("mind") || normalized.contains("think") {
             if let index = presetTitles.firstIndex(of: "Mindset"), index < presetContent.count { return presetContent[index] }
        }

        if let randomContent = presetContent.filter({ !$0.isEmpty }).randomElement() {
            return randomContent
        }
        
        return "Science is a systematic enterprise that builds and organizes knowledge in the form of testable explanations and predictions about the universe."
    }

    func showDetailScreen(title: String, text: String) {
        guard let detailVC = storyboard?.instantiateViewController(withIdentifier: "DetailVC") as? DetailViewController else { return }
        
        detailVC.textToDisplay = text
        detailVC.titleToDisplay = title
        detailVC.initialDAFDelay = currentDAFDelay

        let detailNav = UINavigationController(rootViewController: detailVC)
        detailNav.modalPresentationStyle = .fullScreen
        self.present(detailNav, animated: true, completion: nil)
    }
    
    func showEmptyInputAlert() {
        let alert = UIAlertController(title: "Invalid Input", message: "Please enter at least 50 characters.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
            
        if kind == UICollectionView.elementKindSectionHeader {
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: TitleHeaderView.identifier, for: indexPath) as! TitleHeaderView
            return header
            
        } else if kind == UICollectionView.elementKindSectionFooter {
            let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: CaptionFooterView.identifier, for: indexPath) as! CaptionFooterView
            return footer
        }
        
        return UICollectionReusableView()
    }
}

// MARK: - Supplementary Views

class TitleHeaderView: UICollectionReusableView {
    static let identifier = "TitleHeaderView"
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "What would you like to read?"
        // Matches standard iOS large title aesthetic
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 0),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 36),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 16)
        ])
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

class CaptionFooterView: UICollectionReusableView {
    static let identifier = "CaptionFooterView"
    
    private let captionLabel: UILabel = {
        let label = UILabel()
        label.text = "Topics are just for reference. We generate texts based on your specific speech triggers."
        // Uses dynamic type for accessibility and system gray for secondary text
        label.font = UIFont.preferredFont(forTextStyle: .footnote)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(captionLabel)
        
        NSLayoutConstraint.activate([
            captionLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            captionLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32),
            captionLabel.topAnchor.constraint(equalTo: topAnchor, constant: -8)
        ])
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
