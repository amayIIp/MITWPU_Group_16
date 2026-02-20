import UIKit
import Speech
import AVFoundation

class TestViewController: UIViewController, SFSpeechRecognizerDelegate {

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var previousButton: UIButton!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var resetButton: UIButton!
    @IBOutlet weak var continueButton: UIButton!
    @IBOutlet weak var bottomViewConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var waveformStackView: UIStackView!
    private var waveformBars: [UIView] = []
    private let numberOfBars = 9 // Adjust based on preference
    
    // The text the user needs to read
    let paragraphs: [String] = [
        "Because everyone has a significant story to tell, Peter, a professional photographer, typically describes his most incredible, adventurous experiences. My grandfather, who is nearly ninety-three years old, often ponders those vibrant, green mountains while talking to anyone who will listen attentively.",
        "Although communication can be challenging, he persists in connecting with the people in his community through vivid, descriptive language. Critics frequently keep track of his complicated techniques because they require great concentration and persistent practice.",
        "Every individual understands that real success depends on excellent preparation and diligent effort. Statistical analysis of a chrysanthemum reveals the complex phonological sequences and changing stress patterns found in a diverse neighbourhood."
    ]
    
    var paragraphLabels: [UILabel] = []
    var currentIndex: Int = 0
    
    // --- 🎤 AUDIO & SPEECH VARS ---
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // ✅ ADDED: Timer Variable
    var startTime: Date?
    
    // Data to hold the recording
    var recordedTranscript = ""
    var recordedSegments: [SFTranscriptionSegment] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupButtons()
        createParagraphLabels()
        highlightParagraph(at: currentIndex, animated: false)
        setupPermissions()
        setupWaveformUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Start recording as soon as the test screen appears
        try? startRecording()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopRecording() // Safety stop
    }
    
    func setupWaveformUI() {
        waveformStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        waveformBars.removeAll()
        
        for _ in 0..<numberOfBars {
            let bar = UIView()
            bar.backgroundColor = .buttonTheme // Or your preferred color
            bar.layer.cornerRadius = 6
            bar.translatesAutoresizingMaskIntoConstraints = false
            bar.heightAnchor.constraint(equalToConstant: 5).isActive = true
            
            waveformStackView.addArrangedSubview(bar)
            waveformBars.append(bar)
        }
    }
    
    // MARK: - Audio Logic
    
    func setupPermissions() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            // Handle auth status if needed
        }
    }
    
    func startRecording() throws {
        // 1. Cancel existing tasks
        recognitionTask?.cancel()
        self.recognitionTask = nil
        
        // 2. Setup Session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        let inputNode = audioEngine.inputNode
        
        // 3. Reset Engine to prevent crashes
        inputNode.removeTap(onBus: 0)
        
        // ✅ START TIMER
        startTime = Date()
        
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to create request") }
        recognitionRequest.shouldReportPartialResults = true
        
        // 4. Keep recording even if user pauses
        if #available(iOS 13, *) {
            recognitionRequest.requiresOnDeviceRecognition = true
        }
        
        // 5. Start Recognition Task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                let newText = result.bestTranscription.formattedString
                
                // ✅ CRITICAL FIX: SAFETY CHECK FOR LONG BLOCKS
                // Only update if the new text is NOT empty.
                // This prevents the engine from wiping your data when it detects a long silence (block).
                if !newText.isEmpty {
                    self.recordedTranscript = newText
                    self.recordedSegments = result.bestTranscription.segments
                    // print("📝 Test Live: \(self.recordedTranscript)") // Debug if needed
                }
            }
            if error != nil {
                self.stopRecording()
            }
        }
        
        // 6. Install Tap on Mic
        let recordingFormat = inputNode.outputFormat(forBus: 0)
