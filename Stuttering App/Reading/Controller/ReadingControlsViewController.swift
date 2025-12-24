//
//  ReadingControlsViewController.swift
//  Spasht
//
//

import UIKit

protocol WorkoutSheetDelegate: AnyObject {
    func didTapPlayPause()
    func didTapDecreaseSpeed()
    func didTapIncreaseSpeed()
    func didTapReset()
    func didTapShowResult()
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
        
        
        endButton.configuration = .prominentGlass()
        endButton.configuration?.baseBackgroundColor = .systemRed
        endButton.configuration?.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 24, weight: .semibold)
            return outgoing
        }
        endButton.setTitle("End", for: .normal)
        
    }
    
    @IBAction func playPauseTapped(_ sender: UIButton) {
        delegate?.didTapPlayPause()
    }
    
    @IBAction func decreaseSpeedTapped(_ sender: UIButton) {
        delegate?.didTapDecreaseSpeed()
        // Optional: add haptic feedback
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.impactOccurred()
    }
    
    @IBAction func increaseSpeedTapped(_ sender: UIButton) {
        delegate?.didTapIncreaseSpeed()
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.impactOccurred()
    }
    
    @IBAction func resetTapped(_ sender: UIButton) {
        delegate?.didTapReset()
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
    }
    
    @IBAction func showResultTapped(_ sender: UIButton) {
        delegate?.didTapShowResult()
    }
    
    func updatePlaybackState(isPlaying: Bool, hasFinished: Bool) {
        let config = UIImage.SymbolConfiguration(pointSize: 42, weight: .regular, scale: .default)
        let symbolName = isPlaying ? "microphone" : "microphone.slash"
        let symbol = UIImage(systemName: symbolName, withConfiguration: config)
        playPauseButton.setImage(symbol, for: .normal)
        
    }
    
    func configureMenu() {
        
        let offAction = UIAction(
            title: "Off",
             
            state: currentPlaybackSpeed == 0 ? .on : .off
        ) { [weak self] _ in
            self?.currentPlaybackSpeed = 0
            print("Playback stopped (0x)")
            self?.configureMenu()
        }
        
        let speedOptions = [0.05, 0.1, 0.15, 0.25, 0.5, 0.75, 1.0, 1.5]
        
        let menuActions = speedOptions.map { speed in
            UIAction(title: "\(speed)s", state: speed == currentPlaybackSpeed ? .on : .off) { [weak self] action in
                self?.currentPlaybackSpeed = speed
                print("Speed updated to: \(speed)")
                self?.configureMenu()
            }
        }
        
        let speedsMenu = UIMenu(options: .displayInline, children: menuActions)
        
        let menu = UIMenu(
            title: "Choose Delay for DAF",
            image: UIImage(systemName: "speedometer"),
            children: [offAction, speedsMenu]
        )
        
        dafButton.menu = menu
        dafButton.showsMenuAsPrimaryAction = true
    }

}
