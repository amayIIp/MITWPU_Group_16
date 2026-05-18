import UIKit

// MARK: - LastOnboardingViewController
class LastOnboardingViewController: UIViewController {
    
    // MARK: - IBOutlets
    @IBOutlet weak var blocks: UILabel!
    @IBOutlet weak var repitition: UILabel!
    @IBOutlet weak var prolongation: UILabel!
    @IBOutlet weak var troubledWords: UIStackView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var getStartedButton: UIButton!

    // MARK: - UI Components
    private let splashContainer = UIView()
    private let waveView = WaveBackgroundView() // This will now use the existing definition from your project
    private let titleLabel = UILabel()
    private let completedLabel = UILabel()
    
    // MARK: - Properties
    var report: StutterJSONReport?
    private var hasSavedData = false
    let customBrandBlue = UIColor(named: "ButtonTheme") ?? UIColor(red: 0.21, green: 0.32, blue: 0.63, alpha: 1.0)
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.navigationBar.prefersLargeTitles = true
        self.navigationItem.largeTitleDisplayMode = .always
        
        setupCustomBackButton()
        setupInitialState()
        
        if let report = report {
            setupResults(report: report)
        } else {
            blocks.text = "0%"
            repitition.text = "0%"
            prolongation.text = "0%"
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        performEntryAnimation()
    }

