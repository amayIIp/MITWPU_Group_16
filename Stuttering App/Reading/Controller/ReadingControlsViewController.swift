import UIKit


protocol WorkoutSheetDelegate: AnyObject {
    func didTapPlayPause()
    func didTapDecreaseSpeed()
    func didTapIncreaseSpeed()
    func didTapReset()
    func didTapShowResult()
    func didUpdateDAFDelay(_ delay: Double)
}

class ReadingControlsViewController: UIViewController {
    
    weak var delegate: WorkoutSheetDelegate?
    
    
    @IBOutlet weak var playPauseButton: UIButton!
    @IBOutlet weak var speedUpButton: UIButton!
    @IBOutlet weak var speedDownButton: UIButton!
    @IBOutlet weak var resetButton: UIButton!
    @IBOutlet weak var endButton: UIButton!
    @IBOutlet weak var dafButton: UIButton!
    
    var currentPlaybackSpeed: Double = 1.0
    var currentDAFDelay: Double = 0.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupButtons()
        configureMenu()
    }
    
    private func setupButtons() {
        let config = UIImage.SymbolConfiguration(pointSize: 36, weight: .regular, scale: .default)
        let playSymbol = UIImage(systemName: "microphone.slash", withConfiguration: config)
        playPauseButton.setImage(playSymbol, for: .normal)
        playPauseButton.configuration = .glass()
        speedUpButton.configuration = .glass()
        speedUpButton.setImage(UIImage(systemName: "hare"), for: .normal)
        speedDownButton.configuration = .glass()
        speedDownButton.setImage(UIImage(systemName: "tortoise"), for: .normal)
        resetButton.configuration = .glass()
        resetButton.setImage(UIImage(systemName: "arrow.trianglehead.clockwise"), for: .normal)
        dafButton.configuration = .glass()
        dafButton.setImage(UIImage(systemName: "ear.badge.checkmark"), for: .normal)
        
    }
    
    @IBAction func playPauseTapped(_ sender: UIButton) {
        delegate?.didTapPlayPause()
    }
    
    @IBAction func decreaseSpeedTapped(_ sender: UIButton) {
        delegate?.didTapDecreaseSpeed()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    @IBAction func increaseSpeedTapped(_ sender: UIButton) {
        delegate?.didTapIncreaseSpeed()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    @IBAction func resetTapped(_ sender: UIButton) {
        delegate?.didTapReset()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    @IBAction func showResultTapped(_ sender: UIButton) {
        delegate?.didTapShowResult()
    }
    
    
    func updatePlaybackState(isPlaying: Bool, hasFinished: Bool) {
        let config = UIImage.SymbolConfiguration(pointSize: 42, weight: .regular, scale: .default)
        let symbolName = isPlaying ? "microphone" : "microphone.slash"
        let symbol = UIImage(systemName: symbolName, withConfiguration: config)
        playPauseButton.setImage(symbol, for: .normal)
        
        playPauseButton.tintColor = isPlaying ? .systemRed : .systemBlue
    }
    
    func toggleDoneButtonVisibility(isHidden: Bool) {
        // Wrap in an animation block for a smooth iOS-native fade effect
        UIView.animate(withDuration: 0.25) {
            self.endButton.alpha = isHidden ? 0.0 : 1.0
            self.endButton.isHidden = isHidden
        }
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
            title: "Choose Delay for DAF",
            image: UIImage(systemName: "speedometer"),
            children: [offAction, delaysMenu]
        )
        
        dafButton.menu = menu
        dafButton.showsMenuAsPrimaryAction = true
    }
}
