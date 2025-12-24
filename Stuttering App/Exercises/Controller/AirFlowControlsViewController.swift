//
//  AirFlowControlsViewController.swift
//  Stuttering App 1
//
//  Created by SDC-USER on 16/12/25.
//

import UIKit

protocol AirFlowControlsDelegate: AnyObject {
    func didTapPlayPause()
    func didTapNextWord()
    func didTapStop()
}

class AirFlowControlsViewController: UIViewController {

    @IBOutlet weak var timerLabel: UILabel!
    @IBOutlet weak var playPauseButton: UIButton!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var stopButton: UIButton!
    @IBOutlet weak var resetButton: UIButton!
    @IBOutlet weak var stepProgressView: RadialProgressView!

    weak var delegate: AirFlowControlsDelegate?
    private var isPlaying: Bool = true

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        let largeConfig = UIImage.SymbolConfiguration(pointSize: 26, weight: .semibold)
        let resetConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        
        
        playPauseButton.configuration = .glass()
        playPauseButton.setImage(UIImage(systemName: "pause", withConfiguration: largeConfig), for: .normal)
        
        nextButton.configuration = .prominentGlass()
        nextButton.configuration?.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 24, weight: .semibold)
            return outgoing
        }
        nextButton.setTitle("Next word", for: .normal)
        
        stopButton.configuration = .prominentGlass()
        stopButton.configuration?.baseBackgroundColor = .systemRed
        stopButton.configuration?.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 24, weight: .semibold)
            return outgoing
        }
        stopButton.setTitle("End", for: .normal)
        
        
        resetButton.configuration = .glass()
        resetButton.setImage(UIImage(systemName: "repeat", withConfiguration: resetConfig), for: .normal)
        
        setupRadialView()
    }
    
    private func setupRadialView() {
        let radialConfig = RadialData(
            title: "Step Timer",
            color: .systemIndigo,
            progress: 1.0,
            radius: 26,
            lineWidth: 14,
            order: 0
        )
        stepProgressView.chartData = [radialConfig]
        stepProgressView.backgroundColor = .clear
    }

    func updateTimerLabel(text: String) {
        DispatchQueue.main.async {
            self.timerLabel.text = text
        }
    }
    
    func updateProgress(value: CGFloat) {
        DispatchQueue.main.async {
            self.stepProgressView.updateProgress(for: "Step Timer", to: value)
        }
    }
    
    func setPlayPauseState(isPlaying: Bool) {
        self.isPlaying = isPlaying
        let iconName = isPlaying ? "pause" : "play"
        let config = UIImage.SymbolConfiguration(pointSize: 26, weight: .semibold)
        
        DispatchQueue.main.async {
            self.playPauseButton.setImage(UIImage(systemName: iconName, withConfiguration: config), for: .normal)
        }
    }

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
