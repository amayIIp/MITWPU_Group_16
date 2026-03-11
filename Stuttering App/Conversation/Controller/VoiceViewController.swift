// VoiceViewController.swift

import UIKit

// MARK: - AudioWaveformView

class AudioWaveformView: UIView {
    private let stackView = UIStackView()
    private var bars: [UIView] = []
    private let numberOfBars = 15 // Reduced for better spacing
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .equalSpacing
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        
        // Create the bars
        for _ in 0..<numberOfBars {
            let bar = UIView()
            bar.backgroundColor = UIColor(resource: .buttonTheme)
            bar.layer.cornerRadius = 2
            bar.translatesAutoresizingMaskIntoConstraints = false
            
            // Set base width and height (flat state)
            bar.widthAnchor.constraint(equalToConstant: 4).isActive = true
            let heightConstraint = bar.heightAnchor.constraint(equalToConstant: 4)
            heightConstraint.isActive = true
            
            stackView.addArrangedSubview(bar)
            bars.append(bar)
        }
    }
    
    func update(with level: CGFloat) {
        UIView.animate(withDuration: 0.1, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
            for (index, bar) in self.bars.enumerated() {
                guard let heightConstraint = bar.constraints.first(where: { $0.firstAttribute == .height }) else { continue }
                
                if level <= 0.05 {
                    heightConstraint.constant = 4
                } else {
                    let center = CGFloat(self.numberOfBars / 2)
                    let distanceToCenter = abs(CGFloat(index) - center)
                    let normalizedDistance = max(0, 1.0 - (distanceToCenter / center))
                    
                    let flutter = CGFloat.random(in: 0.6...1.0)
                    let maxHeight: CGFloat = 80.0
                    
                    let newHeight = max(4, maxHeight * level * normalizedDistance * flutter)
                    heightConstraint.constant = newHeight
                }
                self.layoutIfNeeded()
            }
        }
    }
}

// MARK: - VoiceViewController

class VoiceViewController: UIViewController {
    
    // MARK: - Outlets
    
    @IBOutlet weak var aiTextView: UITextView!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var resetButton: UIButton!
    
    // MARK: - Properties
    
    private let viewModel = VoiceViewModel()
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    private var pendingTabViewController: UIViewController?
    
