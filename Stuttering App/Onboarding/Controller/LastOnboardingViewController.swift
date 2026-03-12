import UIKit

class LastOnboardingViewController: UIViewController {
    
    @IBOutlet weak var blocks: UILabel!
    @IBOutlet weak var repitition: UILabel!
    @IBOutlet weak var prolongation: UILabel!
    @IBOutlet weak var troubledWords: UIStackView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var getStartedButton: UIButton!

    private let titleLabel = UILabel()
    private let circleLayer = CAShapeLayer()
    private let checkmarkImageView = UIImageView()
    private let completedLabel = UILabel()
    private let timeLabel = UILabel()
    private let splashContainer = UIView()
    var report: StutterJSONReport?

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.navigationBar.prefersLargeTitles = true
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
    
    private func setupCustomBackButton() {
        self.navigationItem.hidesBackButton = true
        let customBackButton = UIBarButtonItem(image: UIImage(systemName: "chevron.backward"), style: .plain, target: self, action: #selector(didTapResetButton))
        self.navigationItem.leftBarButtonItem = customBackButton
    }

    func setupResults(report: StutterJSONReport) {
        blocks.text = "\(Int(report.percentages.blocks))%"
        repitition.text = "\(Int(report.percentages.repetition))%"
        prolongation.text = "\(Int(report.percentages.prolongation))%"
        loadTroubledWords(words: report.stutteredWords)
    }
    
    func loadTroubledWords(words: [String]) {
        troubledWords.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let cleanWords = words.filter({ !$0.isEmpty })
        
        if cleanWords.isEmpty {
            let label = UILabel()
            label.text = "None detected!"
            label.textColor = .secondaryLabel
            label.font = UIFont.systemFont(ofSize: 16)
            label.textAlignment = .center
            troubledWords.addArrangedSubview(label)
            return
        }
        
        let maxPerRow = 3
        var currentRowStack: UIStackView?
        let displayWords = Array(cleanWords.prefix(9))
        
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

    private func setupRingUI() {
        splashContainer.frame = view.bounds
        splashContainer.backgroundColor = .bg
        view.addSubview(splashContainer)

        let centerPoint = view.center
        let brandColour = UIColor(resource: .buttonTheme).cgColor
        let radius: CGFloat = 80
        
        titleLabel.text = "Stutter Test"
        titleLabel.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        titleLabel.textColor = .black
        titleLabel.sizeToFit()
        titleLabel.center = CGPoint(x: centerPoint.x, y: centerPoint.y - radius - 80)
        titleLabel.alpha = 1.0
        splashContainer.addSubview(titleLabel)
        
        let circularPath = UIBezierPath(arcCenter: centerPoint, radius: radius, startAngle: -CGFloat.pi / 2, endAngle: 3 * CGFloat.pi / 2, clockwise: true)
        circleLayer.path = circularPath.cgPath
        circleLayer.strokeColor = brandColour
        circleLayer.lineWidth = 20
        circleLayer.fillColor = UIColor.clear.cgColor
        circleLayer.lineCap = .round
        circleLayer.strokeEnd = 0
        splashContainer.layer.addSublayer(circleLayer)
        
        let config = UIImage.SymbolConfiguration(pointSize: 60, weight: .bold)
        checkmarkImageView.image = UIImage(systemName: "checkmark", withConfiguration: config)
        checkmarkImageView.tintColor = UIColor(cgColor: brandColour)
        checkmarkImageView.frame = CGRect(x: 0, y: 0, width: 60, height: 60)
        checkmarkImageView.center = centerPoint
        checkmarkImageView.alpha = 0
        splashContainer.addSubview(checkmarkImageView)
        
        completedLabel.text = "Completed !!"
        completedLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        completedLabel.textColor = .black
        completedLabel.sizeToFit()
        completedLabel.center = CGPoint(x: centerPoint.x, y: centerPoint.y - radius - 40)
        completedLabel.alpha = 0
        splashContainer.addSubview(completedLabel)
        
        timeLabel.text = ""
        timeLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        timeLabel.textColor = .black
        timeLabel.sizeToFit()
        timeLabel.center = CGPoint(x: centerPoint.x, y: centerPoint.y + radius + 40)
        timeLabel.alpha = 0
        splashContainer.addSubview(timeLabel)
    }
    
    private func performEntryAnimation() {
        setupRingUI()
        
        let circularProgressAnimation = CABasicAnimation(keyPath: "strokeEnd")
        circularProgressAnimation.duration = 1.0
        circularProgressAnimation.toValue = 1.0
        circularProgressAnimation.fillMode = .forwards
        circularProgressAnimation.isRemovedOnCompletion = false
        circularProgressAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        
        CATransaction.begin()
        CATransaction.setCompletionBlock {
            // Fade in checkmark and text after ring finishes
            UIView.animate(withDuration: 0.3, animations: {
                self.checkmarkImageView.alpha = 1.0
                self.completedLabel.alpha = 1.0
                self.timeLabel.alpha = 1.0
            }) { _ in
                // Wait 1 second, then dissolve everything
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.dissolveSplash()
                }
            }
        }
        circleLayer.add(circularProgressAnimation, forKey: "progressAnim")
        CATransaction.commit()
    }
    
    private func dissolveSplash() {
        UIView.animate(withDuration: 1.0, delay: 0.0, options: [.curveEaseInOut], animations: {
            self.splashContainer.alpha = 0.0
        }) { _ in
            self.splashContainer.removeFromSuperview()
            
            self.navigationController?.setNavigationBarHidden(false, animated: false)
            
            UIView.animate(withDuration: 0.5) {
                self.scrollView.alpha = 1.0
                self.getStartedButton.alpha = 1.0
            }
        }
    }
    
    @IBAction func getStartedButtonTapped(_ sender: UIButton) {
        AppState.isOnboardingCompleted = true
        SupabaseSyncManager.shared.pushOnboardingStatus(isCompleted: true)
        AwardsManager.shared.updateAwardProgress(id: "nm_001", progress: 1.0, newStatus: "1 of 1 completed")
        
        // Generate daily tasks before going to Home so the task cards aren't empty
        let logic = LogicMaker()
        logic.checkForNewDay()
            
        let storyboard = UIStoryboard(name: "Home", bundle: nil)
        let homeVC = storyboard.instantiateViewController(withIdentifier: "HomeVC")

        guard let window = view.window else { return }

        window.backgroundColor = .systemBackground 

        UIView.animate(withDuration: 0.3, animations: {
            window.rootViewController?.view.alpha = 0
        }) { _ in
            homeVC.view.alpha = 0
            window.rootViewController = homeVC
            
            UIView.animate(withDuration: 0.3) {
                homeVC.view.alpha = 1
            }
        }
    }
    
    @objc func didTapResetButton() {
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
