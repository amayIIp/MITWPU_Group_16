//
//  AirFlowControlsViewController.swift
//  Stuttering App 1
//
//  Updated for Dynamic Sheet State
//

import UIKit

protocol AirFlowControlsDelegate: AnyObject {
    func didTapPlayPause()
    func didTapNextWord()
    func didTapStop()
}

class ControlsTemplateViewController: UIViewController {

    @IBOutlet weak var timerLabel: UILabel!
    @IBOutlet weak var playPauseButton: UIButton!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var stopButton: UIButton!
    @IBOutlet weak var resetButton: UIButton!
//    @IBOutlet weak var stepProgressView: RadialProgressView!

    weak var delegate: AirFlowControlsDelegate?
    private var isPlaying: Bool = true

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        // Initial state: Collapsed, buttons hidden
        setExpandedState(isExpanded: false, animated: false)
    }
    
    private func setupUI() {
        let largeConfig = UIImage.SymbolConfiguration(pointSize: 26, weight: .semibold)
        let resetConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        
        playPauseButton.configuration = .glass()
        playPauseButton.setImage(UIImage(systemName: "pause", withConfiguration: largeConfig), for: .normal)
        
//        nextButton.configuration = .prominentGlass()
//        nextButton.configuration?.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
//            var outgoing = incoming
//            outgoing.font = UIFont.systemFont(ofSize: 24, weight: .semibold)
//            return outgoing
//        }
//        nextButton.setTitle("Next word", for: .normal)
        
        stopButton.configuration = .prominentGlass()
        stopButton.configuration?.baseBackgroundColor = .systemRed
        stopButton.configuration?.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 22, weight: .semibold)
            return outgoing
        }
        stopButton.setTitle("End", for: .normal)
        
        resetButton.configuration = .glass()
        resetButton.setImage(UIImage(systemName: "repeat", withConfiguration: resetConfig), for: .normal)
        
        nextButton.configuration = .glass()
        nextButton.setImage(UIImage(systemName: "forward.frame", withConfiguration: resetConfig), for: .normal)
        
//        setupRadialView()
    }
    
//    private func setupRadialView() {
//        let radialConfig = RadialData(
//            title: "Step Timer",
//            color: .systemIndigo,
//            progress: 1.0,
//            radius: 26,
//            lineWidth: 14,
//            order: 0
//        )
//        stepProgressView.chartData = [radialConfig]
//        stepProgressView.backgroundColor = .clear
//    }

    // MARK: - State Management
    
    /// Controls the visibility of secondary buttons based on sheet expansion
    func setExpandedState(isExpanded: Bool, animated: Bool = true) {
        let targetAlpha: CGFloat = isExpanded ? 1.0 : 0.0
        
        // Ensure buttons are interactive only when visible
        self.stopButton.isUserInteractionEnabled = isExpanded
        
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
                self.stopButton.alpha = targetAlpha
                self.view.layoutIfNeeded()
            }
        } else {
            self.stopButton.alpha = targetAlpha
        }
    }

    func updateTimerLabel(text: String) {
        DispatchQueue.main.async {
            self.timerLabel.text = text
        }
    }
    
//    func updateProgress(value: CGFloat) {
//        DispatchQueue.main.async {
//            self.stepProgressView.updateProgress(for: "Step Timer", to: value)
//        }
//    }
    
    func setPlayPauseState(isPlaying: Bool) {
        self.isPlaying = isPlaying
        let iconName = isPlaying ? "pause" : "play"
        let config = UIImage.SymbolConfiguration(pointSize: 26, weight: .semibold)
        
        DispatchQueue.main.async {
            // Add a small bounce animation for feedback
            UIView.transition(with: self.playPauseButton, duration: 0.2, options: .transitionCrossDissolve) {
                self.playPauseButton.setImage(UIImage(systemName: iconName, withConfiguration: config), for: .normal)
            }
        }
    }

    // MARK: - Actions
    
    @IBAction func playPauseTapped(_ sender: UIButton) {
        delegate?.didTapPlayPause()
    }
    
    @IBAction func nextTapped(_ sender: UIButton) {
        delegate?.didTapNextWord()
    }
    
    @IBAction func stopTapped(_ sender: UIButton) {
        delegate?.didTapStop()
    }
}
