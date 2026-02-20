import UIKit

class OnboardingInstructionsViewController: UIViewController {
    
    // MARK: - Outlets
    @IBOutlet weak var instructionLabel: UILabel!
    @IBOutlet weak var pagecontrol: UIPageControl!
    @IBOutlet weak var continueButton: UIButton!
    
    // MARK: - Properties
    private let instructions = [
        "Let's take a quick\nspeech test",
        "Please ensure you are in a quiet space and your voice can be heard clearly.",
        "A passage will appear next.\nRead it out loud naturally."
    ]
    
    private var currentPage = 0 {
        didSet {
            animateInstructionChange()
        }
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        resetUI()
    }

    private func resetUI() {
        // 1. Restore visibility
        self.pagecontrol.alpha = 1
        self.continueButton.alpha = 1
        self.instructionLabel.alpha = 1
        
        // 2. Reset transforms and font
        self.instructionLabel.transform = .identity
        self.continueButton.transform = .identity
        self.instructionLabel.font = UIFont.preferredFont(forTextStyle: .largeTitle)
        
        // 3. Reset the text to the current instruction
        self.instructionLabel.text = instructions[currentPage]
        
        // 4. Show the back button again if needed
        self.navigationItem.setHidesBackButton(false, animated: false)
    }
    
    // MARK: - Setup
    func setupUI() {
        pagecontrol.numberOfPages = instructions.count
        pagecontrol.currentPage = 0
        pagecontrol.isUserInteractionEnabled = true
        
        instructionLabel.text = instructions[0]
        instructionLabel.numberOfLines = 0
        instructionLabel.textAlignment = .center
        
        continueButton.layer.cornerRadius = 25
        // Add a soft shadow to the button for depth
        continueButton.layer.shadowColor = UIColor.black.cgColor
        continueButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        continueButton.layer.shadowOpacity = 0.1
        continueButton.layer.shadowRadius = 8
    }
    
    // MARK: - Instruction Animation (Slide & Fade)
    private func animateInstructionChange() {
        // 1. Determine direction (Forward or Backward)
        let isForward = pagecontrol.currentPage < currentPage || currentPage == 0
        let transitionOffset: CGFloat = isForward ? 40 : -40
        
        // 2. Animate out the old text
        UIView.animate(withDuration: 0.2, animations: {
            self.instructionLabel.alpha = 0
            self.instructionLabel.transform = CGAffineTransform(translationX: -transitionOffset, y: 0)
        }) { _ in
            // 3. Update the text and move it to the starting position for the "In" animation
            self.instructionLabel.text = self.instructions[self.currentPage]
            self.instructionLabel.transform = CGAffineTransform(translationX: transitionOffset, y: 0)
            
            // 4. Animate in the new text
            UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: {
                self.instructionLabel.alpha = 1
                self.instructionLabel.transform = .identity
            }, completion: nil)
        }
        
        // Update UI components
        pagecontrol.currentPage = currentPage
        let isLastPage = (currentPage == instructions.count - 1)
        let buttonTitle = isLastPage ? "Start the test" : "Next"
        
        // Smoothly transition the button text
        UIView.transition(with: continueButton, duration: 0.3, options: .transitionCrossDissolve, animations: {
            self.continueButton.setTitle(buttonTitle, for: .normal)
        }, completion: nil)
    }

    // MARK: - Countdown Animation (Scale, Pulse & Haptic)
    func startCountdown() {
        self.navigationItem.setHidesBackButton(true, animated: true)
        // 1. Fade out navigation elements
        UIView.animate(withDuration: 0.3) {
            self.pagecontrol.alpha = 0
            self.continueButton.alpha = 0
            self.continueButton.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        }
        
        instructionLabel.font = UIFont.systemFont(ofSize: 110, weight: .bold)
        
        let countdownNumbers = ["3", "2", "1"]
        animateSequence(numbers: countdownNumbers, index: 0)
    }
    
    private func animateSequence(numbers: [String], index: Int) {
        guard index < numbers.count else {
            self.navigateToTestVC()
            return
        }
        
        // Trigger Haptic Feedback (Phone vibrates slightly)
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        
        self.instructionLabel.text = numbers[index]
        self.instructionLabel.alpha = 0
        self.instructionLabel.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
        
        // Pop In
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: {
            self.instructionLabel.alpha = 1
            self.instructionLabel.transform = .identity
        }) { _ in
            // Stay for a moment then Pulse Out
            UIView.animate(withDuration: 0.4, delay: 0.2, options: .curveEaseIn, animations: {
                self.instructionLabel.alpha = 0
                self.instructionLabel.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
            }) { _ in
                self.animateSequence(numbers: numbers, index: index + 1)
            }
        }
    }

    func navigateToTestVC() {
        let storyboard = UIStoryboard(name: "Onboarding", bundle: nil)
        let testVC = storyboard.instantiateViewController(withIdentifier: "TestVC")
        self.navigationController?.pushViewController(testVC, animated: true)
    }

    // MARK: - Actions
    @IBAction func continueButtonTapped(_ sender: UIButton) {
        if currentPage < instructions.count - 1 {
            currentPage += 1
        } else {
            startCountdown()
        }
    }
    
    @IBAction func pageControlValueChanged(_ sender: UIPageControl) {
        currentPage = sender.currentPage
    }
}
