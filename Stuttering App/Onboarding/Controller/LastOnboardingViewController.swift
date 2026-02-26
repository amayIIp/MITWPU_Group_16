import UIKit

class LastOnboardingViewController: UIViewController {
    
    @IBOutlet weak var blocks: UILabel!
    @IBOutlet weak var repitition: UILabel!
    @IBOutlet weak var prolongation: UILabel!
    @IBOutlet weak var troubledWords: UIStackView! // This should be the StackView inside "Words you find hard to say"
    
    @IBOutlet weak var splashStackView: UIStackView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var getStartedButton: UIButton!
    //@IBOutlet weak var chartContainerView: UIView!

    // ✅ Variable to receive data
    var report: StutterJSONReport?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCustomBackButton()
        setupInitialState()
        
        // Populate Data if available
        if let report = report {
            setupResults(report: report)
        } else {
            // Default "Zero" state if accessed directly
            blocks.text = "0%"
            repitition.text = "0%"
            prolongation.text = "0%"
        }
    }
    
    func setupResults(report: StutterJSONReport) {
        // 1. Update Percentage Labels
        blocks.text = "\(Int(report.percentages.blocks))%"
        repitition.text = "\(Int(report.percentages.repetition))%"
        prolongation.text = "\(Int(report.percentages.prolongation))%"
        
        // 2. Update Troubled Words Chips
        loadTroubledWords(words: report.stutteredWords)
    }
    
    func loadTroubledWords(words: [String]) {
        // Clear any placeholder views in the stack
        troubledWords.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        let cleanWords = words.filter({ !$0.isEmpty })
        
        // Handle empty case
        if cleanWords.isEmpty {
            let label = UILabel()
            label.text = "None detected!"
            label.textColor = .secondaryLabel
            label.font = UIFont.systemFont(ofSize: 16)
            label.textAlignment = .center
            troubledWords.addArrangedSubview(label)
            return
        }
        
        // Create Chips (reuse logic from ResultVC)
        let maxPerRow = 3
        var currentRowStack: UIStackView?
        let displayWords = Array(cleanWords.prefix(9)) // Limit to 9
        
        for (index, word) in displayWords.enumerated() {
            if index % maxPerRow == 0 {
                currentRowStack = UIStackView()
                currentRowStack?.axis = .horizontal
                currentRowStack?.alignment = .center
                currentRowStack?.distribution = .fillProportionally
                currentRowStack?.spacing = 8
                troubledWords.addArrangedSubview(currentRowStack!)
            }
            let chip = createChipLabel(text: word)
            currentRowStack?.addArrangedSubview(chip)
        }
    }
    
    func createChipLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = "  \(text)  "
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = .systemBlue
        label.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.12)
        label.textAlignment = .center
        label.layer.cornerRadius = 14
        label.layer.masksToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        label.heightAnchor.constraint(equalToConstant: 32).isActive = true
        return label
    }
    
    // MARK: - Navigation & Animations
    
    private func setupCustomBackButton() {
        self.navigationItem.hidesBackButton = true
        let customBackButton = UIBarButtonItem(image: UIImage(systemName: "chevron.backward"), style: .plain, target: self, action: #selector(didTapResetButton))
        self.navigationItem.leftBarButtonItem = customBackButton
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Check if splash is supposed to be shown
        if !splashStackView.isHidden {
            createConfetti()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Only run the fade-out animation here
        if !splashStackView.isHidden {
            performEntryAnimation()
        }
    }

    private func performEntryAnimation() {
        // Keep splash visible for 2 seconds (as per your current delay)
//        UIView.animate(withDuration: 1.0, delay: 2.0, options: [.curveEaseInOut], animations: {
//            self.splashStackView.alpha = 0.0
//        }) { _ in
//            self.splashStackView.isHidden = true
//            self.navigationController?.setNavigationBarHidden(false, animated: true)
//            
//            // Fade in content
//            UIView.animate(withDuration: 0.5) {
//                self.scrollView.alpha = 1.0
//                self.getStartedButton.alpha = 1.0
//            }
//        }
        UIView.animate(withDuration: 1.0, delay: 2.0, options: [.curveEaseInOut], animations: {
            self.splashStackView.alpha = 0.0
            
        }) { _ in
            self.splashStackView.isHidden = true
            self.navigationController?.setNavigationBarHidden(false, animated: false)
            self.scrollView.alpha = 1.0
            self.getStartedButton.alpha = 1.0
            
        }
    }
    private func createConfetti() {
        let emitter = CAEmitterLayer()
        emitter.emitterPosition = CGPoint(x: view.frame.size.width / 2, y: -10)
        emitter.emitterShape = .line
        emitter.emitterSize = CGSize(width: view.frame.size.width, height: 2)
        
        let colors: [UIColor] = [.systemRed, .systemBlue, .systemGreen, .systemYellow, .systemPink, .systemPurple]
        
        let cells: [CAEmitterCell] = colors.map { color in
            let cell = CAEmitterCell()
            cell.birthRate = 4.0
            cell.lifetime = 10.0
            cell.velocity = CGFloat.random(in: 100...200)
            cell.velocityRange = 50
            cell.emissionLongitude = .pi
            cell.emissionRange = .pi / 4
            cell.spin = 2
            cell.spinRange = 3
            cell.scale = 0.1
            cell.scaleRange = 0.05
            cell.contents = createConfettiImage(with: color)?.cgImage
            return cell
        }
        
        emitter.emitterCells = cells
        view.layer.addSublayer(emitter)
        
        // Store reference to stop it later
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            emitter.birthRate = 0 // Stop generating new confetti
        }
    }

    private func createConfettiImage(with color: UIColor) -> UIImage? {
        let size = CGSize(width: 12, height: 12)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        let context = UIGraphicsGetCurrentContext()
        color.setFill()
        context?.fill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
    
    private func setupInitialState() {
        splashStackView.alpha = 1.0
        splashStackView.isHidden = false
        scrollView.alpha = 0.0
        getStartedButton.alpha = 0.0
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    
    

    @IBAction func getStartedButtonTapped(_ sender: UIButton) {
//        
//        AppState.isOnboardingCompleted = true
//        AwardsManager.shared.updateAwardProgress(id: "nm_001", progress: 1.0, newStatus: "1 of 1 completed")
//        // Go to Home
//        let storyboard = UIStoryboard(name: "Home", bundle: nil)
//        let homeVC = storyboard.instantiateViewController(withIdentifier: "HomeVC")
//        
//        if let sceneDelegate = view.window?.windowScene?.delegate as? SceneDelegate,
//           let window = sceneDelegate.window {
//            UIView.transition(with: window, duration: 0.3, options: .curveLinear, animations: {
//                window.rootViewController = homeVC
//            }, completion: nil)
//        }
        AppState.isOnboardingCompleted = true
            AwardsManager.shared.updateAwardProgress(id: "nm_001", progress: 1.0, newStatus: "1 of 1 completed")
            
            // 1. Setup the new View Controller
        let storyboard = UIStoryboard(name: "Home", bundle: nil)
        let homeVC = storyboard.instantiateViewController(withIdentifier: "HomeVC")

        guard let window = view.window else { return }

        // 1. Set the window's background to your target color
        // (e.g., .white or homeVC's background color)
        window.backgroundColor = .bg

        // 2. Phase 1: Fade out the current view
        UIView.animate(withDuration: 0.3, animations: {
            window.rootViewController?.view.alpha = 0
        }) { _ in
            // 3. Switch the Root View Controller
            homeVC.view.alpha = 0
            window.rootViewController = homeVC
            
            // 4. Phase 2: Fade the new view back in
            UIView.animate(withDuration: 0.3) {
                homeVC.view.alpha = 1
            }
        }
    }
    
    @objc func didTapResetButton() {
        // Reset Logic
        let alert = UIAlertController(title: "Reset Test", message: "This will reset your current progress. Continue?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Reset", style: .destructive) { [weak self] _ in
            self?.navigateHere()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    func navigateHere() {
        navigationController?.popViewController(animated: true)
    }
}
