// VoiceViewController.swift

import UIKit

// MARK: - Chat Message Model

struct ChatMessage {
    let id = UUID()
    let speaker: String
    var text: String
    var isTranscribing: Bool = false
}

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
    
    // Chat Stack View (non-scrolling, shows last 4 messages)
    private var chatStackView: UIStackView!
    private var displayedBubbles: [UIView] = []
    private var liveTranscriptBubble: UIView?
    private let maxVisibleMessages = 4
    
    // Topic Selection UI
    private var topicSelectionView: UIView!
    private var topicChipViews: [UIView] = []
    private var selectedTopic: String?
    
    // MARK: - Onboarding Gate
    private func setupOnboardingOverlayIfNeeded() {
        guard !AppState.isConvoCompleted else { return }
        
        let features = [
            OnboardingFeature(iconName: "bubble.left.and.bubble.right.fill", title: "Topic-Based Practice", description: "Select specific topics from the interactive bubbles to start a focused discussion."),
            OnboardingFeature(iconName: "waveform.circle.fill", title: "Real-Time Voice AI", description: "Engage in seamless, natural spoken conversations to simulate real-world scenarios."),
            OnboardingFeature(iconName: "chart.bar.doc.horizontal", title: "Conversational Analytics", description: "Review detailed insights into your conversational fluency and trouble spots.")
        ]
        
        let overlay = ModuleOnboardingOverlayView(
            subtitle: "Master your speaking skills through real-time AI interaction and feedback.",
            features: features,
            footerText: "Progress is synced with your profile."
        )
        overlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlay)
        
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        overlay.onContinue = {
            AppState.isConvoCompleted = true
            UIView.animate(withDuration: 0.3, animations: {
                overlay.alpha = 0
            }) { _ in
                overlay.removeFromSuperview()
            }
        }
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.delegate = self
        tabBarController?.delegate = self
        
        // Keep the "Conversation" large title pinned — don't collapse on scroll
        navigationItem.largeTitleDisplayMode = .always
        navigationController?.navigationBar.prefersLargeTitles = true
        
        configureUI()
        feedbackGenerator.prepare()
        setupOnboardingOverlayIfNeeded()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !viewModel.isModelReady {
            Task { await viewModel.prepareModel() }
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
        setupChatStack()
        
        // 🛠️ The New Dynamic Stack Setup
        setupStackViews()
        
        // Topic selection overlay (on top of everything)
        setupTopicSelectionView()
        
        // Touch fix hack removed — was causing double-firing of button actions
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
        
        // Set initial hidden states — all controls hidden until topic is selected
        resetButton.isHidden = true
        resetButton.alpha = 0
        recordButton.isHidden = true
        recordButton.alpha = 0
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
    
    private func setupTopicSelectionView() {
        guard let container = aiTextView.superview else { return }
        
        topicSelectionView = UIView()
        topicSelectionView.translatesAutoresizingMaskIntoConstraints = false
        topicSelectionView.backgroundColor = .clear
        container.addSubview(topicSelectionView)
        
        NSLayoutConstraint.activate([
            topicSelectionView.topAnchor.constraint(equalTo: container.topAnchor),
            topicSelectionView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            topicSelectionView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            topicSelectionView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        // 1. AI Chat Bubble — native iOS styling
        let aiBubble = UIView()
        aiBubble.translatesAutoresizingMaskIntoConstraints = false
        aiBubble.backgroundColor = .secondarySystemBackground
        aiBubble.layer.cornerRadius = 18
        topicSelectionView.addSubview(aiBubble)
        
        let aiBubbleLabel = UILabel()
        aiBubbleLabel.translatesAutoresizingMaskIntoConstraints = false
        aiBubbleLabel.text = "Hi! What would you like to talk about today?"
        aiBubbleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        aiBubbleLabel.textColor = .label
        aiBubbleLabel.numberOfLines = 0
        aiBubble.addSubview(aiBubbleLabel)
        
        // 2. Topic Options
        let topics = [
            "I'll introduce myself",
            "Can we talk about my weekend plans?",
            "Let's talk about my day"
        ]
        
        let optionsStack = UIStackView()
        optionsStack.translatesAutoresizingMaskIntoConstraints = false
        optionsStack.axis = .vertical
        optionsStack.spacing = 10
        optionsStack.alignment = .trailing
        topicSelectionView.addSubview(optionsStack)
        
        for topic in topics {
            let chipView = UIView()
            chipView.translatesAutoresizingMaskIntoConstraints = false
            chipView.backgroundColor = .secondarySystemBackground
            chipView.layer.cornerRadius = 20
            chipView.layer.borderWidth = 1
            chipView.layer.borderColor = UIColor.separator.cgColor
            
            let chipLabel = UILabel()
            chipLabel.translatesAutoresizingMaskIntoConstraints = false
            chipLabel.text = topic
            chipLabel.font = .systemFont(ofSize: 14, weight: .medium)
            chipLabel.textColor = .label
            
            chipView.addSubview(chipLabel)
            
            NSLayoutConstraint.activate([
                chipLabel.leadingAnchor.constraint(equalTo: chipView.leadingAnchor, constant: 18),
                chipLabel.trailingAnchor.constraint(equalTo: chipView.trailingAnchor, constant: -18),
                chipLabel.topAnchor.constraint(equalTo: chipView.topAnchor, constant: 10),
                chipLabel.bottomAnchor.constraint(equalTo: chipView.bottomAnchor, constant: -10)
            ])
            
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(topicChipTapped(_:)))
            chipView.addGestureRecognizer(tapGesture)
            chipView.isUserInteractionEnabled = true
            chipView.accessibilityLabel = topic
            
            optionsStack.addArrangedSubview(chipView)
            topicChipViews.append(chipView)
        }
        
        // 3. Start Talking Button
        let startButton = UIButton(type: .system)
        startButton.translatesAutoresizingMaskIntoConstraints = false
        startButton.setTitle("Start Talking", for: .normal)
        startButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        startButton.setTitleColor(.white, for: .normal)
        startButton.backgroundColor = UIColor(resource: .buttonThemeMain)
        startButton.layer.cornerRadius = 25
        startButton.clipsToBounds = true
        startButton.addTarget(self, action: #selector(startTalkingTapped), for: .touchUpInside)
        topicSelectionView.addSubview(startButton)
        
        // 4. Layout Constraints
        let pad: CGFloat = 16
        NSLayoutConstraint.activate([
            // RE-ANCHORED: aiBubble now pins to the top of topicSelectionView
            aiBubble.topAnchor.constraint(equalTo: topicSelectionView.topAnchor, constant: pad),
            aiBubble.leadingAnchor.constraint(equalTo: topicSelectionView.leadingAnchor, constant: pad),
            aiBubble.trailingAnchor.constraint(lessThanOrEqualTo: topicSelectionView.trailingAnchor, constant: -60),
            
            aiBubbleLabel.topAnchor.constraint(equalTo: aiBubble.topAnchor, constant: 14),
            aiBubbleLabel.bottomAnchor.constraint(equalTo: aiBubble.bottomAnchor, constant: -14),
            aiBubbleLabel.leadingAnchor.constraint(equalTo: aiBubble.leadingAnchor, constant: 16),
            aiBubbleLabel.trailingAnchor.constraint(equalTo: aiBubble.trailingAnchor, constant: -16),
            
            startButton.bottomAnchor.constraint(equalTo: topicSelectionView.bottomAnchor, constant: -pad),
            startButton.leadingAnchor.constraint(equalTo: topicSelectionView.leadingAnchor, constant: pad),
            startButton.trailingAnchor.constraint(equalTo: topicSelectionView.trailingAnchor, constant: -pad),
            startButton.heightAnchor.constraint(equalToConstant: 50),
            
            optionsStack.bottomAnchor.constraint(equalTo: startButton.topAnchor, constant: -16),
            optionsStack.trailingAnchor.constraint(equalTo: topicSelectionView.trailingAnchor, constant: -pad),
            optionsStack.leadingAnchor.constraint(greaterThanOrEqualTo: topicSelectionView.leadingAnchor, constant: pad)
        ])
    }
    
    @objc private func topicChipTapped(_ gesture: UITapGestureRecognizer) {
        guard let chipView = gesture.view else { return }
        feedbackGenerator.impactOccurred()
        selectedTopic = chipView.accessibilityLabel
        
        // Scale-only feedback — no background color change to avoid color persistence bug
        UIView.animate(withDuration: 0.1, animations: {
            chipView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                chipView.transform = .identity
            }
            self.beginConversationWithSelectedTopic()
        }
    }
    
    @objc private func startTalkingTapped() {
        feedbackGenerator.impactOccurred()
        beginConversationWithSelectedTopic()
    }
    
    private func beginConversationWithSelectedTopic() {
        chatStackView.isHidden = false
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0, options: .curveEaseInOut, animations: {
            self.topicSelectionView.alpha = 0
            self.topicSelectionView.transform = CGAffineTransform(translationX: 0, y: -30)
            self.chatStackView.alpha = 1.0
        }) { _ in
            self.topicSelectionView.isHidden = true
        }
        
        startSessionTimer()
        
        if let topic = selectedTopic {
            viewModel.startConversation(withTopic: topic)
        } else {
            viewModel.startConversation()
        }
    }
    
    private func setupChatStack() {
        guard let container = aiTextView.superview else { return }
        
        chatStackView = UIStackView()
        chatStackView.translatesAutoresizingMaskIntoConstraints = false
        chatStackView.axis = .vertical
        chatStackView.spacing = 8
        chatStackView.alignment = .fill
        chatStackView.distribution = .fill
        chatStackView.alpha = 0
        chatStackView.isHidden = true
        
        container.insertSubview(chatStackView, at: 0)
        
        NSLayoutConstraint.activate([
            chatStackView.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            chatStackView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            chatStackView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
    }
    
    // MARK: - Bubble Factory
    
    private func makeBubbleView(for message: ChatMessage) -> UIView {
        let wrapper = UIView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        
        let bubble = UIView()
        bubble.translatesAutoresizingMaskIntoConstraints = false
        bubble.layer.cornerRadius = 18
        
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.tag = 100 // tag for live transcript updates
        
        bubble.addSubview(label)
        wrapper.addSubview(bubble)
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -10),
            label.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -14),
            
            bubble.topAnchor.constraint(equalTo: wrapper.topAnchor),
            bubble.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
            bubble.widthAnchor.constraint(lessThanOrEqualTo: wrapper.widthAnchor, multiplier: 0.78),
        ])
        
        label.text = message.text
        
        if message.speaker == "AI" {
            bubble.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 12).isActive = true
            bubble.backgroundColor = .secondarySystemBackground
            label.textColor = .label
        } else {
            bubble.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -12).isActive = true
            if message.isTranscribing {
                bubble.backgroundColor = .tertiarySystemFill
                label.textColor = .secondaryLabel
            } else {
                bubble.backgroundColor = UIColor(resource: .buttonThemeMain)
                label.textColor = .white
            }
        }
        
        return wrapper
    }
    
    // MARK: - Chat Message Management
    
    private func addChatMessage(speaker: String, text: String) {
        // If committing a live transcript, convert it in place
        if speaker == "User", let liveBubble = liveTranscriptBubble {
            if let label = liveBubble.viewWithTag(100) as? UILabel {
                label.text = text
                label.textColor = .white
            }
            if let bubble = liveBubble.subviews.first {
                bubble.backgroundColor = UIColor(resource: .buttonThemeMain)
            }
            // Fix applied: we leave the liveTranscriptBubble intact here
            // so late transcript updates aren't orphaned into a new bubble.
            return
        }
        
        let msg = ChatMessage(speaker: speaker, text: text)
        let bubbleView = makeBubbleView(for: msg)
        bubbleView.alpha = 0
        bubbleView.transform = CGAffineTransform(translationX: 0, y: 15)
        
        chatStackView.addArrangedSubview(bubbleView)
        displayedBubbles.append(bubbleView)
        
        // Fix applied: Re-assign the new committed bubble as the active transcript
        // reference just in case late transcripts fire after the text is committed.
        if speaker == "User" {
            liveTranscriptBubble = bubbleView
        }
        
        // Animate in
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0, options: .curveEaseOut) {
            bubbleView.alpha = 1
            bubbleView.transform = .identity
        }
        
        // Trim oldest if over max
        trimOldBubbles()
    }
    
    private func updateLiveTranscript(_ text: String) {
        if let liveBubble = liveTranscriptBubble {
            if let label = liveBubble.viewWithTag(100) as? UILabel {
                label.text = text
            }
        } else {
            let msg = ChatMessage(speaker: "User", text: text, isTranscribing: true)
            let bubbleView = makeBubbleView(for: msg)
            bubbleView.alpha = 0
            bubbleView.transform = CGAffineTransform(translationX: 0, y: 15)
            
            chatStackView.addArrangedSubview(bubbleView)
            displayedBubbles.append(bubbleView)
            liveTranscriptBubble = bubbleView
            
            UIView.animate(withDuration: 0.25) {
                bubbleView.alpha = 1
                bubbleView.transform = .identity
            }
            
            trimOldBubbles()
        }
    }
    
    private func trimOldBubbles() {
        while displayedBubbles.count > maxVisibleMessages {
            let oldest = displayedBubbles.removeFirst()
            UIView.animate(withDuration: 0.3, animations: {
                oldest.alpha = 0
                oldest.isHidden = true
            }) { _ in
                oldest.removeFromSuperview()
            }
        }
    }
    
    private func resetDisplay(completion: (() -> Void)? = nil) {
        self.topicSelectionView.isHidden = false
        self.topicSelectionView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        
        UIView.animate(withDuration: 0.8, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.0, options: [.curveEaseInOut]) {
            self.chatStackView.alpha = 0
            
            self.resetButton.isHidden = true
            self.resetButton.alpha = 0
            self.recordButton.isHidden = true
            self.recordButton.alpha = 0
            self.waveformView.isHidden = true
            self.waveformView.alpha = 0
            self.endButton.isHidden = true
            self.endButton.alpha = 0.0
            
            self.topicSelectionView.alpha = 1.0
            self.topicSelectionView.transform = .identity
            self.view.layoutIfNeeded()
        } completion: { _ in
            // Clear all bubbles
            for bubble in self.displayedBubbles {
                bubble.removeFromSuperview()
            }
            self.displayedBubbles.removeAll()
            self.liveTranscriptBubble = nil
            self.chatStackView.isHidden = true
            self.selectedTopic = nil
            for chip in self.topicChipViews {
                chip.backgroundColor = .secondarySystemBackground
            }
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
        viewModel.pauseSpeaking()
        
        let alert = UIAlertController(
            title: "End Conversation?",
            message: "Are you sure you want to end this session?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.viewModel.resumeSpeaking()
        })
        alert.addAction(UIAlertAction(title: "End", style: .destructive) { [weak self] _ in
            self?.executeEndSession()
        })
        
        present(alert, animated: true)
    }
    
    private func showResetConfirmation() {
        viewModel.pauseSpeaking()
        
        let alert = UIAlertController(
            title: "Restart Conversation?",
            message: "This will end the current conversation and take you back to topic selection.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.viewModel.resumeSpeaking()
        })
        alert.addAction(UIAlertAction(title: "Restart", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            let finalDuration = Int(self.sessionDuration)
            self.viewModel.stopSession()
            self.viewModel.resetConversationHistory()
            self.stopAndResetSessionTimer()
            self.resetDisplay()
            
            LogManager.shared.addLog(
                exerciseName: "Conversation",
                source: .conversation,
                exerciseDuration: finalDuration
            )
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
                // Show conversation controls
                self.resetButton.isHidden = false
                self.resetButton.alpha = 1.0
                self.recordButton.isHidden = false
                
                self.waveformView.isHidden = false
                self.waveformView.alpha = 1.0
                
                self.endButton.isHidden = false
                self.endButton.alpha = 1.0
                
                self.topicSelectionView.alpha = 0.0
                self.topicSelectionView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            } else {
                // Hide conversation controls, show topic selection
                self.resetButton.isHidden = true
                self.resetButton.alpha = 0
                self.recordButton.isHidden = true
                self.recordButton.alpha = 0
                
                self.waveformView.isHidden = true
                self.waveformView.alpha = 0.0
                
                self.endButton.isHidden = true
                self.endButton.alpha = 0.0
                
                self.topicSelectionView.alpha = 1.0
                self.topicSelectionView.transform = .identity
            }
            
            if state != .listening {
                self.waveformView.update(with: 0.0)
            }
            
            // 🛠️ MAGIC HAPPENS HERE: Forces the StackView to animate its layout updates
            self.view.layoutIfNeeded()
            
        } completion: { _ in
            if isSessionActive {
                self.topicSelectionView.isHidden = true
            }
        }
    }
}



// MARK: - VoiceViewModelDelegate

extension VoiceViewController: VoiceViewModelDelegate {
    func didUpdateState(_ state: VoiceViewModel.VoiceState) {
        Task { @MainActor in
            // Fix applied: explicitly clear the transcript bubble reference ONLY
            // when we begin a totally fresh listening turn.
            if state == .listening {
                self.liveTranscriptBubble = nil
            }
            self.updateVisuals(for: state)
        }
    }
    
    func didUpdateTranscript(_ text: String, isUser: Bool) {
        Task { @MainActor in
            // Only process transcripts while actively listening — prevents duplicates
            // from stale recognition callbacks that fire after commitUserBuffer
            guard isUser, text != "Listening...", self.viewModel.state == .listening else { return }
            self.updateLiveTranscript(text)
        }
    }
    
    func addMessageToConversation(speaker: String, text: String) {
        Task { @MainActor in
            self.addChatMessage(speaker: speaker, text: text)
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
        viewModel.pauseSpeaking()
        
        let alert = UIAlertController(title: "End Conversation?", message: "You're currently in an active conversation.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in 
            self?.pendingTabViewController = nil 
            self?.viewModel.resumeSpeaking()
        })
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
