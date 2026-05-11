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
    
    // Chat Bubble Containers
    private var aiBubbleView: UIView!
    private var userBubbleView: UIView!
    
    // Topic Selection UI
    private var topicSelectionView: UIView!
    private var selectedTopic: String?
    
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
        setupChatBubbles()
        
        // 🛠️ The New Dynamic Stack Setup
        setupStackViews()
        
        // Topic selection overlay (on top of everything)
        setupTopicSelectionView()
        
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
        
        // AI Chat Bubble
        let aiBubble = UIView()
        aiBubble.translatesAutoresizingMaskIntoConstraints = false
        aiBubble.backgroundColor = UIColor(resource: .buttonTheme).withAlphaComponent(0.18)
        aiBubble.layer.cornerRadius = 16
        aiBubble.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        topicSelectionView.addSubview(aiBubble)
        
        let aiBubbleLabel = UILabel()
        aiBubbleLabel.translatesAutoresizingMaskIntoConstraints = false
        aiBubbleLabel.text = "Hi! What would you like to talk about today?"
        aiBubbleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        aiBubbleLabel.textColor = .label
        aiBubbleLabel.numberOfLines = 0
        aiBubble.addSubview(aiBubbleLabel)
        
        // Topic Options
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
            chipView.backgroundColor = .systemBackground
            chipView.layer.cornerRadius = 20
            chipView.layer.borderWidth = 1.5
            chipView.layer.borderColor = UIColor.systemGray4.cgColor
            
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
        }
        
        // Start Talking Button
