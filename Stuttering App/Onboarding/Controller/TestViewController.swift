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
    
    // Data to hold the recording
    var recordedTranscript = ""
    var recordedSegments: [SFTranscriptionSegment] = []
    
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
    
    func startRecording() throws {
        recognitionTask?.cancel()
        self.recognitionTask = nil
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        let inputNode = audioEngine.inputNode
        
        inputNode.removeTap(onBus: 0)
        
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to create request") }
        recognitionRequest.shouldReportPartialResults = true
        
        if #available(iOS 13, *) {
            recognitionRequest.requiresOnDeviceRecognition = true
        }
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                self.recordedTranscript = result.bestTranscription.formattedString
                self.recordedSegments = result.bestTranscription.segments
                // print("Test Live: \(self.recordedTranscript)")
            }
            if error != nil {
                self.stopRecording()
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        print("Test Recording Started...")
    }
    
    func stopRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            audioEngine.inputNode.removeTap(onBus: 0)
            print("Test Recording Stopped.")
        }
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
            }
        }
    }
    
    @IBAction func previousButtonTapped(_ sender: UIButton) {
        if currentIndex > 0 {
            highlightParagraph(at: currentIndex - 1, animated: true)
        }
    }
    
    @IBAction func resetButtonTapped(_ sender: UIButton) {
        stopRecording()
        recordedTranscript = ""
        recordedSegments = []
        try? startRecording()
        
        highlightParagraph(at: 0, animated: true)
        bottomViewConstraint.constant = 0
        continueButton.isEnabled = false
        continueButton.isHidden = true
        
        UIView.animate(withDuration: 0.4) {
            self.view.layoutIfNeeded()
            self.continueButton.alpha = 0
        }
    }
    
    @IBAction func continueButtonTapped(_ sender: UIButton) {
        stopRecording()
        let fullReferenceText = paragraphs.joined(separator: " ")
        let jsonResult = StutterAnalyzer.analyze(reference: fullReferenceText, transcript: recordedTranscript, segments: recordedSegments, duration: 1)
        
        print("Analysis Result: \(jsonResult)")
        
        guard let jsonData = jsonResult.data(using: .utf8),
              let report = try? JSONDecoder().decode(StutterJSONReport.self, from: jsonData) else {
            print("Error decoding report")
            return
        }
        
        if let resultVC = storyboard?.instantiateViewController(withIdentifier: "LastOnboardingViewController") as? LastOnboardingViewController {
            resultVC.report = report // Pass data
            navigationController?.pushViewController(resultVC, animated: true)
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
        previousButton.isEnabled = currentIndex > 0
        nextButton.isEnabled = currentIndex < paragraphs.count
        previousButton.alpha = previousButton.isEnabled ? 1.0 : 0.5
        nextButton.alpha = nextButton.isEnabled ? 1.0 : 0.5
    }
}
