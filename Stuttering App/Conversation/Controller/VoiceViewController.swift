// VoiceViewController.swift

import UIKit

class VoiceViewController: UIViewController {
    
    // MARK: - Outlets
    
    @IBOutlet weak var aiTextView: UITextView!
    @IBOutlet weak var userLabel: UILabel!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var resetButton: UIButton!
    
    // MARK: - Properties
    
    private let viewModel = VoiceViewModel()
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    private var pendingTabViewController: UIViewController?
    
    // Chat display
    private var aiMessageLabel: UILabel!
    private var userMessageLabel: UILabel!
    
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
        
        // Restore label when returning to this screen
        if !viewModel.isConversationActive {
            userLabel.text = "Tap the mic to start the conversation"
            userLabel.textColor = UIColor(resource: .buttonTheme)
        }
        
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
        // Hide the storyboard text view — we use our own labels
        aiTextView.isHidden = true
        
        userLabel.text = "Tap the mic to start the conversation"
        userLabel.textColor = UIColor(resource: .buttonTheme)
        userLabel.font = .systemFont(ofSize: 15, weight: .medium)
        userLabel.textAlignment = .center
        userLabel.numberOfLines = 2
        
        configureButtons()
        setupChatLabels()
    }
    
    private func configureButtons() {
        var resetConfig = UIButton.Configuration.glass()
        resetConfig.image = UIImage(systemName: "arrow.clockwise")
        resetConfig.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        resetButton.configuration = resetConfig
        resetButton.setTitle("", for: .normal)
        
        var recordConfig = UIButton.Configuration.glass()
        recordConfig.image = UIImage(systemName: "mic")
        recordConfig.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
        recordButton.configuration = recordConfig
        recordButton.setTitle("", for: .normal)
    }
    
    private func setupChatLabels() {
        guard let container = aiTextView.superview else { return }
        
        // AI message label — left aligned
        aiMessageLabel = UILabel()
        aiMessageLabel.translatesAutoresizingMaskIntoConstraints = false
        aiMessageLabel.numberOfLines = 0
        aiMessageLabel.lineBreakMode = .byWordWrapping
        aiMessageLabel.font = .systemFont(ofSize: 17, weight: .medium)
        aiMessageLabel.textColor = .label
        aiMessageLabel.textAlignment = .left
        aiMessageLabel.alpha = 0
        container.addSubview(aiMessageLabel)
        
        // User message label — right aligned
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
            // AI label — top area, left side
            aiMessageLabel.topAnchor.constraint(equalTo: aiTextView.topAnchor, constant: 16),
            aiMessageLabel.leadingAnchor.constraint(equalTo: aiTextView.leadingAnchor, constant: padding),
            aiMessageLabel.trailingAnchor.constraint(equalTo: aiTextView.trailingAnchor, constant: -padding),
            
            // User label — below AI label, right side
            userMessageLabel.topAnchor.constraint(equalTo: aiMessageLabel.bottomAnchor, constant: 24),
            userMessageLabel.leadingAnchor.constraint(equalTo: aiTextView.leadingAnchor, constant: padding),
            userMessageLabel.trailingAnchor.constraint(equalTo: aiTextView.trailingAnchor, constant: -padding),
        ])
    }
    
    // MARK: - Display Helpers
    
    private func showAIMessage(_ text: String) {
        // Clear previous user message when AI speaks again
        UIView.animate(withDuration: 0.2) {
            self.userMessageLabel.alpha = 0
        } completion: { _ in
            self.userMessageLabel.text = ""
        }
        
        aiMessageLabel.text = text
        UIView.animate(withDuration: 0.3) {
            self.aiMessageLabel.alpha = 1
        }
    }
    
    private func showUserMessage(_ text: String) {
        userMessageLabel.text = text
        UIView.animate(withDuration: 0.2) {
            self.userMessageLabel.alpha = 1
        }
    }
    
    private func resetDisplay() {
        aiMessageLabel?.text = ""
        aiMessageLabel?.alpha = 0
        userMessageLabel?.text = ""
        userMessageLabel?.alpha = 0
        userLabel.text = "Tap the mic to start the conversation"
        userLabel.textColor = UIColor(resource: .buttonTheme)
    }
    
    // MARK: - Actions
    
    @IBAction func didTapReset(_ sender: UIButton) {
        feedbackGenerator.impactOccurred()
        
        if viewModel.isConversationActive || viewModel.hasConversationHistory {
            showResetConfirmation()
        } else {
            viewModel.resetConversation()
        }
    }
    
    @IBAction func didTapRecord(_ sender: UIButton) {
        feedbackGenerator.impactOccurred()
        
        if !viewModel.isConversationActive {
            viewModel.startConversation()
        } else {
            viewModel.commitUserBuffer()
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
            self?.resetDisplay()
            self?.viewModel.resetConversation()
        })
        
        present(alert, animated: true)
    }
    
    // MARK: - Visual Updates
    
    private func updateVisuals(for state: VoiceViewModel.VoiceState) {
        var symbol: String
        var statusText: String
        var isEnabled = true
        
        switch state {
        case .idle:
            symbol = "mic"
            statusText = viewModel.hasConversationHistory ? "" : "Tap the mic to start the conversation"
        case .speaking:
            symbol = "mic"
            statusText = "AI is speaking"
        case .listening:
            symbol = "waveform"
            statusText = "Listening..."
        case .thinking:
            symbol = "brain"
            statusText = "Thinking..."
            isEnabled = false
        }
        
        UIView.animate(withDuration: 0.25) {
            self.userLabel.text = statusText
            self.userLabel.textColor = state == .idle ? .secondaryLabel : UIColor(resource: .buttonTheme)
            
            var config = UIButton.Configuration.glass()
            config.image = UIImage(systemName: symbol)
            config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
            
            self.recordButton.configuration = config
            self.recordButton.setTitle("", for: .normal)
            self.recordButton.isEnabled = isEnabled
            self.recordButton.alpha = isEnabled ? 1.0 : 0.6
            
            if state == .listening {
                self.addPulseAnimation()
            } else {
                self.recordButton.layer.removeAnimation(forKey: "pulse")
            }
        }
    }
    
    private func addPulseAnimation() {
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1.0
        pulse.toValue = 1.1
        pulse.duration = 0.8
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        recordButton.layer.add(pulse, forKey: "pulse")
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
            if isUser {
                if text == "Listening..." {
                    self.userLabel.text = "Listening..."
                } else {
                    self.userLabel.text = "You're speaking..."
                    self.showUserMessage(text)
                }
                self.userLabel.textColor = UIColor(resource: .buttonTheme)
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
            self.userLabel.text = "⚠️ \(message)"
            self.userLabel.textColor = .systemRed
            
            let errorFeedback = UINotificationFeedbackGenerator()
            errorFeedback.notificationOccurred(.error)
            
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if self.userLabel.text?.contains("⚠️") == true {
                    self.userLabel.text = "Tap mic to speak"
                    self.userLabel.textColor = .secondaryLabel
                }
            }
        }
    }
}

// MARK: - UITabBarControllerDelegate

extension VoiceViewController: UITabBarControllerDelegate {
    
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        if viewModel.isConversationActive {
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
