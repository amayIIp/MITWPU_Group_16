import UIKit


protocol WorkoutSheetDelegate: AnyObject {
    func didTapPlayPause()
    func didChangeSpeed(_ speed: Double)
    func didTapReset()
    func didTapShowResult()
    func didUpdateDAFDelay(_ delay: Double)
}

class ReadingControlsViewController: UIViewController {
    
    weak var delegate: WorkoutSheetDelegate?
    
    @IBOutlet weak var playPauseButton: UIButton!
    @IBOutlet weak var resetButton: UIButton!
    @IBOutlet weak var endButton: UIButton!
    @IBOutlet weak var dafButton: UIButton!
    @IBOutlet weak var speedSlider: UISlider!
    
    @IBOutlet weak var sliderStack: UIStackView!
    @IBOutlet weak var timer: UILabel!
    
    @IBOutlet weak var playPauseWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var dafWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var resetHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var endHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var stackTopConstraint: NSLayoutConstraint!
    
    var currentPlaybackSpeed: Double = 1.0
    var currentDAFDelay: Double = 0.0
    
    var screenHeight : CGFloat = 850
    
    private var timerObject: Timer?
    private var startTime: Date?
    private var elapsedTime: TimeInterval = 0
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupButtons()
        configureMenu()
        setupSlider()
        timer.text = "00:00"
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        adjustButtonSizes()
    }
    
    func startTimer() {
        startTime = Date()
        timerObject = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimer()
        }
    }
    
    func pauseTimer() {
        timerObject?.invalidate()
        timerObject = nil
        startTime = nil
    }
    
    func resetTimer() {
        timerObject?.invalidate()
        timerObject = nil
        
        elapsedTime = 0
        startTime = nil
        
        timer.text = "00:00"
    }
    
    private func updateTimer() {
        guard let start = startTime else { return }

        let totalTime = elapsedTime + Date().timeIntervalSince(start)

        let minutes = Int(totalTime) / 60
        let seconds = Int(totalTime) % 60

        timer.text = String(format: "%02d:%02d", minutes, seconds)
    }

    func updatePlaybackState(isPlaying: Bool, hasFinished: Bool, currentTime: TimeInterval) {

        let symbolName = isPlaying ? "pause.fill" : "play.fill"
        let symbol = UIImage(systemName: symbolName)

        playPauseButton.setImage(symbol, for: .normal)
        playPauseButton.tintColor = .systemBlue
        
        self.elapsedTime = currentTime

        if isPlaying {
            if timerObject == nil { startTimer() }
        } else {
            pauseTimer()
        
            let minutes = Int(currentTime) / 60
            let seconds = Int(currentTime) % 60
            timer.text = String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private func setupButtons() {
        playPauseButton.configuration = .glass()
        playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)

        var config = UIButton.Configuration.prominentGlass()
        config.title = "Reset"

        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.preferredFont(forTextStyle: .title2)
            return outgoing
        }
        
        dafButton.configuration = .glass()
        dafButton.setImage(UIImage(systemName: "ear.badge.checkmark"), for: .normal)
        
        sliderStack.isHidden = true
    }
    
    private func setupSlider() {
        speedSlider.minimumValue = 0.5
        speedSlider.maximumValue = 2.0
        speedSlider.value = Float(currentPlaybackSpeed)
        
        speedSlider.minimumTrackTintColor = .buttonTheme
        speedSlider.maximumTrackTintColor = .white
        
    }
    
    private func adjustButtonSizes() {
        guard playPauseWidthConstraint != nil, dafWidthConstraint != nil else { return }
        
        let proportionalWidth = view.bounds.width * 0.212
        let optimalWidth = max(80.0, min(proportionalWidth, 110))
        
        playPauseWidthConstraint.constant = optimalWidth
        dafWidthConstraint.constant = optimalWidth
        endHeightConstraint.constant = optimalWidth * 0.6
        resetHeightConstraint.constant = optimalWidth * 0.6
        stackTopConstraint.constant = (screenHeight - optimalWidth)/2
        
        print("screenHeight : \(screenHeight)")
        print("stackTop : \(stackTopConstraint.constant)")
    }
    
    @IBAction func speedSliderChanged(_ sender: UISlider) {
        let speed = Double(sender.value)
        currentPlaybackSpeed = speed
        
        delegate?.didChangeSpeed(speed)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    @IBAction func playPauseTapped(_ sender: UIButton) {
        delegate?.didTapPlayPause()
    }
    
    @IBAction func resetTapped(_ sender: UIButton) {
        delegate?.didTapReset()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    @IBAction func showResultTapped(_ sender: UIButton) {
        delegate?.didTapShowResult()
    }
    
    func toggleDoneButtonVisibility(isHidden: Bool) {
        
        if !isHidden {
            self.sliderStack.isHidden = false
        }
        
        UIView.animate(
            withDuration: 0.3,
            delay: 0.0,
            options: [.curveEaseInOut, .beginFromCurrentState],
            animations: {
                self.sliderStack.alpha = isHidden ? 0.0 : 1.0
            },
            completion: { _ in
                if isHidden {
                    self.sliderStack.isHidden = true
                }
            }
        )
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