//        let startButton = UIButton(type: .system)
//        startButton.translatesAutoresizingMaskIntoConstraints = false
//        startButton.setTitle("Start Talking", for: .normal)
//        startButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
//        startButton.setTitleColor(.white, for: .normal)
//        startButton.backgroundColor = UIColor(resource: .buttonThemeMain)
//        startButton.layer.cornerRadius = 25
//        startButton.clipsToBounds = true
//        startButton.addTarget(self, action: #selector(startTalkingTapped), for: .touchUpInside)
//        topicSelectionView.addSubview(startButton)
        let startButton = UIButton(type: .system)
        startButton.translatesAutoresizingMaskIntoConstraints = false
        startButton.setTitle("Start Talking", for: .normal)

        // Add the symbol and set its color to white
        startButton.setImage(UIImage(systemName: "microphone.fill"), for: .normal)
        startButton.tintColor = .white

        // Add a little padding between the icon and the text
        startButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 10)

        startButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        startButton.setTitleColor(.white, for: .normal)
        startButton.backgroundColor = UIColor(resource: .buttonThemeMain)
        startButton.layer.cornerRadius = 25
        startButton.clipsToBounds = true
        startButton.addTarget(self, action: #selector(startTalkingTapped), for: .touchUpInside)
        topicSelectionView.addSubview(startButton)
        
        // Layout
        let pad: CGFloat = 16
        NSLayoutConstraint.activate([
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
        
        // Visual feedback
        UIView.animate(withDuration: 0.15, animations: {
            chipView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            chipView.backgroundColor = UIColor(resource: .buttonTheme).withAlphaComponent(0.12)
        }) { _ in
            UIView.animate(withDuration: 0.15) {
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
        // Hide topic overlay with animation
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0, options: .curveEaseInOut, animations: {
            self.topicSelectionView.alpha = 0
            self.topicSelectionView.transform = CGAffineTransform(translationX: 0, y: -30)
        }) { _ in
            self.topicSelectionView.isHidden = true
        }
        
        startSessionTimer()
        
        // Start conversation with or without topic
        if let topic = selectedTopic {
            viewModel.startConversation(withTopic: topic)
        } else {
            viewModel.startConversation()
        }
    }
    
    private func setupChatBubbles() {
        guard let container = aiTextView.superview else { return }
        
        // AI Bubble
        aiBubbleView = UIView()
        aiBubbleView.translatesAutoresizingMaskIntoConstraints = false
        aiBubbleView.backgroundColor = .systemGray6
        aiBubbleView.layer.cornerRadius = 16
        aiBubbleView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        aiBubbleView.alpha = 0
        container.addSubview(aiBubbleView)
        
        aiMessageLabel = UILabel()
        aiMessageLabel.translatesAutoresizingMaskIntoConstraints = false
        aiMessageLabel.numberOfLines = 0
        aiMessageLabel.lineBreakMode = .byWordWrapping
        aiMessageLabel.font = .systemFont(ofSize: 16, weight: .medium)
        aiMessageLabel.textColor = .label
        aiMessageLabel.textAlignment = .left
        aiBubbleView.addSubview(aiMessageLabel)
        
        // User Bubble
        userBubbleView = UIView()
        userBubbleView.translatesAutoresizingMaskIntoConstraints = false
        userBubbleView.backgroundColor = .systemGray6
        userBubbleView.layer.cornerRadius = 16
        userBubbleView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner]
        userBubbleView.alpha = 0
        container.addSubview(userBubbleView)
        
        userMessageLabel = UILabel()
        userMessageLabel.translatesAutoresizingMaskIntoConstraints = false
        userMessageLabel.numberOfLines = 0
        userMessageLabel.lineBreakMode = .byWordWrapping
        userMessageLabel.font = .systemFont(ofSize: 16, weight: .medium)
        userMessageLabel.textColor = .label
        userMessageLabel.textAlignment = .right
        userBubbleView.addSubview(userMessageLabel)
        
        let padding: CGFloat = 16
        
        NSLayoutConstraint.activate([
            // AI bubble
            aiBubbleView.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            aiBubbleView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding),
            aiBubbleView.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -60),
            
            aiMessageLabel.topAnchor.constraint(equalTo: aiBubbleView.topAnchor, constant: 12),
            aiMessageLabel.bottomAnchor.constraint(equalTo: aiBubbleView.bottomAnchor, constant: -12),
            aiMessageLabel.leadingAnchor.constraint(equalTo: aiBubbleView.leadingAnchor, constant: 14),
            aiMessageLabel.trailingAnchor.constraint(equalTo: aiBubbleView.trailingAnchor, constant: -14),
            
            // User bubble
            userBubbleView.topAnchor.constraint(equalTo: aiBubbleView.bottomAnchor, constant: 16),
            userBubbleView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -padding),
            userBubbleView.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 60),
            
            userMessageLabel.topAnchor.constraint(equalTo: userBubbleView.topAnchor, constant: 12),
            userMessageLabel.bottomAnchor.constraint(equalTo: userBubbleView.bottomAnchor, constant: -12),
            userMessageLabel.leadingAnchor.constraint(equalTo: userBubbleView.leadingAnchor, constant: 14),
            userMessageLabel.trailingAnchor.constraint(equalTo: userBubbleView.trailingAnchor, constant: -14),
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
        if self.userBubbleView.alpha > 0 {
            UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.0, options: .curveEaseInOut, animations: {
                self.userBubbleView.transform = CGAffineTransform(translationX: 0, y: -30)
                self.userBubbleView.alpha = 0
            }) { _ in
                self.userMessageLabel.text = ""
                self.userBubbleView.transform = .identity
            }
        }
        
        if self.aiBubbleView.alpha > 0 {
            UIView.transition(with: self.aiMessageLabel, duration: 0.4, options: .transitionCrossDissolve) {
                self.aiMessageLabel.text = text
            }
        } else {
            self.aiMessageLabel.text = text
            self.aiBubbleView.transform = CGAffineTransform(translationX: 0, y: 20)
            UIView.animate(withDuration: 0.6, delay: 0.1, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.0, options: .curveEaseOut, animations: {
                self.aiBubbleView.transform = .identity
                self.aiBubbleView.alpha = 1
            })
        }
    }
    
    private func showUserMessage(_ text: String) {
        if userBubbleView.alpha == 0 {
            userBubbleView.transform = CGAffineTransform(translationX: 0, y: 20)
            UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.0, options: .curveEaseOut, animations: {
                self.userBubbleView.alpha = 1
                self.userBubbleView.transform = .identity
            })
        }
        userMessageLabel.text = text
    }
    
    private func resetDisplay(completion: (() -> Void)? = nil) {
        self.topicSelectionView.isHidden = false
        self.topicSelectionView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        
        UIView.animate(withDuration: 0.8, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.0, options: [.curveEaseInOut]) {
            self.aiBubbleView?.transform = CGAffineTransform(translationX: 0, y: -40)
            self.aiBubbleView?.alpha = 0
            
            self.userBubbleView?.transform = CGAffineTransform(translationX: 0, y: -40)
            self.userBubbleView?.alpha = 0
            
            // Re-hide all conversation controls
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
            
            // Trigger layout engine to animate the collapse smoothly
            self.view.layoutIfNeeded()
            
        } completion: { _ in
            self.aiMessageLabel?.text = ""
            self.userMessageLabel?.text = ""
            self.aiBubbleView?.transform = .identity
            self.userBubbleView?.transform = .identity
            self.selectedTopic = nil
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
            message: "This will end the current conversation and take you back to topic selection.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
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

// MARK: - UIGestureRecognizerDelegate

extension VoiceViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Don't intercept touches on buttons or topic selection overlay
        if let touchView = touch.view,
           touchView.isDescendant(of: recordButton) ||
           touchView.isDescendant(of: resetButton) ||
           touchView.isDescendant(of: endButton) ||
           (topicSelectionView != nil && !topicSelectionView.isHidden && touchView.isDescendant(of: topicSelectionView)) {
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
