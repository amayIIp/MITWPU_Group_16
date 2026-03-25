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

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        resetUI()
    }

    private func resetUI() {
        //self.pagecontrol.alpha = 1
        self.continueButton.alpha = 1
        self.instructionLabel.alpha = 1
        
        self.instructionLabel.transform = .identity
        self.continueButton.transform = .identity
        self.instructionLabel.font = UIFont.preferredFont(forTextStyle: .largeTitle)
        
        self.instructionLabel.text = instructions[currentPage]
        
        self.navigationItem.setHidesBackButton(false, animated: false)
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
        
        UIView.animate(withDuration: 0.2, animations: {
            self.instructionLabel.alpha = 0
            self.instructionLabel.transform = CGAffineTransform(translationX: -transitionOffset, y: 0)
        }) { _ in
            self.instructionLabel.text = self.instructions[self.currentPage]
            self.instructionLabel.transform = CGAffineTransform(translationX: transitionOffset, y: 0)
            
            UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: {
                self.instructionLabel.alpha = 1
                self.instructionLabel.transform = .identity
            }, completion: nil)
        }
        
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
        
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: {
            self.instructionLabel.alpha = 1
            self.instructionLabel.transform = .identity
        }) { _ in
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

    @IBAction func continueButtonTapped(_ sender: UIButton) {
        if currentPage < instructions.count - 1 {
            currentPage += 1
        } else {
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
                    break
                }
            }
        }
    }

    private func requestMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
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
