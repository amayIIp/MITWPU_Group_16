import UIKit
import Speech
import AVFoundation

class DetailViewController: UIViewController, SFSpeechRecognizerDelegate {
    
    @IBOutlet weak var textView: UITextView!
    
    var textToDisplay: String = ""
    var titleToDisplay: String = ""
    var exerciseDuration: Int = 0
    var startTime: Date?
    var initialDAFDelay: Double = 0.0

    
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
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let delayNode = AVAudioUnitDelay()
    private var selectedDAFDelay: Double = 0.0
    
    var recordedTranscript = ""
    var recordedSegments: [SFTranscriptionSegment] = []
    
    // NEW: Background state management for long paragraphs
    private var totalSegmentsCaptured: [SFTranscriptionSegment] = []


    override func viewDidLoad() {
        super.viewDidLoad()
        print("DEBUG: DetailVC viewDidLoad")
        print("DEBUG: textToDisplay: '\(textToDisplay.prefix(50))...'")
        
        if textView == nil {
            print("ERROR: textView is NIL in DetailVC! Check Storyboard Outlet connection.")
        } else {
            print("DEBUG: textView is connected.")
        }
        
        view.backgroundColor = UIColor(named: "bg")
        textView?.backgroundColor = UIColor(named: "bg") // Use optional chaining just in case
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
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    

    func setupTextView() {
        guard let textView = textView else { return }
        
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
    
//    private func presentWorkoutSheet() {
//        guard let sheetVC = storyboard?.instantiateViewController(withIdentifier: "ReadingControlsViewController") as? ReadingControlsViewController else { return }
//        sheetVC.delegate = self
//        self.sheetVC = sheetVC
//        sheetVC.isModalInPresentation = true
//        
//        if let sheet = sheetVC.sheetPresentationController {
//            sheet.detents = [
//                .custom(identifier: .init("quarter")) { $0.maximumDetentValue * 0.25 },
//                .custom(identifier: .init("half")) { $0.maximumDetentValue * 0.38 }
//            ]
//            sheet.selectedDetentIdentifier = .init("quarter")
//            sheet.prefersGrabberVisible = true
//            sheet.largestUndimmedDetentIdentifier = .init("quarter")
//            sheet.preferredCornerRadius = 20
//        }
//        present(sheetVC, animated: true)
//    }
    
    private func presentWorkoutSheet() {
        guard let sheetVC = storyboard?.instantiateViewController(withIdentifier: "ReadingControlsViewController") as? ReadingControlsViewController else { return }
        
        sheetVC.delegate = self
        self.sheetVC = sheetVC
        sheetVC.isModalInPresentation = true
        
        if let sheet = sheetVC.sheetPresentationController {
            sheet.delegate = self // Set the delegate to track manual dragging
            
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
        
        sheetVC.view.layer.cornerRadius = 20
        sheetVC.view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        sheetVC.view.clipsToBounds = true
        
        present(sheetVC, animated: true) {
            // Ensure initial state hides the Done button since we start at "quarter"
            sheetVC.toggleDoneButtonVisibility(isHidden: true)
        }
    }

    
    func setupPermissions() {
        SFSpeechRecognizer.requestAuthorization { _ in }
    }
    
    func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetoothA2DP, .defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch { print("Audio Session Setup Error: \(error)") }
    }
    
    func startRecording() {
        // Stop current task to clear internal buffers
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        
        // Start time only if it's a fresh start
        if startTime == nil { startTime = Date() }
        
        let format = inputNode.outputFormat(forBus: 0)
        
        // Setup DAF
        audioEngine.attach(delayNode)
        if selectedDAFDelay > 0 && areHeadphonesConnected() {
            delayNode.delayTime = selectedDAFDelay
            delayNode.wetDryMix = 100
        } else {
            delayNode.wetDryMix = 0
        }
        
        audioEngine.connect(inputNode, to: delayNode, format: format)
        audioEngine.connect(delayNode, to: audioEngine.mainMixerNode, format: format)
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            if let result = result {
                self.recordedTranscript = result.bestTranscription.formattedString
                self.recordedSegments = result.bestTranscription.segments
            }
            if error != nil { self.stopRecording() }
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { (buffer, _) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try? audioEngine.start()
    }
    
    func stopRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
    }
    
    func areHeadphonesConnected() -> Bool {
        let route = AVAudioSession.sharedInstance().currentRoute
        return route.outputs.contains { port in
            [.headphones, .bluetoothA2DP, .bluetoothHFP, .bluetoothLE].contains(port.portType)
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
        isPlaying ? pausePlayback() : startPlayback()
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
        animateSheet(to: .init("quarter")) // Automatically collapse on play
    }

    func pausePlayback() {
        isPlaying = false
        stopRecording()
        highlightTimer?.invalidate()
        highlightTimer = nil
        
        notifySheetOfStateChange()
        animateSheet(to: .init("half")) // Automatically expand on pause
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
        startTime = nil
        highlightBlock(at: -1, isFinalReset: true)
        textView.setContentOffset(.zero, animated: true)
        recordedTranscript = ""
        recordedSegments = []
        notifySheetOfStateChange()
    }
    
    private func animateSheet(to detentIdentifier: UISheetPresentationController.Detent.Identifier) {
        guard let sheet = sheetVC?.sheetPresentationController else { return }
        
        // Smoothly animate the detent change
        sheet.animateChanges {
            sheet.selectedDetentIdentifier = detentIdentifier
        }
        
        // Update the Done button visibility based on the new state
        let isExpanded = (detentIdentifier == .init("half"))
        sheetVC?.toggleDoneButtonVisibility(isHidden: !isExpanded)
    }
    
    private func notifySheetOfStateChange() {
        let finished = currentWordBlockIndex * wordsPerHighlight >= wordRanges.count
        sheetVC?.updatePlaybackState(isPlaying: isPlaying, hasFinished: finished)
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
            let endRange = wordRanges[min(endIndex - 1, wordRanges.count - 1)]
            let hRange = NSRange(location: startRange.location, length: endRange.location + endRange.length - startRange.location)
            
            mutableAttributedText.addAttributes(highlightAttributes, range: hRange)
            textView.attributedText = mutableAttributedText
            
            let rect = textView.layoutManager.boundingRect(forGlyphRange: endRange, in: textView.textContainer)
            let targetY = rect.minY - (textView.bounds.height / 2.0) + (rect.height / 2.0)
            let finalY = min(max(0, textView.contentSize.height - textView.bounds.height), max(0, targetY))
            textView.setContentOffset(CGPoint(x: 0, y: finalY), animated: true)
        }
    }
    
    func didTapOpenButton() {
        let duration = Date().timeIntervalSince(startTime ?? Date())
        
        // ACCURACY FIX: Pass the recorded data to the optimized analyzer
        let jsonResult = StutterAnalyzer.analyze(
            reference: textToDisplay,
            transcript: recordedTranscript,
            segments: recordedSegments,
            duration: duration
        )
        
        guard let jsonData = jsonResult.data(using: .utf8),
              let report = try? JSONDecoder().decode(StutterJSONReport.self, from: jsonData) else {
            return
        }

        LogManager.shared.updateStutterStats(letterCounts: report.letterAnalysis)
        
        guard let ResultVC = storyboard?.instantiateViewController(withIdentifier: "ReadingResultViewController") as? ReadingResultViewController else { return }
        ResultVC.report = report
        
        let ResultNav = UINavigationController(rootViewController: ResultVC)
        ResultNav.modalPresentationStyle = .fullScreen
        self.present(ResultNav, animated: true, completion: nil)
        
        logReadingActivity()
    }
    
    func logReadingActivity() {
        let duration = Date().timeIntervalSince(startTime ?? Date())
        self.exerciseDuration = Int(duration)
        LogManager.shared.addLog(exerciseName: titleToDisplay, source: .reading, exerciseDuration: self.exerciseDuration)
    }
}

extension DetailViewController: WorkoutSheetDelegate {
    func didTapPlayPause() { togglePlayPause() }
    func didTapDecreaseSpeed() { decreaseSpeed() }
    func didTapIncreaseSpeed() { increaseSpeed() }
    func didTapReset() { resetReading() }
    func didTapShowResult() {
        pausePlayback()
        self.dismiss(animated: true) { self.didTapOpenButton() }
    }
    
    func didUpdateDAFDelay(_ delay: Double) {
        self.selectedDAFDelay = delay
        if areHeadphonesConnected() {
            delayNode.delayTime = delay
            delayNode.wetDryMix = (delay > 0) ? 100 : 0
        } else {
            delayNode.wetDryMix = 0
        }
    }
}

extension DetailViewController: UISheetPresentationControllerDelegate {
    func sheetPresentationControllerDidChangeSelectedDetentIdentifier(_ sheetPresentationController: UISheetPresentationController) {
        
        // Determine if the sheet was dragged to the expanded "half" state
        let isExpanded = sheetPresentationController.selectedDetentIdentifier == .init("half")
        
        // 1. Update the Done button visibility based on the new size
        sheetVC?.toggleDoneButtonVisibility(isHidden: !isExpanded)
        
        // 2. Sync the playback state with the modal's physical position
        if isExpanded {
            // Modal was dragged UP: Pause the exercise if it's currently running
            if isPlaying {
                pausePlayback()
            }
        } else {
            // Modal was dragged DOWN: Resume the exercise if it's currently paused
            if !isPlaying {
                startPlayback()
            }
        }
    }
}
