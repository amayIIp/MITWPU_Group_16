// VoiceViewController.swift

import UIKit

class VoiceViewController: UIViewController {
    
    @IBOutlet weak var aiTextView: UITextView!
    @IBOutlet weak var userLabel: UILabel!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var resetButton: UIButton!
    @IBOutlet weak var reportButton: UIButton!
    
    private let viewModel = VoiceViewModel()
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    
    var exerciseDuration = 0
    private var exerciseTimer: Timer?
    private var exerciseStartTime: Date?
    private var pendingTabViewController: UIViewController?
    private var conversationMessages: [(speaker: String, text: String)] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.delegate = self
        setupTabBarDelegate()
        configureUI()
        feedbackGenerator.prepare()
        
        aiTextView.inputView = UIView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !viewModel.isModelReady {
            startExerciseTimer()
            Task {
                await viewModel.prepareModel()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if isMovingFromParent || isBeingDismissed {
            stopExerciseTimer()
            viewModel.stopSession()
            clearConversation()
        }
    }
    
    deinit {
        stopExerciseTimer()
        viewModel.stopSession()
    }
    
    // MARK: - UI Configuration
    
    private func clearConversation() {
        conversationMessages.removeAll()
        showCenteredMessage("Tap the microphone to begin", isPlaceholder: true)
    }
    
    private func configureUI() {
        aiTextView.isEditable = false
        aiTextView.isSelectable = false
        aiTextView.isUserInteractionEnabled = false
        aiTextView.isScrollEnabled = false
        aiTextView.showsVerticalScrollIndicator = false
        aiTextView.text = "Tap the microphone to begin"
        aiTextView.font = .systemFont(ofSize: 17, weight: .regular)
        aiTextView.textColor = .secondaryLabel
        aiTextView.backgroundColor = .clear
        aiTextView.textAlignment = .center
        aiTextView.textContainerInset = UIEdgeInsets.zero
        aiTextView.textContainer.lineFragmentPadding = 0
        aiTextView.clipsToBounds = true
        
        userLabel.text = "Preparing AI..."
        userLabel.textColor = .secondaryLabel
        userLabel.font = .systemFont(ofSize: 15, weight: .medium)
        userLabel.textAlignment = .center
        userLabel.numberOfLines = 2
        
        configureButtons()
    }
    
    private func configureButtons() {
        var resetConfig = UIButton.Configuration.glass()
        resetConfig.image = UIImage(systemName: "arrow.counterclockwise")
        resetConfig.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
//        resetConfig.baseBackgroundColor = .systemBlue
//        resetConfig.baseForegroundColor = .white
//        resetConfig.cornerStyle = .capsule
//        resetConfig.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
        resetButton.configuration = resetConfig
        resetButton.setTitle("", for: .normal)
        
        var recordConfig = UIButton.Configuration.glass()
        recordConfig.image = UIImage(systemName: "waveform")
        recordConfig.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
//        recordConfig.baseBackgroundColor = .systemBlue
//        recordConfig.baseForegroundColor = .white
//        recordConfig.cornerStyle = .capsule
//        recordConfig.contentInsets = NSDirectionalEdgeInsets(top: 24, leading: 24, bottom: 24, trailing: 24)
        recordButton.configuration = recordConfig
        recordButton.setTitle("", for: .normal)
        
        var reportConfig = UIButton.Configuration.glass()
        reportConfig.image = UIImage(systemName: "doc.text")
        reportConfig.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
//        reportConfig.baseBackgroundColor = .systemBlue
//        reportConfig.baseForegroundColor = .white
//        reportConfig.cornerStyle = .capsule
//        reportConfig.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
        reportButton.configuration = reportConfig
        reportButton.setTitle("", for: .normal)
    }
    
    private func setupTabBarDelegate() {
        self.tabBarController?.delegate = self
    }
    
    // MARK: - Exercise Timer
    
    private func startExerciseTimer() {
        exerciseStartTime = Date()
        exerciseTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.exerciseStartTime else { return }
            self.exerciseDuration = Int(Date().timeIntervalSince(startTime))
        }
    }
    
    private func stopExerciseTimer() {
        exerciseTimer?.invalidate()
        exerciseTimer = nil
    }
    
    // MARK: - Actions
    
    @IBAction func didTapReset(_ sender: UIButton) {
        feedbackGenerator.impactOccurred()
        
        if viewModel.isConversationActive || viewModel.hasConversationHistory {
            showResetConfirmation()
        } else {
            viewModel.resetConversation()
            clearConversation()
        }
    }
    
    private func showResetConfirmation() {
        let alert = UIAlertController(
            title: "Reset Conversation?",
            message: "This will clear your current conversation and start fresh.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Reset", style: .destructive) { [weak self] _ in
            self?.viewModel.resetConversation()
            self?.clearConversation()
        })
        
