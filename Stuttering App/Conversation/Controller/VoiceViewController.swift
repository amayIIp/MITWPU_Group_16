import UIKit

class VoiceViewController: UIViewController {
    
    @IBOutlet weak var aiTextView: UITextView!
    @IBOutlet weak var userLabel: UILabel!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var resetButton: UIButton!
    @IBOutlet weak var reportButton: UIButton!
    
    private let viewModel = VoiceViewModel()
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    var exerciseDuration = 300

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.delegate = self
        configureInterface()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task { await viewModel.prepareModel() }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.stopSession()
    }

    private func configureInterface() {
        aiTextView.text = "System initializing..."
        aiTextView.isEditable = false
        aiTextView.isSelectable = false
        aiTextView.font = .preferredFont(forTextStyle: .body)
        
        userLabel.text = "Tap the microphone to begin."
        userLabel.textColor = .secondaryLabel
        
        var resetConfig = UIButton.Configuration.glass()
        resetConfig.image = UIImage(systemName: "arrow.counterclockwise")
        resetButton.configuration = resetConfig
        
        var reportConfig = UIButton.Configuration.glass()
        reportConfig.image = UIImage(systemName: "doc.text")
        reportConfig.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(scale: .medium)
        reportButton.configuration = reportConfig
        
        updateVisuals(for: .idle)
    }

    @IBAction func didTapReset(_ sender: UIButton) {
        feedbackGenerator.impactOccurred()
        viewModel.resetConversation()
    }
    
    @IBAction func didTapRecord(_ sender: UIButton) {
        feedbackGenerator.impactOccurred()
        viewModel.commitUserBuffer()
    }
    
    @IBAction func didTapReport(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Conversation", bundle: nil)
        guard let ResultVC = storyboard.instantiateViewController(withIdentifier: "ConversationResultViewController") as? ConversationResultViewController else {
            return
        }
        
        let ResultNav = UINavigationController(rootViewController: ResultVC)
        ResultNav.modalPresentationStyle = .fullScreen
        self.present(ResultNav, animated: true, completion: nil)
        
        LogManager.shared.addLog(
            exerciseName: "Coversation",
            source: .conversation,
            exerciseDuration: self.exerciseDuration
        )
    }

    private func updateVisuals(for state: VoiceViewModel.VoiceState) {
        
        var symbol: String = "mic.fill"
        var labelText: String = ""
        
        switch state {
        case .idle:
            symbol = "mic"
            labelText = "Tap to speak"
            
        case .speaking:
            symbol = "stop"
            labelText = "AI is speaking..."
            
        case .listening:
            symbol = "waveform"
            labelText = "Listening..."
            
        case .thinking:
            symbol = "apple.intelligence"
            labelText = "Processing..."
        }
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
            self.userLabel.text = labelText
            
            var config = UIButton.Configuration.glass()
            config.image = UIImage(systemName: symbol)
            config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
            config.cornerStyle = .capsule
            
            self.recordButton.configuration = config
            self.recordButton.isEnabled = (state != .speaking)
            self.recordButton.alpha = (state == .speaking) ? 0.6 : 1.0
        }
    }
}

extension VoiceViewController: VoiceViewModelDelegate {
    
    func didUpdateState(_ state: VoiceViewModel.VoiceState) {
        DispatchQueue.main.async { [weak self] in
            self?.updateVisuals(for: state)
        }
    }
    
    func didUpdateTranscript(_ text: String, isUser: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if isUser {
                self.userLabel.text = text
            } else {
                self.aiTextView.text = text
            }
        }
    }
    
    func didEncounterError(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.userLabel.text = message
            self.userLabel.textColor = .systemRed
            
            let errorFeedback = UINotificationFeedbackGenerator()
            errorFeedback.notificationOccurred(.error)
        }
    }
}