    private func setupInitialState() {
        scrollView.alpha = 0.0
        getStartedButton.alpha = 0.0
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    // MARK: - UI Setup
    private func setupWaveUI() {
        splashContainer.frame = view.bounds
        splashContainer.backgroundColor = UIColor(named: "bg") ?? .systemBackground
        view.addSubview(splashContainer)

        // 1. Setup Waves
        waveView.frame = splashContainer.bounds
        waveView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        waveView.themeColor = customBrandBlue
        splashContainer.addSubview(waveView)
        waveView.start()

        // 2. Setup Typography
        titleLabel.text = "Analysis Complete"
        titleLabel.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.alpha = 0
        
        completedLabel.text = "Your personalized report is ready"
        completedLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        completedLabel.textColor = .secondaryLabel
        completedLabel.textAlignment = .center
        completedLabel.alpha = 0

        let stack = UIStackView(arrangedSubviews: [titleLabel, completedLabel])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        splashContainer.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: splashContainer.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: splashContainer.centerYAnchor, constant: -60)
        ])
    }
    
    private func performEntryAnimation() {
        setupWaveUI()
        
        titleLabel.transform = CGAffineTransform(translationX: 0, y: 20)
        completedLabel.transform = CGAffineTransform(translationX: 0, y: 20)
        
        waveView.targetFillLevel = 0.40
        
        UIView.animate(withDuration: 0.8, delay: 0.3, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseOut) {
            self.titleLabel.alpha = 1.0
            self.titleLabel.transform = .identity
            self.completedLabel.alpha = 1.0
            self.completedLabel.transform = .identity
        } completion: { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                self.dissolveSplash()
            }
        }
    }
    
    private func dissolveSplash() {
        waveView.targetFillLevel = 0.0
        
        UIView.animate(withDuration: 0.7, delay: 0, options: .curveEaseInOut, animations: {
            self.splashContainer.alpha = 0.0
            self.titleLabel.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            self.waveView.stop()
            self.splashContainer.removeFromSuperview()
            
            self.navigationController?.setNavigationBarHidden(false, animated: true)
            
            UIView.animate(withDuration: 0.6) {
                self.scrollView.alpha = 1.0
                self.getStartedButton.alpha = 1.0
            }
        }
    }
    
    // MARK: - Logic & Actions
    func setupResults(report: StutterJSONReport) {
        blocks.text = "\(Int(report.percentages.blocks))%"
        repitition.text = "\(Int(report.percentages.repetition))%"
        prolongation.text = "\(Int(report.percentages.prolongation))%"
        loadTroubledWords(words: report.stutteredWords)
        
        if !hasSavedData {
            LogManager.shared.saveReadingSession(report: report)
            analyzeAndSaveProblemPhonemes(from: report.stutteredWords)
            hasSavedData = true
        }
    }
    
    private func analyzeAndSaveProblemPhonemes(from words: [String]) {
        let cleanWords = words.filter { !$0.isEmpty }.map { $0.lowercased() }
        if cleanWords.isEmpty { return }

        var plosiveCount = 0
        var fricativeCount = 0
        var vowelVoicedCount = 0

        let plosives: Set<Character> = ["p", "b", "t", "d", "k", "g"]
        let fricatives: Set<Character> = ["s", "f"]
        let vowelsVoiced: Set<Character> = ["a", "e", "i", "o", "u", "m", "n", "l"]

        for word in cleanWords {
            if word.hasPrefix("sh") || word.hasPrefix("th") {
                fricativeCount += 1
                continue
            }
            if let firstChar = word.first {
                if plosives.contains(firstChar) {
                    plosiveCount += 1
                } else if fricatives.contains(firstChar) {
                    fricativeCount += 1
                } else if vowelsVoiced.contains(firstChar) {
                    vowelVoicedCount += 1
                }
            }
        }

        var problemPhonemes: [String] = []
        if plosiveCount > 0 { problemPhonemes.append("Plosives (P, B, T, D, K, G)") }
        if fricativeCount > 0 { problemPhonemes.append("Fricatives (S, F, SH, TH)") }
        if vowelVoicedCount > 0 { problemPhonemes.append("Vowels (A,E,I,O,U) & Voiced (M,N,L)") }

        if !problemPhonemes.isEmpty {
            DatabaseManager.shared.saveUserProblemPhonemes(phonemes: problemPhonemes)
        }
    }
    
    func loadTroubledWords(words: [String]) {
        // Clear existing
        troubledWords.arrangedSubviews.forEach {
            troubledWords.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        let clean = words.filter { !$0.isEmpty }

        if clean.isEmpty {
            let label = UILabel()
            label.text = "None detected"
            label.textColor = .secondaryLabel
            label.font = UIFont.systemFont(ofSize: 15)
            label.textAlignment = .center
            troubledWords.addArrangedSubview(label)
            return
        }

        // Text-width-based wrapping flow (same as ReadingResultViewController2)
        let chipFont    = UIFont.systemFont(ofSize: 13, weight: .semibold)
        let chipHPad: CGFloat   = 24   // 12 left + 12 right
        let chipSpacing: CGFloat = 8
        let maxRowWidth = view.bounds.width - 48  // 24pt margin each side

        var currentRow = makeChipRowStack()
        troubledWords.addArrangedSubview(currentRow)
        var rowWidth: CGFloat = 0

        for word in Array(clean.prefix(14)) {
            let textW = (word as NSString).size(withAttributes: [.font: chipFont]).width.rounded(.up)
            let chipW = textW + chipHPad

            if rowWidth > 0 && rowWidth + chipSpacing + chipW > maxRowWidth {
                // Fill trailing space so chips stay left-aligned
                let spacer = UIView()
                spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
                currentRow.addArrangedSubview(spacer)

                currentRow = makeChipRowStack()
                troubledWords.addArrangedSubview(currentRow)
                rowWidth = 0
            }

            currentRow.addArrangedSubview(makeChip(text: word))
            rowWidth += (rowWidth == 0 ? 0 : chipSpacing) + chipW
        }

        // Trailing spacer on last row
        let trailing = UIView()
        trailing.setContentHuggingPriority(.defaultLow, for: .horizontal)
        currentRow.addArrangedSubview(trailing)
    }

    private func makeChipRowStack() -> UIStackView {
        let s = UIStackView()
        s.axis = .horizontal
        s.spacing = 8
        s.alignment = .center
        s.distribution = .fill
        return s
    }

    private func makeChip(text: String) -> UIView {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        label.textColor = customBrandBlue
        label.translatesAutoresizingMaskIntoConstraints = false

        let pill = UIView()
        pill.backgroundColor = customBrandBlue.withAlphaComponent(0.12)
        pill.layer.cornerRadius = 12
        pill.clipsToBounds = true
        pill.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: pill.topAnchor, constant: 6),
            label.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -6),
            label.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -12)
        ])
        return pill
    }

    private func setupCustomBackButton() {
        self.navigationItem.hidesBackButton = true
        var config = UIButton.Configuration.plain()
        let imageConfig = UIImage.SymbolConfiguration(weight: .semibold)
        config.image = UIImage(systemName: "chevron.backward", withConfiguration: imageConfig)
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        
        let backButton = UIButton(configuration: config)
        backButton.addTarget(self, action: #selector(didTapResetButton), for: .touchUpInside)
        let customBarButtonItem = UIBarButtonItem(customView: backButton)
        self.navigationItem.leftBarButtonItem = customBarButtonItem
    }

    @IBAction func getStartedButtonTapped(_ sender: UIButton) {
        if !SessionManager.shared.isAccountMode {
            SessionManager.shared.startGuestSession()
        }
        
        AppState.isOnboardingCompleted = true
        AppState.isLoginCompleted = true
        AwardsManager.shared.updateAwardProgress(id: "nm_001", progress: 1.0, newStatus: "1 of 1 completed")
        
        guard let currentUserId = LogManager.shared.getCurrentUserId() else { return }
        var profile = LogManager.shared.getProfile(userId: currentUserId) ?? UserProfile(id: currentUserId, isOnboardingCompleted: false)
        profile.isOnboardingCompleted = true
        LogManager.shared.saveProfile(profile)
        
        if SessionManager.shared.isAccountMode {
            SupabaseSyncManager.shared.pushProfile(profile)
        }
        
        LogicMaker().checkForNewDay(isFromLogin: true)
            
        let storyboard = UIStoryboard(name: "Home", bundle: nil)
        let homeVC = storyboard.instantiateViewController(withIdentifier: "HomeVC")

        guard let window = view.window else { return }
        window.backgroundColor = .systemBackground

        UIView.animate(withDuration: 0.3, animations: {
            window.rootViewController?.view.alpha = 0
        }) { _ in
            homeVC.view.alpha = 0
            window.rootViewController = homeVC
            UIView.animate(withDuration: 0.3) { homeVC.view.alpha = 1 }
        }
    }
    
    @objc func didTapResetButton() {
        let alert = UIAlertController(title: "Retake Test", message: "This will reset your current progress. Continue?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Retake", style: .destructive) { [weak self] _ in
            self?.navigateHere()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    func navigateHere() {
        guard let nav = navigationController else { return }
        let stack = nav.viewControllers
        if stack.count >= 3 {
            nav.popToViewController(stack[stack.count - 3], animated: true)
        } else {
            nav.popToRootViewController(animated: true)
        }
    }
}