    // Programmatic UI Elements
    private var aiMessageLabel: UILabel!
    private var userMessageLabel: UILabel!
    private var waveformView: AudioWaveformView!
    private let startPromptLabel = UILabel()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.delegate = self
        tabBarController?.delegate = self
        configureUI()
        feedbackGenerator.prepare()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !viewModel.isModelReady {
            Task {
                await viewModel.prepareModel()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if isMovingFromParent || isBeingDismissed {
            viewModel.stopSession()
            viewModel.resetConversationHistory()
            resetDisplay()
        }
    }
    
    deinit {
        viewModel.stopSession()
    }
    
    // MARK: - UI Configuration
    
    private func configureUI() {
        aiTextView.isHidden = true
        
        configureButtons()
        setupChatLabels()
        setupWaveformView()
        setupStartPromptLabel()
        setupTouchFix() // 🛠️ Fixes the untappable button bug
    }
    
    private func configureButtons() {
        var resetConfig = UIButton.Configuration.glass()
        resetConfig.image = UIImage(systemName: "arrow.clockwise")
        resetConfig.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        resetButton.configuration = resetConfig
        resetButton.setTitle("", for: .normal)
        
        var recordConfig = UIButton.Configuration.glass()
        recordConfig.image = UIImage(systemName: "mic.slash")
        recordConfig.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
        recordButton.configuration = recordConfig
        recordButton.setTitle("", for: .normal)
    }
    
    private func setupWaveformView() {
        waveformView = AudioWaveformView()
        waveformView.translatesAutoresizingMaskIntoConstraints = false
        waveformView.alpha = 0
        waveformView.isUserInteractionEnabled = false // Let taps pass through
        view.addSubview(waveformView)
        
        NSLayoutConstraint.activate([
            waveformView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            waveformView.centerYAnchor.constraint(equalTo: recordButton.centerYAnchor),
            waveformView.heightAnchor.constraint(equalToConstant: 100)
        ])
    }
    
    private func setupStartPromptLabel() {
            startPromptLabel.translatesAutoresizingMaskIntoConstraints = false
            startPromptLabel.text = "Tap mic to start"
            startPromptLabel.textColor = .secondaryLabel
            startPromptLabel.font = .systemFont(ofSize: 16, weight: .medium)
            startPromptLabel.textAlignment = .center
            startPromptLabel.alpha = 1.0
            startPromptLabel.isUserInteractionEnabled = false
            view.addSubview(startPromptLabel)
            
            NSLayoutConstraint.activate([
                // Perfectly centered horizontally
                startPromptLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                // Perfectly centered vertically in the middle of the screen
                startPromptLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
            ])
        }
    private func setupChatLabels() {
        guard let container = aiTextView.superview else { return }
        
        aiMessageLabel = UILabel()
        aiMessageLabel.translatesAutoresizingMaskIntoConstraints = false
        aiMessageLabel.numberOfLines = 0
        aiMessageLabel.lineBreakMode = .byWordWrapping
        aiMessageLabel.font = .systemFont(ofSize: 17, weight: .medium)
        aiMessageLabel.textColor = .label
        aiMessageLabel.textAlignment = .left
        aiMessageLabel.alpha = 0
        container.addSubview(aiMessageLabel)
        
        userMessageLabel = UILabel()
        userMessageLabel.translatesAutoresizingMaskIntoConstraints = false
        userMessageLabel.numberOfLines = 0
        userMessageLabel.lineBreakMode = .byWordWrapping
        userMessageLabel.font = .systemFont(ofSize: 17, weight: .medium)
        userMessageLabel.textColor = .label
        userMessageLabel.textAlignment = .right
        userMessageLabel.alpha = 0
        container.addSubview(userMessageLabel)
        
        let padding: CGFloat = 20
        
        NSLayoutConstraint.activate([
            aiMessageLabel.topAnchor.constraint(equalTo: aiTextView.topAnchor, constant: 16),
            aiMessageLabel.leadingAnchor.constraint(equalTo: aiTextView.leadingAnchor, constant: padding),
            aiMessageLabel.trailingAnchor.constraint(equalTo: aiTextView.trailingAnchor, constant: -padding),
            
            userMessageLabel.topAnchor.constraint(equalTo: aiMessageLabel.bottomAnchor, constant: 24),
            userMessageLabel.leadingAnchor.constraint(equalTo: aiTextView.leadingAnchor, constant: padding),
            userMessageLabel.trailingAnchor.constraint(equalTo: aiTextView.trailingAnchor, constant: -padding),
        ])
    }
    
    // MARK: - 🛠️ Touch Fix Hack
    
    private func setupTouchFix() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleScreenTap(_:)))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        view.addGestureRecognizer(tap)
    }
    
    @objc private func handleScreenTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: view)
        
        let recordRect = recordButton.convert(recordButton.bounds, to: view)
        let resetRect = resetButton.convert(resetButton.bounds, to: view)
        
        if recordRect.contains(location) && recordButton.isEnabled {
            UIView.animate(withDuration: 0.1, animations: { self.recordButton.alpha = 0.5 }) { _ in
                UIView.animate(withDuration: 0.1) { self.recordButton.alpha = 1.0 }
            }
            didTapRecord(recordButton)
        } else if resetRect.contains(location) && resetButton.isEnabled {
            UIView.animate(withDuration: 0.1, animations: { self.resetButton.alpha = 0.5 }) { _ in
                UIView.animate(withDuration: 0.1) { self.resetButton.alpha = 1.0 }
            }
            didTapReset(resetButton)
        }
    }
    
    // MARK: - Display Helpers (Updated AI anchoring logic)
    
    private func showAIMessage(_ text: String) {
        // Fly user message UP and fade out when the AI responds
        if self.userMessageLabel.alpha > 0 {
            UIView.animate(withDuration: 0.3, animations: {
                self.userMessageLabel.transform = CGAffineTransform(translationX: 0, y: -30)
                self.userMessageLabel.alpha = 0
            }) { _ in
                self.userMessageLabel.text = ""
                self.userMessageLabel.transform = .identity
            }
        }
        
        // Update the AI message text smoothly
        if self.aiMessageLabel.alpha > 0 {
            // If the AI message is already on screen, cross-fade to the new text
            UIView.transition(with: self.aiMessageLabel, duration: 0.3, options: .transitionCrossDissolve) {
                self.aiMessageLabel.text = text
            }
        } else {
            // For the very first AI message, slide it up into place
            self.aiMessageLabel.text = text
            self.aiMessageLabel.transform = CGAffineTransform(translationX: 0, y: 20)
            UIView.animate(withDuration: 0.4, delay: 0.1, options: .curveEaseOut) {
                self.aiMessageLabel.transform = .identity
                self.aiMessageLabel.alpha = 1
            }
        }
    }
    
    private func showUserMessage(_ text: String) {
        // NOTE: We no longer hide the AI message here! It stays anchored at the top.
        
        // If the user label was hidden, slide it up into place beneath the AI message
        if userMessageLabel.alpha == 0 {
            userMessageLabel.transform = CGAffineTransform(translationX: 0, y: 20)
            UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseOut) {
                self.userMessageLabel.alpha = 1
                self.userMessageLabel.transform = .identity
            }
        }
        
        // Update the live transcription text
        userMessageLabel.text = text
    }
    
    private func resetDisplay(completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.4, delay: 0, options: [.curveEaseIn]) {
            // Fly labels UP and out when clearing
            self.aiMessageLabel?.transform = CGAffineTransform(translationX: 0, y: -40)
            self.aiMessageLabel?.alpha = 0
            
            self.userMessageLabel?.transform = CGAffineTransform(translationX: 0, y: -40)
            self.userMessageLabel?.alpha = 0
            
            self.recordButton.transform = .identity
            self.resetButton.transform = .identity
            self.waveformView.alpha = 0
            self.startPromptLabel.alpha = 1.0
        } completion: { _ in
            self.aiMessageLabel?.text = ""
            self.userMessageLabel?.text = ""
            
            // Reset their position so they don't stay hidden off-screen
            self.aiMessageLabel?.transform = .identity
            self.userMessageLabel?.transform = .identity
            
            completion?()
        }
    }
    
    // MARK: - Actions
    
    @IBAction func didTapReset(_ sender: UIButton) {
        feedbackGenerator.impactOccurred()
        
        if viewModel.isConversationActive || viewModel.hasConversationHistory {
            showResetConfirmation()
        } else {
            showMicPromptAlert()
        }
    }
    
    @IBAction func didTapRecord(_ sender: UIButton) {
        feedbackGenerator.impactOccurred()
        
        if viewModel.state == .listening {
            viewModel.stopListening()
        } else {
            if !viewModel.isConversationActive && !viewModel.hasConversationHistory {
                viewModel.startConversation()
            } else {
                viewModel.startListening()
            }
        }
    }
    
    private func showResetConfirmation() {
        let alert = UIAlertController(
            title: "Restart Conversation?",
            message: "This will clear your current conversation and start fresh.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Restart", style: .destructive) { [weak self] _ in
            self?.resetDisplay {
                self?.viewModel.resetConversation()
            }
        })
        
        present(alert, animated: true)
    }
    
    private func showMicPromptAlert() {
        let alert = UIAlertController(
            title: "No Active Conversation",
            message: "Tap the mic button to unmute the microphone and start the conversation.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Visual Updates
    
    private func updateVisuals(for state: VoiceViewModel.VoiceState) {
        var symbol: String
        var isEnabled = true
        
        switch state {
        case .idle:
            symbol = "mic.slash"
        case .speaking, .listening:
            symbol = "mic"
        case .thinking:
            symbol = "mic"
            isEnabled = false
        }
        
        let isSessionActive = viewModel.isConversationActive || viewModel.hasConversationHistory
        
        UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseInOut) {
            
            var config = UIButton.Configuration.glass()
            config.image = UIImage(systemName: symbol)
            config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
            
            self.recordButton.configuration = config
            self.recordButton.setTitle("", for: .normal)
            self.recordButton.isEnabled = isEnabled
            self.recordButton.alpha = isEnabled ? 1.0 : 0.6
            
            if isSessionActive {
                self.resetButton.transform = CGAffineTransform(translationX: -75, y: 0)
                self.recordButton.transform = CGAffineTransform(translationX: 75, y: 0)
                
                self.waveformView.alpha = 1.0
                self.startPromptLabel.alpha = 0.0
            } else {
                self.recordButton.transform = .identity
                self.resetButton.transform = .identity
                
                self.waveformView.alpha = 0.0
                self.startPromptLabel.alpha = 1.0
            }
            
            if state != .listening {
                self.waveformView.update(with: 0.0)
            }
        }
    }
}

