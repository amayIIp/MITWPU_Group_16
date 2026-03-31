import UIKit
import Speech
import AVFoundation

class TestViewController: UIViewController, SFSpeechRecognizerDelegate {

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var resetButton: UIButton!
    @IBOutlet weak var continueButton: UIButton!
    @IBOutlet weak var bottomViewConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var waveformView: BarWaveformView!
    // Defines how many bars fit on screen before scrolling. Adjust based on your UI width.
    private let maxWaveformBars = 150
    // MARK: - Waveform Variables
    private var waveformHistory: [CGFloat] = []
    private var smoothedMagnitude: Float = 0.0
    private var displayLink: CADisplayLink?
    // NEW: Timing controls for the horizontal scroll speed
    private var lastShiftTime: CFTimeInterval = 0
    // Change this to make it faster/slower. 0.08 means it adds ~12 bars per second.
    private let shiftInterval: CFTimeInterval = 0.04
    
    let paragraphs: [String] = [
        "Because everyone has a significant story to tell, Peter, a professional photographer, typically describes his most incredible, adventurous experiences. My grandfather, who is nearly ninety-three years old, often ponders those vibrant, green mountains while talking to anyone who will listen attentively.",
        "Although communication can be challenging, he persists in connecting with the people in his community through vivid, descriptive language. Critics frequently keep track of his complicated techniques because they require great concentration and persistent practice.",
        "Every individual understands that real success depends on excellent preparation and diligent effort. Statistical analysis of a chrysanthemum reveals the complex phonological sequences and changing stress patterns found in a diverse neighbourhood."
    ]
    
    var paragraphLabels: [UILabel] = []
    var currentIndex: Int = 0
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    var startTime: Date?
    
    var recordedTranscript = ""
    var recordedSegments: [SFTranscriptionSegment] = []