        present(alert, animated: true)
    }
    
    @IBAction func didTapRecord(_ sender: UIButton) {
        feedbackGenerator.impactOccurred()
        
        if conversationMessages.isEmpty && !viewModel.isConversationActive {
            viewModel.startConversation()
        } else {
            viewModel.commitUserBuffer()
        }
    }
    
    @IBAction func didTapReport(_ sender: UIButton) {
        feedbackGenerator.impactOccurred()
        showReportOptionsAlert()
    }
    
    private func showReportOptionsAlert() {
        let alert = UIAlertController(
            title: "View Results?",
            message: "Would you like to view your conversation results or continue talking?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Back", style: .destructive))
        
        alert.addAction(UIAlertAction(title: "Result", style: .default) { [weak self] _ in
            guard let self = self else { return }
            
            if self.viewModel.isConversationActive {
                self.viewModel.stopSession()
            }
            
            self.showReport()
        })
        
        present(alert, animated: true)
    }
    
    private func showReport() {
        let storyboard = UIStoryboard(name: "Conversation", bundle: nil)
        guard let resultVC = storyboard.instantiateViewController(withIdentifier: "ConversationResultViewController") as? ConversationResultViewController else {
            showError("Could not load results view")
            return
        }
        
        let stutterJSON = viewModel.getStutterAnalysisJSON()
        
        resultVC.conversationDuration = self.exerciseDuration
        resultVC.stutterAnalysisJSON = stutterJSON
        
        let resultNav = UINavigationController(rootViewController: resultVC)
        resultNav.modalPresentationStyle = .fullScreen
        
        present(resultNav, animated: true) {
            LogManager.shared.addLog(
                exerciseName: "Conversation",
                source: .conversation,
                exerciseDuration: self.exerciseDuration
            )
        }
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Conversation Display
    
    private func updateConversationDisplay() {
        if conversationMessages.isEmpty {
            showCenteredMessage("Tap the microphone to begin", isPlaceholder: true)
            return
        }
        
        let maxVisibleMessages = 4
        let startIndex = max(0, conversationMessages.count - maxVisibleMessages)
        let visibleMessages = Array(conversationMessages[startIndex...])
        
        let attributedText = NSMutableAttributedString()
        
        for (index, message) in visibleMessages.enumerated() {
            let messageAge = visibleMessages.count - 1 - index
            let label = message.speaker == "AI" ? "AI" : "You"
            let prefix = "\(label): "
            let messageText = prefix + message.text
            let attributed = NSMutableAttributedString(string: messageText)
            
            let opacity: CGFloat
            let fontSize: CGFloat
            let weight: UIFont.Weight
            
            switch messageAge {
            case 0:
                opacity = 1.0
                fontSize = 17
                weight = .medium
            case 1:
                opacity = 0.55
                fontSize = 16
                weight = .regular
            case 2:
                opacity = 0.3
                fontSize = 15
                weight = .regular
            default:
                opacity = 0.15
                fontSize = 14
                weight = .light
            }
            
            attributed.addAttributes([
                .font: UIFont.systemFont(ofSize: fontSize, weight: weight),
                .foregroundColor: UIColor.label.withAlphaComponent(opacity)
            ], range: NSRange(location: 0, length: attributed.length))
            
            attributedText.append(attributed)
            
            if index < visibleMessages.count - 1 {
                attributedText.append(NSAttributedString(string: "\n\n"))
            }
        }
        
        UIView.transition(with: aiTextView, duration: 0.3, options: .transitionCrossDissolve) {
            self.aiTextView.attributedText = attributedText
            self.aiTextView.textAlignment = .center
        }
    }
    
    private func showCenteredMessage(_ text: String, isPlaceholder: Bool = false) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = 4
        
        let attributed = NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 17, weight: .regular),
                .foregroundColor: isPlaceholder ? UIColor.secondaryLabel : UIColor.label,
                .paragraphStyle: paragraphStyle
            ]
        )
        
        UIView.transition(with: aiTextView, duration: 0.3, options: .transitionCrossDissolve) {
            self.aiTextView.attributedText = attributed
            self.aiTextView.textAlignment = .center
        }
    }
    
    // MARK: - Visual Updates
    
    private func updateVisuals(for state: VoiceViewModel.VoiceState) {
        var symbol: String
        var statusText: String
        var isEnabled = true
        
        switch state {
        case .idle:
            symbol = "mic"
            statusText = viewModel.hasConversationHistory ? "Tap to speak" : "Tap to start"
        case .speaking:
            symbol = "stop"
            statusText = "AI is speaking..."
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
            self.userLabel.textColor = state == .idle ? .secondaryLabel : .label
            
            var config = self.recordButton.configuration ?? UIButton.Configuration.filled()
            config.image = UIImage(systemName: symbol)
            config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
            config.baseBackgroundColor = .systemBlue
            config.baseForegroundColor = .white
            config.cornerStyle = .capsule
            config.contentInsets = NSDirectionalEdgeInsets(top: 24, leading: 24, bottom: 24, trailing: 24)
            
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

// MARK: - VoiceViewModel Delegate

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
                }
                self.userLabel.textColor = .systemBlue
            }
        }
    }
    
    func addMessageToConversation(speaker: String, text: String) {
        Task { @MainActor in
            self.conversationMessages.append((speaker: speaker, text: text))
            self.updateConversationDisplay()
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
                    self.userLabel.text = "Tap to try again"
                    self.userLabel.textColor = .secondaryLabel
                }
            }
        }
    }
}

// MARK: - Tab Bar Controller Delegate

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
            
            let wordCount = self.viewModel.getTotalWordCount()
            
            if wordCount >= 10 {
                self.showReport()
            } else {
                self.switchToPendingTab()
            }
            
            self.pendingTabViewController = nil
        })
        
        present(alert, animated: true) {
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.warning)
        }
    }
    
    private func switchToPendingTab() {
        guard let destination = pendingTabViewController else { return }
        clearConversation()
        tabBarController?.selectedViewController = destination
    }
}
