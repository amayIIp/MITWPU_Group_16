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
        UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
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
    @IBOutlet weak var endButton: UIButton!
    @IBOutlet weak var waveformView: AudioWaveformView!
    
    // MARK: - Properties
    
    private let viewModel = VoiceViewModel()
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    private var pendingTabViewController: UIViewController?
    
    private var sessionTimer: Timer?
    private var sessionDuration: TimeInterval = 0
    
    // Programmatic UI Elements
    private var aiMessageLabel: UILabel!
    private var userMessageLabel: UILabel!
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
        setupStartPromptLabel()
        
        // 🛠️ The New Dynamic Stack Setup
        setupStackViews()
        
        setupTouchFix()
    }
    
    private func setupStackViews() {
        // 1. Remove views from their storyboard constraints so we can animate them dynamically
        resetButton.removeFromSuperview()
        waveformView.removeFromSuperview()
        recordButton.removeFromSuperview()
        endButton.removeFromSuperview()
        
        // Give the waveform a fixed height so the stack doesn't jitter when the audio bounces
        waveformView.heightAnchor.constraint(equalToConstant: 80).isActive = true
        
        // 2. Horizontal Stack: When waveformView appears, it pushes the buttons outward
        let hStack = UIStackView(arrangedSubviews: [resetButton, waveformView, recordButton])
        hStack.axis = .horizontal
        hStack.spacing = 24
        hStack.alignment = .center
        hStack.distribution = .equalSpacing
        
        // 3. Vertical Stack: When endButton appears, it pushes the hStack upward
        let vStack = UIStackView(arrangedSubviews: [hStack, endButton])
        vStack.axis = .vertical
        vStack.spacing = 30
        vStack.alignment = .fill
        
        vStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(vStack)
        
        // Pin the vertical stack to the bottom of the screen
        NSLayoutConstraint.activate([
            vStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            vStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40)
        ])
        
        // Set initial hidden states
        waveformView.isHidden = true
        waveformView.alpha = 0
        endButton.isHidden = true
        endButton.alpha = 0
    }
    
    private func configureButtons() {
        var resetConfig = UIButton.Configuration.glass()
        resetConfig.image = UIImage(systemName: "arrow.clockwise")
        resetConfig.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        resetButton.configuration = resetConfig
        resetButton.setTitle("", for: .normal)
        
        var recordConfig = UIButton.Configuration.glass()
        recordConfig.image = UIImage(systemName: "mic.slash")
        recordConfig.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        recordButton.configuration = recordConfig
        recordButton.setTitle("", for: .normal)
        
        var endConfig = UIButton.Configuration.filled()
        endConfig.baseBackgroundColor = .systemRed
        endConfig.cornerStyle = .capsule
        endButton.configuration = endConfig
        endButton.setTitle("End", for: .normal)
    }
        
    private func startSessionTimer() {
        guard sessionTimer == nil else { return }
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.sessionDuration += 1
        }
    }
    
    private func stopAndResetSessionTimer() {
        sessionTimer?.invalidate()
        sessionTimer = nil
        sessionDuration = 0
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
            startPromptLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
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
        let endRect = endButton.convert(endButton.bounds, to: view)
        
        if recordRect.contains(location) && recordButton.isEnabled {
            UIView.animate(withDuration: 0.15, animations: { self.recordButton.alpha = 0.5 }) { _ in
                UIView.animate(withDuration: 0.15) { self.recordButton.alpha = 1.0 }
            }
            didTapRecord(recordButton)
        } else if resetRect.contains(location) && resetButton.isEnabled {
            UIView.animate(withDuration: 0.15, animations: { self.resetButton.alpha = 0.5 }) { _ in
                UIView.animate(withDuration: 0.15) { self.resetButton.alpha = 1.0 }
            }
            didTapReset(resetButton)
        } else if endRect.contains(location) && endButton.alpha > 0 {
            UIView.animate(withDuration: 0.15, animations: { self.endButton.alpha = 0.5 }) { _ in
                UIView.animate(withDuration: 0.15) { self.endButton.alpha = 1.0 }
            }
            didTapEnd(endButton)
        }
    }
    
    // MARK: - Display Helpers
    
    private func showAIMessage(_ text: String) {
        if self.userMessageLabel.alpha > 0 {
            UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.0, options: .curveEaseInOut, animations: {
                self.userMessageLabel.transform = CGAffineTransform(translationX: 0, y: -30)
                self.userMessageLabel.alpha = 0
            }) { _ in
                self.userMessageLabel.text = ""
                self.userMessageLabel.transform = .identity
            }
        }
        
        if self.aiMessageLabel.alpha > 0 {
            UIView.transition(with: self.aiMessageLabel, duration: 0.4, options: .transitionCrossDissolve) {
                self.aiMessageLabel.text = text
            }
        } else {
            self.aiMessageLabel.text = text
            self.aiMessageLabel.transform = CGAffineTransform(translationX: 0, y: 20)
            UIView.animate(withDuration: 0.6, delay: 0.1, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.0, options: .curveEaseOut, animations: {
                self.aiMessageLabel.transform = .identity
                self.aiMessageLabel.alpha = 1
            })
        }
    }
    
    private func showUserMessage(_ text: String) {
        if userMessageLabel.alpha == 0 {
            userMessageLabel.transform = CGAffineTransform(translationX: 0, y: 20)
            UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.0, options: .curveEaseOut, animations: {
                self.userMessageLabel.alpha = 1
                self.userMessageLabel.transform = .identity
            })
        }
        userMessageLabel.text = text
    }
    
    private func resetDisplay(completion: (() -> Void)? = nil) {
        self.startPromptLabel.isHidden = false
        self.startPromptLabel.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        
        UIView.animate(withDuration: 0.8, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.0, options: [.curveEaseInOut]) {
            self.aiMessageLabel?.transform = CGAffineTransform(translationX: 0, y: -40)
            self.aiMessageLabel?.alpha = 0
            
            self.userMessageLabel?.transform = CGAffineTransform(translationX: 0, y: -40)
            self.userMessageLabel?.alpha = 0
            
            // Re-hide stack elements so they snap back together
            self.waveformView.isHidden = true
            self.waveformView.alpha = 0
            
            self.endButton.isHidden = true
            self.endButton.alpha = 0.0
            
            self.startPromptLabel.alpha = 1.0
            self.startPromptLabel.transform = .identity
            
            // Trigger layout engine to animate the collapse smoothly
            self.view.layoutIfNeeded()
            
        } completion: { _ in
            self.aiMessageLabel?.text = ""
            self.userMessageLabel?.text = ""
            self.aiMessageLabel?.transform = .identity
            self.userMessageLabel?.transform = .identity
            completion?()
        }
    }
    
    // MARK: - Session Management
    
    private func executeEndSession() {
        let finalDuration = Int(self.sessionDuration)
        
        self.viewModel.stopSession()
        self.viewModel.resetConversationHistory()
        self.resetDisplay()
        self.stopAndResetSessionTimer()
        
        LogManager.shared.addLog(
            exerciseName: "Conversation",
            source: .conversation,
            exerciseDuration: finalDuration
        )
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
        startSessionTimer()
        
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
    
    @IBAction func didTapEnd(_ sender: UIButton) {
        feedbackGenerator.impactOccurred()
        
        let alert = UIAlertController(
            title: "End Conversation?",
            message: "Are you sure you want to end this session?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "End", style: .destructive) { [weak self] _ in
            self?.executeEndSession()
        })
        
        present(alert, animated: true)
    }
    
    private func showResetConfirmation() {
        let alert = UIAlertController(
            title: "Restart Conversation?",
            message: "This will clear your current conversation and start fresh.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Restart", style: .destructive) { [weak self] _ in
            self?.stopAndResetSessionTimer()
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
        
        UIView.animate(withDuration: 0.8, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.0, options: [.curveEaseInOut, .allowUserInteraction]) {
            
            var config = UIButton.Configuration.glass()
            config.image = UIImage(systemName: symbol)
            config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
            
            self.recordButton.configuration = config
            self.recordButton.setTitle("", for: .normal)
            self.recordButton.isEnabled = isEnabled
            self.recordButton.alpha = isEnabled ? 1.0 : 0.6
            
            if isSessionActive {
                // Changing isHidden inside the animation block triggers the layout shift
                self.waveformView.isHidden = false
                self.waveformView.alpha = 1.0
                
                self.endButton.isHidden = false
                self.endButton.alpha = 1.0
                
                self.startPromptLabel.alpha = 0.0
                self.startPromptLabel.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            } else {
                self.waveformView.isHidden = true
                self.waveformView.alpha = 0.0
                
                self.endButton.isHidden = true
                self.endButton.alpha = 0.0
                
                self.startPromptLabel.alpha = 1.0
                self.startPromptLabel.transform = .identity
            }
            
            if state != .listening {
                self.waveformView.update(with: 0.0)
            }
            
            // 🛠️ MAGIC HAPPENS HERE: Forces the StackView to animate its layout updates
            self.view.layoutIfNeeded()
            
        } completion: { _ in
            if isSessionActive {
                self.startPromptLabel.isHidden = true
            }
        }
    }
}