    private var tempAudioFile: AVAudioFile?
    private var tempAudioURL: URL?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupButtons()
        createParagraphLabels()
        highlightParagraph(at: currentIndex, animated: false)
        setupPermissions()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        try? startRecording()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopRecording()
    }
    
    func setupPermissions() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
        }
    }
    
    func updateWaveform(with magnitude: CGFloat) {
        // 1. Append the new real-time magnitude to our history
        waveformHistory.append(magnitude)
        
        // 2. Keep the array size manageable so it scrolls smoothly left-to-right
        if waveformHistory.count > maxWaveformBars {
            waveformHistory.removeFirst()
        }
        
        // 3. Feed the data to the custom view (it automatically triggers UI updates)
        waveformView.amplitudes = waveformHistory
    }
    
    func startRecording() throws {
        recognitionTask?.cancel()
        self.recognitionTask = nil
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        
        // ✅ START TIMER & RESET WAVEFORM STATE
        startTime = Date()
        waveformHistory.removeAll()
        smoothedMagnitude = 0.0
        
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to create request") }
        recognitionRequest.shouldReportPartialResults = true
        if #available(iOS 13, *) { recognitionRequest.requiresOnDeviceRecognition = true }
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                let newText = result.bestTranscription.formattedString
                if !newText.isEmpty {
                    self.recordedTranscript = newText
                    self.recordedSegments = result.bestTranscription.segments
                }
            }
            if error != nil { self.stopRecording() }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        let tempDir = FileManager.default.temporaryDirectory
        tempAudioURL = tempDir.appendingPathComponent("test_\(UUID().uuidString).wav")
        do {
            tempAudioFile = try AVAudioFile(forWriting: tempAudioURL!, settings: recordingFormat.settings)
        } catch {
            print("Error creating temp audio file: \(error)")
        }
        
        // MARK: - Optimized Audio Tap
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer, when) in
            guard let self = self else { return }
            self.recognitionRequest?.append(buffer)
            try? self.tempAudioFile?.write(from: buffer)
            
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameLength = UInt32(buffer.frameLength)
            
            var sum: Float = 0
            for i in 0..<Int(frameLength) { sum += channelData[i] * channelData[i] }
            
            let rms = sqrt(sum / Float(frameLength))
                    
            let rawMagnitude = rms * 12.0
            let filteredMagnitude = rawMagnitude < 0.03 ? 0.0 : rawMagnitude
            
            // Dispatch only the math update to the main thread to prevent data races
            DispatchQueue.main.async {
                if filteredMagnitude > self.smoothedMagnitude {
                    self.smoothedMagnitude = (self.smoothedMagnitude * 0.4) + (filteredMagnitude * 0.6)
                } else {
                    self.smoothedMagnitude = filteredMagnitude
                }
            }
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        // ✅ START THE UI REFRESH LOOP
        startDisplayLink()
        print("🎤 Test Recording Started...")
    }

    func stopRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            audioEngine.inputNode.removeTap(onBus: 0)
            tempAudioFile = nil
            
            // ✅ STOP THE UI REFRESH LOOP
            stopDisplayLink()
            
            DispatchQueue.main.async {
                // Smoothly flatten out the visual waveform
                self.waveformHistory = Array(repeating: 0.0, count: self.waveformHistory.count)
                self.waveformView.amplitudes = self.waveformHistory
            }
            print("🛑 Test Recording Stopped.")
        }
    }

    private func startDisplayLink() {
        stopDisplayLink()
        lastShiftTime = CACurrentMediaTime() // Reset the timer
        
        displayLink = CADisplayLink(target: self, selector: #selector(updateUIFromDisplayLink(_:)))
        
        if #available(iOS 15.0, *) {
            displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 60, preferred: 60)
        } else {
            displayLink?.preferredFramesPerSecond = 60
        }
        displayLink?.add(to: .main, forMode: .common)
    }
    
    @objc private func updateUIFromDisplayLink(_ displayLink: CADisplayLink) {
        let finalMagnitude = Swift.max(0.0, Swift.min(1.0, self.smoothedMagnitude))
        
        // 1. VERTICAL SMOOTHNESS (60fps)
        // Always update the very last item in the array.
        // This makes the active center bar dance fluidly without moving left.
        if waveformHistory.isEmpty {
            waveformHistory.append(CGFloat(finalMagnitude))
        } else {
            waveformHistory[waveformHistory.count - 1] = CGFloat(finalMagnitude)
        }
        
        // 2. HORIZONTAL SCROLLING (Slow & Relaxed)
        // Only commit a new bar and shift the graph to the left every 0.08 seconds.
        if displayLink.timestamp - lastShiftTime >= shiftInterval {
            waveformHistory.append(CGFloat(finalMagnitude))
            
            if waveformHistory.count > 150 {
                waveformHistory.removeFirst()
            }
            lastShiftTime = displayLink.timestamp // Reset timer for the next shift
        }
        
        // 3. Render
        waveformView.amplitudes = waveformHistory
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
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
        
        if currentIndex == paragraphs.count - 1 {
            self.continueButton.isHidden = false
            self.continueButton.isEnabled = true
            
            UIView.animate(withDuration: 0.4) {
                self.view.layoutIfNeeded()
                self.continueButton.alpha = 1.0
                self.nextButton.isEnabled = false
            }
        }
    }
    
    
    @IBAction func resetButtonTapped(_ sender: UIButton) {
        let alert = UIAlertController(
            title: "Restart Test?",
            message: "Are you sure you want to start over? Your current recording will be lost.",
            preferredStyle: .alert
        )
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        let restartAction = UIAlertAction(title: "Restart", style: .destructive) { [weak self] _ in
            self?.stopRecording()
            
            self?.navigationController?.popViewController(animated: true)
        }
        
        alert.addAction(cancelAction)
        alert.addAction(restartAction)
        
        present(alert, animated: true, completion: nil)
    }
    
    @IBAction func continueButtonTapped(_ sender: UIButton) {
        stopRecording()
        
        let duration = Date().timeIntervalSince(startTime ?? Date())
        let fullReferenceText = paragraphs.joined(separator: " ")
        
        let spinnerView = UIView(frame: view.bounds)
        spinnerView.backgroundColor = UIColor(white: 0, alpha: 0.5)
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.center = spinnerView.center
        spinner.startAnimating()
        spinnerView.addSubview(spinner)
        view.addSubview(spinnerView)
        
        Task {
            var finalTranscript = self.recordedTranscript
            if let url = self.tempAudioURL {
                do {
                    if let whisperResult = try await WhisperDetectionManager.shared.transcribe(audioURL: url) {
                        finalTranscript = whisperResult
                    }
                } catch {
                    print("WhisperKit failed, falling back to Apple Speech: \(error)")
                }
            }
            
            let jsonResult = StutterAnalyzer.analyze(
                reference: fullReferenceText,
                transcript: finalTranscript,
                segments: self.recordedSegments,
                duration: duration
            )
            
            print("📊 Analysis Result: \(jsonResult)")
            
            await MainActor.run {
                spinnerView.removeFromSuperview()
                guard let jsonData = jsonResult.data(using: .utf8),
                      let report = try? JSONDecoder().decode(StutterJSONReport.self, from: jsonData) else {
                    print("❌ Error decoding report")
                    return
                }
                let storyboard = UIStoryboard(name: "Onboarding", bundle: nil)
                if let resultVC = storyboard.instantiateViewController(withIdentifier: "LastOnboardingViewController") as? LastOnboardingViewController {
                    resultVC.report = report // Pass data
                    self.navigationController?.pushViewController(resultVC, animated: true)
                }
            }
        }
    }
    
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
        nextButton.isEnabled = currentIndex < paragraphs.count
        nextButton.alpha = nextButton.isEnabled ? 1.0 : 0.5
    }
}