//        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
//            self.recognitionRequest?.append(buffer)
//        }
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.recognitionRequest?.append(buffer)
            
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameLength = UInt32(buffer.frameLength)
            
            // Calculate RMS (Volume level)
            var sum: Float = 0
            for i in 0..<Int(frameLength) {
                sum += channelData[i] * channelData[i]
            }
            
            let rms = sqrt(sum / Float(frameLength))
            
            // ADJUST THIS: Sensitivity multiplier
            // If it's not moving, increase '20'. If it's always maxed, decrease it.
            let magnitude = Swift.max(0.1, Swift.min(1.0, rms * 40))
            
            DispatchQueue.main.async {
                self.updateWaveform(with: CGFloat(magnitude))
            }
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        print("🎤 Test Recording Started...")
    }
    func updateWaveform(with magnitude: CGFloat) {
        let maxHeight: CGFloat = 48.0
        
        for bar in waveformBars {
            let randomFactor = CGFloat.random(in: 0.8...1.2)
            let targetHeight = max(5, maxHeight * magnitude * randomFactor)
            
            if let heightConstraint = bar.constraints.first(where: { $0.firstAttribute == .height }) {
                // Remove the individual UIView.animate from here
                heightConstraint.constant = targetHeight
            }
        }
        
        // One single animation for all bars at once
        UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseOut, animations: {
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
    
    func stopRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            audioEngine.inputNode.removeTap(onBus: 0)
            
            // Wrap UI reset in Main thread + Animation
            DispatchQueue.main.async {
                UIView.animate(withDuration: 0.3) {
                    for bar in self.waveformBars {
                        if let height = bar.constraints.first(where: { $0.firstAttribute == .height }) {
                            height.constant = 5
                        }
                    }
                    self.view.layoutIfNeeded()
                }
            }
            print("🛑 Test Recording Stopped.")
        }
    }
    
    // MARK: - Navigation & Analysis
    
    func setupButtons() {
        updateButtonStates()
        continueButton.isEnabled = false
        continueButton.alpha = 0
        continueButton.isHidden = true
        bottomViewConstraint.constant = 0
    }

    @IBAction func nextButtonTapped(_ sender: UIButton) {
        if currentIndex < paragraphs.count - 1 {
            highlightParagraph(at: currentIndex + 1, animated: true)
        }
        
        // If we reached the last paragraph, show the "Submit" button
        if currentIndex == paragraphs.count - 1 {
            //self.bottomViewConstraint.constant = 60
            self.continueButton.isHidden = false
            self.continueButton.isEnabled = true
            
            UIView.animate(withDuration: 0.4) {
                self.view.layoutIfNeeded()
                self.continueButton.alpha = 1.0
            }
        }
    }
    
    @IBAction func previousButtonTapped(_ sender: UIButton) {
        if currentIndex > 0 {
            highlightParagraph(at: currentIndex - 1, animated: true)
        }
    }
    
    @IBAction func resetButtonTapped(_ sender: UIButton) {
        // 1. Reset Recording
        stopRecording()
        recordedTranscript = ""
        recordedSegments = []
        try? startRecording()
        
        // 2. Reset UI
        highlightParagraph(at: 0, animated: true)
        bottomViewConstraint.constant = 0
        continueButton.isEnabled = false
        continueButton.isHidden = true
        
        UIView.animate(withDuration: 0.4) {
            self.view.layoutIfNeeded()
            self.continueButton.alpha = 0
        }
    }
    
    // ✅ "Submit" Button Action
    @IBAction func continueButtonTapped(_ sender: UIButton) {
        // 1. Stop Recording
        stopRecording()
        
        // 2. ✅ Calculate Duration
        let duration = Date().timeIntervalSince(startTime ?? Date())
        
        // 3. Combine all paragraphs into one reference string
        let fullReferenceText = paragraphs.joined(separator: " ")
        
        // 4. Run Analysis (Added Duration Parameter)
        let jsonResult = StutterAnalyzer.analyze(
            reference: fullReferenceText,
            transcript: recordedTranscript,
            segments: recordedSegments,
            duration: duration
        )
        
        print("📊 Analysis Result: \(jsonResult)")
        
        // 5. Decode JSON
        guard let jsonData = jsonResult.data(using: .utf8),
              let report = try? JSONDecoder().decode(StutterJSONReport.self, from: jsonData) else {
            print("❌ Error decoding report")
            return
        }
        
        // 6. Navigate to Result Screen
        if let resultVC = storyboard?.instantiateViewController(withIdentifier: "LastOnboardingViewController") as? LastOnboardingViewController {
            resultVC.report = report // Pass data
            navigationController?.pushViewController(resultVC, animated: true)
        }
    }
    
    // MARK: - UI Logic (Standard)
    
    func createParagraphLabels() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        paragraphLabels.removeAll()
        
        for (index, paragraph) in paragraphs.enumerated() {
            let label = UILabel()
            label.text = paragraph
            label.numberOfLines = 0
            label.textAlignment = .left
            label.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
            label.textColor = UIColor.secondaryLabel
            label.alpha = 0.4
            label.tag = index
            stackView.addArrangedSubview(label)
            paragraphLabels.append(label)
        }
        
        let bottomSpacer = UIView()
        stackView.addArrangedSubview(bottomSpacer)
        bottomSpacer.translatesAutoresizingMaskIntoConstraints = false
        bottomSpacer.heightAnchor.constraint(equalTo: scrollView.heightAnchor, multiplier: 0.4).isActive = true
    }
    
    func highlightParagraph(at index: Int, animated: Bool) {
        guard index >= 0 && index < paragraphLabels.count else { return }
        let duration: TimeInterval = animated ? 0.4 : 0
        let label = self.paragraphLabels[index]
        let labelFrame = label.convert(label.bounds, to: self.scrollView)
        let centerOffset = labelFrame.midY - (self.scrollView.bounds.height / 2)
        let maxOffset = max(0, self.scrollView.contentSize.height - self.scrollView.bounds.height)
        let targetOffset = CGPoint(x: 0, y: min(max(0, centerOffset), maxOffset))
        
        UIView.animate(withDuration: duration, delay: 0, options: .curveEaseInOut, animations: {
            self.scrollView.contentOffset = targetOffset
            for (i, lbl) in self.paragraphLabels.enumerated() {
                if i == index {
                    lbl.textColor = .label; lbl.alpha = 1.0; lbl.font = .systemFont(ofSize: 18, weight: .semibold)
                } else if i < index {
                    lbl.textColor = .tertiaryLabel; lbl.alpha = 0.3; lbl.font = .systemFont(ofSize: 17, weight: .semibold)
                } else {
                    lbl.textColor = .secondaryLabel; lbl.alpha = 0.4; lbl.font = .systemFont(ofSize: 17, weight: .semibold)
                }
            }
        }, completion: nil)
        
        currentIndex = index
        updateButtonStates()
    }
    
    func updateButtonStates() {
        previousButton.isEnabled = currentIndex > 0
        nextButton.isEnabled = currentIndex < paragraphs.count
        previousButton.alpha = previousButton.isEnabled ? 1.0 : 0.5
        nextButton.alpha = nextButton.isEnabled ? 1.0 : 0.5
    }
}
