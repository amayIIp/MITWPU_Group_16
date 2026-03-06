import UIKit


protocol WorkoutSheetDelegate: AnyObject {
    func didTapPlayPause()
    //func didTapDecreaseSpeed()
    //func didTapIncreaseSpeed()
    func didChangeSpeed(_ speed: Double)
    func didTapReset()
    func didTapShowResult()
    func didUpdateDAFDelay(_ delay: Double)
}

class ReadingControlsViewController: UIViewController {
    
    weak var delegate: WorkoutSheetDelegate?
    
    
    @IBOutlet weak var playPauseButton: UIButton!
    //@IBOutlet weak var speedUpButton: UIButton!
    //@IBOutlet weak var speedDownButton: UIButton!
    @IBOutlet weak var resetButton: UIButton!
    @IBOutlet weak var endButton: UIButton!
    @IBOutlet weak var dafButton: UIButton!
    @IBOutlet weak var speedSlider: UISlider!
    
    @IBOutlet weak var sliderStack: UIStackView!
    @IBOutlet weak var timer: UILabel!
    var currentPlaybackSpeed: Double = 1.0
    var currentDAFDelay: Double = 0.0
    
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
    func startTimer() {
        startTime = Date()

        timerObject = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimer()
        }
    }
    func pauseTimer() {
        timerObject?.invalidate()
        timerObject = nil
        
        if let start = startTime {
            elapsedTime += Date().timeIntervalSince(start)
        }
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
    func updatePlaybackState(isPlaying: Bool, hasFinished: Bool) {

        let symbolName = isPlaying ? "pause.fill" : "play.fill"
        let symbol = UIImage(systemName: symbolName)

        playPauseButton.setImage(symbol, for: .normal)
        playPauseButton.tintColor = .systemBlue

        if isPlaying {
            startTimer()
        } else {
            pauseTimer()
        }
    }
    
    private func setupButtons() {
//        let config = UIImage.SymbolConfiguration(pointSize: 36, weight: .regular, scale: .default)
//        let playSymbol = UIImage(systemName: "microphone.slash", withConfiguration: config)
//        playPauseButton.setImage(playSymbol, for: .normal)
//        playPauseButton.configuration = .glass()
////        speedUpButton.configuration = .glass()
////        speedUpButton.setImage(UIImage(systemName: "hare"), for: .normal)
////        speedDownButton.configuration = .glass()
////        speedDownButton.setImage(UIImage(systemName: "tortoise"), for: .normal)
//        resetButton.configuration = .glass()
//        resetButton.setImage(UIImage(systemName: "arrow.trianglehead.clockwise"), for: .normal)
//        dafButton.configuration = .glass()
//        dafButton.setImage(UIImage(systemName: "ear.badge.checkmark"), for: .normal)
        playPauseButton.configuration = .glass()
            playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)

        var config = UIButton.Configuration.prominentGlass()
        config.title = "Reset"

        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.preferredFont(forTextStyle: .title2)
            return outgoing
        }

        //resetButton.configuration = config

            dafButton.configuration = .glass()
            dafButton.setImage(UIImage(systemName: "ear.badge.checkmark"), for: .normal)
        
    }
    
    private func setupSlider() {
        speedSlider.minimumValue = 0.5
        speedSlider.maximumValue = 2.0
        speedSlider.value = Float(currentPlaybackSpeed)
        
        speedSlider.minimumTrackTintColor = .buttonTheme
        speedSlider.maximumTrackTintColor = .white
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
    
//    @IBAction func decreaseSpeedTapped(_ sender: UIButton) {
//        delegate?.didTapDecreaseSpeed()
//        UIImpactFeedbackGenerator(style: .light).impactOccurred()
//    }
//    
//    @IBAction func increaseSpeedTapped(_ sender: UIButton) {
//        delegate?.didTapIncreaseSpeed()
//        UIImpactFeedbackGenerator(style: .light).impactOccurred()
//    }
//    
    @IBAction func resetTapped(_ sender: UIButton) {
        delegate?.didTapReset()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    @IBAction func showResultTapped(_ sender: UIButton) {
        delegate?.didTapShowResult()
    }
    
    
//    func updatePlaybackState(isPlaying: Bool, hasFinished: Bool) {
//        let config = UIImage.SymbolConfiguration(pointSize: 42, weight: .regular, scale: .default)
//        let symbolName = isPlaying ? "microphone" : "microphone.slash"
//        let symbol = UIImage(systemName: symbolName, withConfiguration: config)
//        playPauseButton.setImage(symbol, for: .normal)
//        
//        playPauseButton.tintColor = isPlaying ? .systemRed : .systemBlue
//    }
//
    
//    func updatePlaybackState(isPlaying: Bool, hasFinished: Bool) {
//        
//        let symbolName = isPlaying ? "pause.fill" : "play.fill"
//        let symbol = UIImage(systemName: symbolName)
//        
//        playPauseButton.setImage(symbol, for: .normal)
//        playPauseButton.tintColor = .systemBlue
//    }
    
//    func toggleDoneButtonVisibility(isHidden: Bool) {
//        // Wrap in an animation block for a smooth iOS-native fade effect
//        UIView.animate(withDuration: 0.25) {
//            self.endButton.alpha = isHidden ? 0.0 : 1.0
//            self.endButton.isHidden = isHidden
//        }
//    }
    func toggleDoneButtonVisibility(isHidden: Bool) {
        UIView.animate(withDuration: 0.25) {
            self.sliderStack.alpha = isHidden ? 0.0 : 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            self.sliderStack.isHidden = isHidden
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