// MARK: - UIGestureRecognizerDelegate

extension VoiceViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if let view = touch.view, view.isDescendant(of: recordButton) || view.isDescendant(of: resetButton) || view.isDescendant(of: endButton) {
            return false
        }
        return true
    }
}

// MARK: - VoiceViewModelDelegate

extension VoiceViewController: VoiceViewModelDelegate {
    func didUpdateState(_ state: VoiceViewModel.VoiceState) {
        Task { @MainActor in self.updateVisuals(for: state) }
    }
    
    func didUpdateTranscript(_ text: String, isUser: Bool) {
        Task { @MainActor in
            if isUser && text != "Listening..." { self.showUserMessage(text) }
        }
    }
    
    func addMessageToConversation(speaker: String, text: String) {
        Task { @MainActor in
            if speaker == "AI" { self.showAIMessage(text) } else { self.showUserMessage(text) }
        }
    }
    
    func didEncounterError(_ message: String) {
        Task { @MainActor in UINotificationFeedbackGenerator().notificationOccurred(.error) }
    }
    
    func didUpdateAudioLevel(_ level: Float) {
        Task { @MainActor in self.waveformView.update(with: CGFloat(level)) }
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
        let alert = UIAlertController(title: "End Conversation?", message: "You're currently in an active conversation.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in self?.pendingTabViewController = nil })
        alert.addAction(UIAlertAction(title: "Exit", style: .destructive) { [weak self] _ in
            self?.executeEndSession()
            self?.switchToPendingTab()
            self?.pendingTabViewController = nil
        })
        present(alert, animated: true) { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    }
    
    private func switchToPendingTab() {
        guard let destination = pendingTabViewController else { return }
        tabBarController?.selectedViewController = destination
    }
}
