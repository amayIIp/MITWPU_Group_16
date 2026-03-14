//
//  AirFlowControlsViewController.swift
//  Stuttering App 1
//
//  Updated for Dynamic Sheet State & Adaptive Layout
//

import UIKit

protocol AirFlowControlsDelegate: AnyObject {
    func didTapPlayPause()
    func didTapNextWord()
    func didTapStop()
    func didTapRepeat()
}

class ControlsTemplateViewController: UIViewController {

    @IBOutlet weak var timerLabel: UILabel!
    @IBOutlet weak var playPauseButton: UIButton!
    @IBOutlet weak var stopButton: UIButton!
    @IBOutlet weak var resetButton: UIButton!
    @IBOutlet weak var playPauseWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var resetWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var stopHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var stackTopConstraint: NSLayoutConstraint!

    weak var delegate: AirFlowControlsDelegate?
    private var isPlaying: Bool = true
    var screenHeight : CGFloat = 850

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        // Initial state: Collapsed, secondary buttons hidden
        setExpandedState(isExpanded: false, animated: false)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        adjustButtonSizes()
    }
    
    private func setupUI() {
        let buttonConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        
        playPauseButton.configuration = .glass()
        playPauseButton.setImage(UIImage(systemName: "pause", withConfiguration: buttonConfig), for: .normal)
        
        stopButton.configuration = .prominentGlass()
        stopButton.configuration?.baseBackgroundColor = .systemRed
        stopButton.configuration?.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 22, weight: .semibold)
            return outgoing
        }
        stopButton.setTitle("End", for: .normal)
        
        resetButton.configuration = .glass()
        resetButton.setImage(UIImage(systemName: "repeat", withConfiguration: buttonConfig), for: .normal)
    }

    private func adjustButtonSizes() {
        guard playPauseWidthConstraint != nil, resetWidthConstraint != nil else { return }
        
        // Calculate a proportional width (e.g., 18% of the total screen/sheet width)
        let proportionalWidth = view.bounds.width * 0.22
        
        // Clamp the values to maintain HIG minimum touch targets (44pt) and prevent oversized buttons
        let optimalWidth = max(80.0, min(proportionalWidth, 110))
        
        playPauseWidthConstraint.constant = optimalWidth
        resetWidthConstraint.constant = optimalWidth
        stopHeightConstraint.constant = optimalWidth * 0.6
        stackTopConstraint.constant = (screenHeight - optimalWidth)/2
        
    }
    
    // Controls the visibility of secondary buttons based on sheet expansion
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
    
    func setPlayPauseState(isPlaying: Bool) {
        self.isPlaying = isPlaying
        let iconName = isPlaying ? "pause" : "play"
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        
        DispatchQueue.main.async {
            UIView.transition(with: self.playPauseButton, duration: 0.2, options: .transitionCrossDissolve) {
                self.playPauseButton.setImage(UIImage(systemName: iconName, withConfiguration: config), for: .normal)
            }
        }
    }
    
    func setPlayPauseEnabled(_ isEnabled: Bool) {
        DispatchQueue.main.async {
            self.playPauseButton.isEnabled = isEnabled
            self.playPauseButton.alpha = isEnabled ? 1.0 : 0.5
        }
    }

    @IBAction func playPauseTapped(_ sender: UIButton) {
        delegate?.didTapPlayPause()
    }
    
    @IBAction func stopTapped(_ sender: UIButton) {
        delegate?.didTapStop()
    }
    
    @IBAction func repeatTapped(_ sender: UIButton) {
        delegate?.didTapRepeat()
    }
}