// MARK: - UIGestureRecognizerDelegate

extension VoiceViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if let view = touch.view, view.isDescendant(of: recordButton) || view.isDescendant(of: resetButton) {
            return false
        }
        return true
    }
}

// MARK: - VoiceViewModelDelegate

extension VoiceViewController: VoiceViewModelDelegate {
    
    func didUpdateState(_ state: VoiceViewModel.VoiceState) {
        Task { @MainActor in
            self.updateVisuals(for: state)
        }
    }
    
    func didUpdateTranscript(_ text: String, isUser: Bool) {
        Task { @MainActor in
            if isUser && text != "Listening..." {
                self.showUserMessage(text)
            }
        }
    }
    
    func addMessageToConversation(speaker: String, text: String) {
        Task { @MainActor in
            if speaker == "AI" {
                self.showAIMessage(text)
            } else {
                self.showUserMessage(text)
            }
        }
    }
    
    func didEncounterError(_ message: String) {
        Task { @MainActor in
            let errorFeedback = UINotificationFeedbackGenerator()
            errorFeedback.notificationOccurred(.error)
        }
    }
    
    func didUpdateAudioLevel(_ level: Float) {
        Task { @MainActor in
            self.waveformView.update(with: CGFloat(level))
        }
    }
}

// MARK: - UITabBarControllerDelegate

extension VoiceViewController: UITabBarControllerDelegate {
    
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        if viewModel.isConversationActive || viewModel.hasConversationHistory {
            pendingTabViewController = viewController
            showExitConversationAlert()
            return false
        }
        return true
    }
    
    private func showExitConversationAlert() {
        let alert = UIAlertController(
            title: "End Conversation?",
            message: "You're currently in an active conversation.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.pendingTabViewController = nil
        })
        
        alert.addAction(UIAlertAction(title: "Exit", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            self.viewModel.stopSession()
            self.viewModel.resetConversationHistory()
            self.resetDisplay()
            self.switchToPendingTab()
            self.pendingTabViewController = nil
        })
        
        present(alert, animated: true) {
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.warning)
        }
    }
    
    private func switchToPendingTab() {
        guard let destination = pendingTabViewController else { return }
        tabBarController?.selectedViewController = destination
    }
}
