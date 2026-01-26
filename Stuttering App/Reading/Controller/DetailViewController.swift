import UIKit
import Speech
import AVFoundation

class DetailViewController: UIViewController, SFSpeechRecognizerDelegate {
    
    @IBOutlet weak var textView: UITextView!
    
    var textToDisplay: String = ""
    var titleToDisplay: String = ""
    var exerciseDuration: Int = 0
    var startTime: Date?
    

    private let wordsPerHighlight = 3
    private var highlightDuration: TimeInterval = 1.7
    private let minDuration: TimeInterval = 0.3
    private let maxDuration: TimeInterval = 4.0
    private(set) var isPlaying = false
    private var currentWordBlockIndex = 0
    private var highlightTimer: Timer?
    private var wordRanges: [NSRange] = []
    private var defaultAttributes: [NSAttributedString.Key: Any] = [:]
    private var highlightAttributes: [NSAttributedString.Key: Any] = [:]
    private weak var sheetVC: ReadingControlsViewController?
    
    // --- AUDIO & SPEECH VARS ---
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // DAF Node
    private let delayNode = AVAudioUnitDelay()
    private var selectedDAFDelay: Double = 0.0
    
    // Recording Data
    var recordedTranscript = ""
    var recordedSegments: [SFTranscriptionSegment] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "bg")
        textView.backgroundColor = UIColor(named: "bg")
        setupTextView()
        setupPermissions()
        setupAudioSession()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presentWorkoutSheet()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isPlaying { pausePlayback() }
        navigationController?.setNavigationBarHidden(false, animated: false)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    private func setupTextView() {
        let baseFont = UIFont.systemFont(ofSize: 18, weight: .semibold)
        defaultAttributes = [.font: baseFont, .foregroundColor: UIColor.gray]
        highlightAttributes = [.font: baseFont, .foregroundColor: UIColor.black]
        
        let attributedString = NSMutableAttributedString(string: textToDisplay, attributes: defaultAttributes)
        self.wordRanges = calculateWordRanges(for: textToDisplay)
        
        textView.attributedText = attributedString
        textView.isEditable = false
        textView.textAlignment = .left
        textView.layoutManager.allowsNonContiguousLayout = true
    }
    
    private func calculateWordRanges(for text: String) -> [NSRange] {
        var ranges: [NSRange] = []
        let nsText = text as NSString
        let regex = try? NSRegularExpression(pattern: "\\S+")
        regex?.enumerateMatches(in: text, options: [], range: NSRange(location: 0, length: nsText.length)) { (match, _, _) in
            if let range = match?.range { ranges.append(range) }
        }
        return ranges
    }
    
    private func presentWorkoutSheet() {
        guard let sheetVC = storyboard?.instantiateViewController(withIdentifier: "ReadingControlsViewController") as? ReadingControlsViewController else { return }
        
        sheetVC.delegate = self// Set the delegate so the sheet can call back to us
        self.sheetVC = sheetVC
        
        sheetVC.isModalInPresentation = true
        
        if let sheet = sheetVC.sheetPresentationController {
            sheet.detents = [
                .custom(identifier: .init("quarter")) { context in
                    0.25 * context.maximumDetentValue
                },
                .custom(identifier: .init("half")) { context in
                    0.38 * context.maximumDetentValue
                }
            ]
            sheet.selectedDetentIdentifier = .init("quarter")
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            sheet.largestUndimmedDetentIdentifier = .init("quarter")
            
            sheet.preferredCornerRadius = 20
        }
        
        // Setting view's corner radius
        sheetVC.view.layer.cornerRadius = 20
        sheetVC.view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        sheetVC.view.clipsToBounds = true
        
        present(sheetVC, animated: true)
    }
    
    func setupPermissions() {
        SFSpeechRecognizer.requestAuthorization { authStatus in }
    }
    
    func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetoothA2DP, .defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch { print("Audio Session Setup Error: \(error)") }
    }
    
    func startRecording() {
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        let inputNode = audioEngine.inputNode
        audioEngine.stop()
        inputNode.removeTap(onBus: 0)
        audioEngine.reset()
        audioEngine.detach(delayNode)
        
        startTime = Date()
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        if #available(iOS 13, *) {
            if speechRecognizer.supportsOnDeviceRecognition {
                recognitionRequest?.requiresOnDeviceRecognition = true
            }
        }
        
        let format = inputNode.outputFormat(forBus: 0)
        audioEngine.attach(delayNode)
        
        if selectedDAFDelay > 0 && areHeadphonesConnected() {
            delayNode.delayTime = selectedDAFDelay
            delayNode.feedback = 0
            delayNode.wetDryMix = 100
            print("DAF STARTED: \(selectedDAFDelay)s")
        } else {
            delayNode.delayTime = 0.1
            delayNode.feedback = 0
            delayNode.wetDryMix = 0
            print("DAF STARTED: OFF (Mix 0)")
        }
        
        audioEngine.connect(inputNode, to: delayNode, format: format)
        audioEngine.connect(delayNode, to: audioEngine.mainMixerNode, format: format)
        
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to create request") }
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                let newText = result.bestTranscription.formattedString
                
                if !newText.isEmpty {
                    self.recordedTranscript = newText
                    self.recordedSegments = result.bestTranscription.segments
                    
                    print("Live: \(self.recordedTranscript)")
                }
            }
            if error != nil { self.stopRecording() }
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { (buffer, when) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
            print("Engine Started")
        } catch { print("Engine Start Error: \(error)") }
    }
    
    func stopRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.detach(delayNode)
        }
    }
    
    func areHeadphonesConnected() -> Bool {
        let route = AVAudioSession.sharedInstance().currentRoute
        return route.outputs.contains { port in
            return port.portType == .headphones || port.portType == .bluetoothA2DP || port.portType == .bluetoothHFP || port.portType == .bluetoothLE
        }
    }
    
    private func startTimer() {
        highlightTimer?.invalidate()
        highlightTimer = Timer.scheduledTimer(withTimeInterval: highlightDuration, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.highlightBlock(at: self.currentWordBlockIndex)
            self.currentWordBlockIndex += 1
            if self.currentWordBlockIndex * self.wordsPerHighlight >= self.wordRanges.count {
                self.pausePlayback()
                self.highlightBlock(at: self.currentWordBlockIndex - 1, isFinalReset: true)
                self.notifySheetOfStateChange()
            }
        }
    }
    
    func togglePlayPause() {
        if isPlaying { pausePlayback() } else { startPlayback() }
    }
    
    func startPlayback() {
        if currentWordBlockIndex * wordsPerHighlight >= wordRanges.count {
            currentWordBlockIndex = 0
            highlightBlock(at: -1, isFinalReset: true)
        }
        isPlaying = true
        startRecording()
        startTimer()
        highlightBlock(at: currentWordBlockIndex)
        currentWordBlockIndex += 1
        notifySheetOfStateChange()
    }
    
    func pausePlayback() {
        isPlaying = false
        stopRecording()
        highlightTimer?.invalidate()
        highlightTimer = nil
        notifySheetOfStateChange()
    }
    
    func decreaseSpeed() {
        highlightDuration = max(minDuration, highlightDuration - 0.1)
        if isPlaying { startTimer() }
    }
    
    func increaseSpeed() {
        highlightDuration = min(maxDuration, highlightDuration + 0.1)
        if isPlaying { startTimer() }
    }
    
    func resetReading() {
        pausePlayback()
        currentWordBlockIndex = 0
        highlightBlock(at: -1, isFinalReset: true)
        textView.setContentOffset(.zero, animated: true)
        recordedTranscript = ""
        recordedSegments = []
        notifySheetOfStateChange()
    }
    
    private func notifySheetOfStateChange() {
        let hasFinished = currentWordBlockIndex * wordsPerHighlight >= wordRanges.count
        sheetVC?.updatePlaybackState(isPlaying: isPlaying, hasFinished: hasFinished)
    }
    
    private func highlightBlock(at blockIndex: Int, isFinalReset: Bool = false) {
        guard !wordRanges.isEmpty else { return }
        let mutableAttributedText = NSMutableAttributedString(attributedString: textView.attributedText)
        let fullRange = NSRange(location: 0, length: mutableAttributedText.length)
        mutableAttributedText.setAttributes(defaultAttributes, range: fullRange)
        
        if isFinalReset {
            textView.attributedText = mutableAttributedText
            return
        }
        
        let startIndex = blockIndex * wordsPerHighlight
        let endIndex = min(startIndex + wordsPerHighlight, wordRanges.count)
        
        if startIndex < wordRanges.count {
            let startRange = wordRanges[startIndex]
            let endRangeIndex = min(endIndex - 1, wordRanges.count - 1)
            let endRange = wordRanges[endRangeIndex]
            
            let highlightLocation = startRange.location
            let highlightLength = endRange.location + endRange.length - startRange.location
            let highlightRange = NSRange(location: highlightLocation, length: highlightLength)
            
            mutableAttributedText.addAttributes(highlightAttributes, range: highlightRange)
            textView.attributedText = mutableAttributedText
            
            let rect = textView.layoutManager.boundingRect(forGlyphRange: endRange, in: textView.textContainer)
            let targetY = rect.minY - (textView.bounds.height / 2.0) + (rect.height / 2.0)
            let maxScrollY = max(0, textView.contentSize.height - textView.bounds.height)
            let finalY = min(maxScrollY, max(0, targetY))
            textView.setContentOffset(CGPoint(x: 0, y: finalY), animated: true)
        }
    }
    
    func didTapOpenButton() {
        let duration = Date().timeIntervalSince(startTime ?? Date())
        
        let jsonResult = StutterAnalyzer.analyze(
            reference: textToDisplay,
            transcript: recordedTranscript,
            segments: recordedSegments,
            duration: duration
        )
        print("\nJSON RESULT:\n\(jsonResult)\n")
        
        guard let jsonData = jsonResult.data(using: .utf8),
              let report = try? JSONDecoder().decode(StutterJSONReport.self, from: jsonData) else {
            print("Error decoding result")
            return
        }

        guard let ResultVC = storyboard?.instantiateViewController(withIdentifier: "ReadingResultViewController") as? ReadingResultViewController else { return }
        ResultVC.report = report
        
        let ResultNav = UINavigationController(rootViewController: ResultVC)
        ResultNav.modalPresentationStyle = .fullScreen
        self.present(ResultNav, animated: true, completion: nil)
        
        logReadingActivity()
    }
    
    func logReadingActivity() {
//        if let duration = ExerciseDataManager.shared.getDurationString(for: titleToDisplay) {
//            self.exerciseDuration = duration
        let duration = Date().timeIntervalSince(startTime ?? Date())
        self.exerciseDuration = Int(duration)
        
        LogManager.shared.addLog(exerciseName: titleToDisplay, source: .reading, exerciseDuration: self.exerciseDuration)
        print("Reading activity logged.")
    }
}

extension DetailViewController: WorkoutSheetDelegate {
    func didTapPlayPause() { togglePlayPause() }
    func didTapDecreaseSpeed() { decreaseSpeed() }
    func didTapIncreaseSpeed() { increaseSpeed() }
    func didTapReset() { resetReading() }
    
    func didTapShowResult() {
        pausePlayback()
        self.dismiss(animated: true, completion: nil)
        didTapOpenButton()
    }
    
    func didUpdateDAFDelay(_ delay: Double) {
        self.selectedDAFDelay = delay
        
        if areHeadphonesConnected() {
            if delay > 0 {
                delayNode.delayTime = delay
                delayNode.wetDryMix = 100
                print("Live Update: DAF \(delay)s")
            } else {
                delayNode.wetDryMix = 0
                print("Live Update: DAF OFF")
            }
        } else {
            delayNode.wetDryMix = 0
            print("Live Update: Ignored (No Headphones)")
        }
    }
}
