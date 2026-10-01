import UIKit
import Speech
import AVFoundation

class OnboardingInstructionsViewController: UIViewController {

    @IBOutlet weak var instructionLabel: UILabel!
    @IBOutlet weak var continueButton: UIButton!

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

    /// Closed from the moment Continue is tapped until the screen has finished
    /// reacting to that tap.
    ///
    /// Both of the button's jobs used to be re-entrant: the page change takes
    /// 0.6s of animation before the label reads differently, and "Start the
    /// test" waits on two permission callbacks before the countdown begins. A
    /// second tap inside either window skipped a page, or pushed a second copy
    /// of the test onto the navigation stack.
    private var isAdvancing = false

    /// `isEnabled` would grey the button out for the 0.6s of the page change,
    /// which reads as a glitch, so interaction is what gets switched off.
    private func setAdvancing(_ advancing: Bool) {
        isAdvancing = advancing
        continueButton.isUserInteractionEnabled = !advancing
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        resetUI()
    }

    private func resetUI() {
        // self.pagecontrol.alpha = 1
        self.continueButton.alpha = 1
        self.instructionLabel.alpha = 1

        self.instructionLabel.transform = .identity
        self.continueButton.transform = .identity
        self.instructionLabel.font = UIFont.preferredFont(forTextStyle: .largeTitle)

        self.instructionLabel.text = instructions[currentPage]

        self.navigationItem.setHidesBackButton(false, animated: false)

        // Coming back from the test screen leaves the button locked otherwise.
        setAdvancing(false)
    }

    func setupUI() {

        instructionLabel.text = instructions[0]
        instructionLabel.numberOfLines = 0
        instructionLabel.textAlignment = .center

        continueButton.layer.cornerRadius = 25
        continueButton.layer.shadowColor = UIColor.black.cgColor
        continueButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        continueButton.layer.shadowOpacity = 0.1
        continueButton.layer.shadowRadius = 8
    }

    private func animateInstructionChange() {
        let isForward = true
        let transitionOffset: CGFloat = isForward ? 40 : -40

        UIView.animate(
            withDuration: 0.2,
            animations: {
                self.instructionLabel.alpha = 0
                self.instructionLabel.transform = CGAffineTransform(translationX: -transitionOffset, y: 0)
            },
            completion: { _ in
                self.instructionLabel.text = self.instructions[self.currentPage]
                self.instructionLabel.transform = CGAffineTransform(translationX: transitionOffset, y: 0)

                UIView.animate(
                    withDuration: 0.4,
                    delay: 0,
                    usingSpringWithDamping: 0.8,
                    initialSpringVelocity: 0.5,
                    options: .curveEaseOut,
                    animations: {
                        self.instructionLabel.alpha = 1
                        self.instructionLabel.transform = .identity
                    },
                    completion: { _ in
                        self.setAdvancing(false)
                    }
                )
            }
        )

        let isLastPage = (currentPage == instructions.count - 1)
        let buttonTitle = isLastPage ? "Start the test" : "Next"

        UIView.transition(with: continueButton, duration: 0.3, options: .transitionCrossDissolve, animations: {
            self.continueButton.setTitle(buttonTitle, for: .normal)
        }, completion: nil)
    }

    func startCountdown() {
        self.navigationItem.setHidesBackButton(true, animated: true)
        UIView.animate(withDuration: 0.3) {
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

        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()

        self.instructionLabel.text = numbers[index]
        self.instructionLabel.alpha = 0
        self.instructionLabel.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)

        UIView.animate(
            withDuration: 0.4,
            delay: 0,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 0.5,
            options: .curveEaseOut,
            animations: {
                self.instructionLabel.alpha = 1
                self.instructionLabel.transform = .identity
            },
            completion: { _ in
                UIView.animate(
                    withDuration: 0.4,
                    delay: 0.2,
                    options: .curveEaseIn,
                    animations: {
                        self.instructionLabel.alpha = 0
                        self.instructionLabel.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
                    },
                    completion: { _ in
                        self.animateSequence(numbers: numbers, index: index + 1)
                    }
                )
            }
        )
    }

    func navigateToTestVC() {
        // Last line of defence: if anything has already pushed, don't push again.
        guard navigationController?.topViewController === self else { return }

        let storyboard = UIStoryboard(name: "Onboarding", bundle: nil)
        let testVC = storyboard.instantiateViewController(withIdentifier: "TestVC")
        self.navigationController?.pushViewController(testVC, animated: true)
    }

    @IBAction func continueButtonTapped(_ sender: UIButton) {
        guard !isAdvancing else { return }
        setAdvancing(true)

        if currentPage < instructions.count - 1 {
            // Re-opened by animateInstructionChange's completion.
            currentPage += 1
        } else {
            // Stays closed until the permission prompts come back: either the
            // countdown takes over, or showPermissionAlert re-opens it.
            checkPermissionsAndStart()
        }
    }
    private func checkPermissionsAndStart() {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self?.requestMicrophonePermission()
                case .denied, .restricted, .notDetermined:
                    self?.showPermissionAlert(message: "Speech recognition is required for this test.")
                @unknown default:
                    self?.setAdvancing(false)
                }
            }
        }
    }

    private func requestMicrophonePermission() {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.startCountdown()
                } else {
                    self?.showPermissionAlert(message: "Microphone access is required to record your voice.")
                }
            }
        }
    }

    private func showPermissionAlert(message: String) {
        setAdvancing(false)

        let alert = UIAlertController(title: "Permissions Required", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}
