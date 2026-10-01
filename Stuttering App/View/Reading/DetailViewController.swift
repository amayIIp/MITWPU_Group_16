import UIKit
import Speech
import AVFoundation

class DetailViewController: UIViewController, SFSpeechRecognizerDelegate {

    @IBOutlet weak var textView: UITextView!

    var textToDisplay: String = ""
    var titleToDisplay: String = ""
    var exerciseDuration: Int = 0
    var startTime: Date?
    var accumulatedDuration: TimeInterval = 0.0
    var initialDAFDelay: Double = 0.0
    private var currentPlaybackSpeed: Double = 1.0

    private let wordsPerHighlight = 3
    private var highlightDuration: TimeInterval = 1.7
    private let minDuration: TimeInterval = 0.3
    private let maxDuration: TimeInterval = 4.0
    private(set) var isPlaying = false
    // MARK: - Reading pace
    //
    // The highlight advances on a clock, continuously, and recognition only
    // *corrects* it. The previous design had that backwards: recognition drove
    // the highlight and the clock was a slow fallback, which meant every gap
    // in recognition stalled the highlight while the reader carried on. They
    // then had to stop and re-read the stuck word to get moving again — which
    // filled the transcript with repeats and collapsed the score.
    //
    // Silence from the recogniser is *not* evidence that the reader is silent.
    // On-device recognition batches, times out and drops words; treating that
    // as "the reader stopped" is what caused the stalling. So the clock always
    // moves unless recognition is actively telling us the reader is behind.

    /// Fractional word index of the highlight. Advances every tick.
    private var highlightPosition: Double = 0
    /// Last word index recognition has actually confirmed the reader reached.
    private var confirmedPosition = 0
    /// Painted word index, so the text view is only rebuilt when it changes.
    private var lastPaintedIndex = -1
    private var lastRecognitionResultAt = Date.distantPast
    private var lastPositionEvaluation = Date.distantPast
    private var readingTracker: ReadingPositionTracker?

    /// Reader's pace in words per second, estimated from their own progress.
    /// Seeded at roughly 105 wpm, which is what the old fixed timer used.
    private var paceWordsPerSecond: Double = 1.75
    private var paceSamples: [(time: Date, position: Int)] = []

    private let pacingTick: TimeInterval = 0.1
    /// Recomputing the position walks everything spoken so far, and
    /// recognition callbacks arrive far faster than a reader moves.
    private let positionEvaluationInterval: TimeInterval = 0.2
    /// A recognition result older than this means recognition is unavailable,
    /// not that the reader has gone quiet.
    private let recognitionStaleAfter: TimeInterval = 1.5
    /// How far the highlight may run ahead of confirmed reading before it
    /// waits — and only while recognition is live enough to be believed.
    private let maximumLead: Double = 4.0
    private let minimumPace: Double = 0.7   // ~42 wpm
    private let maximumPace: Double = 4.0   // ~240 wpm
    /// Window over which the reader's pace is measured.
    private let paceWindow: TimeInterval = 6.0
    /// How much silence counts as the reader having stopped.
    private let silenceHoldWindow: TimeInterval = 0.6
    /// Lead beyond which the highlight waits for a reader who has gone quiet.
    private let silentLead: Double = 1.5

    private var highlightTimer: Timer?
    private var sessionLimitTimer: Timer?
    private var chunkRotationTimer: Timer?
    /// Comfortably inside the on-device recogniser's own timeout.
    private let chunkRotationInterval: TimeInterval = 40
    private let maxRecordingDuration: TimeInterval = 15 * 60  // 15-minute hard cap
    private var wordRanges: [NSRange] = []
    private var defaultAttributes: [NSAttributedString.Key: Any] = [:]
    private var highlightAttributes: [NSAttributedString.Key: Any] = [:]
    private weak var sheetVC: ReadingControlsViewController?

    /// Optional for the same reason as in TestViewController: the initialiser
    /// returns nil where en-US recognition isn't available, and force-unwrapping
    /// it in a stored property crashed on controller creation.
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let delayNode = AVAudioUnitDelay()
    private var selectedDAFDelay: Double = 0.0

    // MARK: - Session capture state
    //
    // A reading session outlives any single recognition request: the user
    // pauses and resumes, and on-device `SFSpeechRecognizer` times out after
    // roughly a minute regardless. Each of those spans is a "chunk".
    //
    // Chunks are accumulated rather than replaced. `finalizedTranscriptChunks`
    // and `finalizedSegments` hold every completed chunk of the session;
    // `liveTranscript` / `liveSegments` hold the chunk currently in progress,
    // which is folded into the finalized arrays when it ends. Reading either
    // pair on its own gives you a fragment — always go through
    // `recordedTranscript` / `recordedSegments`.

    private var finalizedTranscriptChunks: [String] = []
    private var finalizedSegments: [SpeechSegment] = []

    private var liveTranscript = ""
    private var liveSegments: [SFTranscriptionSegment] = []

    /// Session-clock time at which the in-progress recognition request began.
    /// Apple's segment timestamps are relative to their own request, so this is
    /// what re-bases them onto one continuous clock.
    private var chunkStartOffset: TimeInterval = 0
    /// A chunk exists and has not yet been folded into the session totals.
    private var isChunkOpen = false
    /// `endAudio()` has been sent; the recogniser still owes us a final result.
    private var isChunkClosing = false

    /// Resumed when the in-progress chunk delivers its final result, so
    /// analysis can wait for the tail of the reading instead of racing it.
    private var finalResultContinuation: CheckedContinuation<Void, Never>?

    /// The whole session's transcript, in reading order.
    var recordedTranscript: String {
        (finalizedTranscriptChunks + [liveTranscript])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Every recognised word of the session, on a single session clock.
    var recordedSegments: [SpeechSegment] {
        finalizedSegments + liveSegments.map { SpeechSegment($0, sessionOffset: chunkStartOffset) }
    }

    // MARK: - Session audio file
    //
    // One file for the whole session, opened once and kept open across pauses,
    // recogniser restarts and route changes. Every incoming buffer is converted
    // to `sessionAudioFormat` first, so a mid-session format change cannot
    // desync the writer — and Whisper resamples to 16 kHz anyway, so this is
    // the format it actually consumes rather than six times more data.

    private let sessionAudioFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 16_000,
        channels: 1,
        interleaved: false
    )!
    private var audioConverter: AVAudioConverter?
    /// Loudness and spectrum every 10 ms, kept alongside the recording so
    /// blocks and prolongations can be measured rather than guessed at.
    private let envelopeBuilder = SpeechEnvelopeBuilder()
    private var tempAudioFile: AVAudioFile?
    private var tempAudioURL: URL?
    private let audioFileLock = NSLock()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor(named: "bg")
        textView?.backgroundColor = UIColor(named: "bg")

        self.selectedDAFDelay = self.initialDAFDelay
        audioEngine.attach(delayNode)

        setupTextView()
        setupPermissions()
        setupAudioSession()

        let format = audioEngine.inputNode.outputFormat(forBus: 0)
        audioEngine.connect(audioEngine.inputNode, to: delayNode, format: format)
        audioEngine.connect(delayNode, to: audioEngine.mainMixerNode, format: format)

        NotificationCenter.default.addObserver(self, selector: #selector(handleAudioRouteChange(_:)), name: AVAudioSession.routeChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAudioInterruption(_:)), name: AVAudioSession.interruptionNotification, object: nil)
    }

    /// A call, an alarm or Siri stops the audio engine underneath us. Only the
    /// route change was being watched, so an interruption left the screen
    /// looking like it was still recording while nothing reached the file —
    /// and the reader finished a passage that scored on silence.
    @objc private func handleAudioInterruption(_ note: Notification) {
        guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }

        switch type {
        case .began:
            stopRecording()
            let alert = UIAlertController(
                title: "Recording Stopped",
                message: "Something else needed the microphone, so the recording stopped. Your progress up to that point is kept.",
                preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)

        case .ended:
            break

        @unknown default:
            break
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        recognitionTask?.cancel()
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        try? AVAudioSession.sharedInstance()
            .setActive(false, options: .notifyOthersOnDeactivation)
        // Don't strand a session-sized recording in the temp directory if the
        // user backs out without ending the session.
        audioFileLock.lock()
        let url = tempAudioURL
        tempAudioFile = nil
        audioFileLock.unlock()
        if let url { try? FileManager.default.removeItem(at: url) }
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

    /// The speed control now sets the reader's *starting* pace. Recognition
    /// re-estimates from there, so the control is a preference rather than a
    /// rate the reader has to keep up with.
    func updatePlaybackSpeed() {
        highlightDuration = max(minDuration, min(maxDuration, 1.7 / currentPlaybackSpeed))
        applySpeedToPace()
    }

    private func applySpeedToPace() {
        paceWordsPerSecond = min(maximumPace, max(minimumPace,
                                                  Double(wordsPerHighlight) / highlightDuration))
        paceSamples.removeAll()
    }

    func setupTextView() {
        guard let textView = textView else { return }

        let baseFont = UIFont.preferredFont(forTextStyle: .title3)
        defaultAttributes = [.font: baseFont, .foregroundColor: UIColor.gray]
        highlightAttributes = [.font: baseFont, .foregroundColor: UIColor.black]

        let attributedString = NSMutableAttributedString(string: textToDisplay, attributes: defaultAttributes)
        self.wordRanges = calculateWordRanges(for: textToDisplay)
        // The tracker's word indices line up 1:1 with `wordRanges`, because
        // both come from a whitespace scan of the same string.
        self.readingTracker = ReadingPositionTracker(reference: textToDisplay)

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

    private var totalExerciseDuration: TimeInterval {
        var total = accumulatedDuration
        if isPlaying, let start = startTime {
            total += Date().timeIntervalSince(start)
        }
        return total
    }

    private func presentWorkoutSheet() {
        guard let sheetVC = storyboard?.instantiateViewController(withIdentifier: "ReadingControlsViewController") as? ReadingControlsViewController else { return }

        sheetVC.delegate = self
        self.sheetVC = sheetVC
        sheetVC.isModalInPresentation = true
        sheetVC.currentDAFDelay = self.selectedDAFDelay

        if let sheet = sheetVC.sheetPresentationController {
            sheet.delegate = self

            sheet.detents = [
                .custom(identifier: .init("quarter")) { context in 0.18 * context.maximumDetentValue },
                .custom(identifier: .init("half")) { context in 0.40 * context.maximumDetentValue }
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
        sheetVC.screenHeight = view.frame.height * 0.18

        present(sheetVC, animated: true) {
            sheetVC.toggleDoneButtonVisibility(isHidden: true)
        }
    }

    /// Asks for speech and microphone access, and says so when either is
    /// refused.
    ///
    /// The result used to be discarded (`{ _ in }`). A user who declined then
    /// read a whole passage to a microphone that was never listening and got a
    /// result screen full of zeros with nothing to explain it — and a reviewer
    /// declining once would see exactly that.
    func setupPermissions() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard let self else { return }
                guard status == .authorized else {
                    self.showPermissionAlert(
                        "Spasht needs Speech Recognition to follow along as you read.")
                    return
                }
                AVAudioApplication.requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        guard !granted else { return }
                        self.showPermissionAlert(
                            "Spasht needs the microphone to record your reading.")
                    }
                }
            }
        }
    }

    private func showPermissionAlert(_ message: String) {
        let alert = UIAlertController(title: "Permissions Required",
                                      message: message,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // `.measurement` disables the automatic gain control and noise
            // suppression iOS applies by default. Those are tuned to make
            // speech sound clean on a call: they compress dynamic range and
            // smear low-energy onsets, which is exactly the material stutter
            // analysis needs to keep. `.playAndRecord` is retained so DAF
            // playback still works.
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.allowBluetoothHFP, .allowBluetoothA2DP, .defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch { print("Audio Session Setup Error: \(error)") }
    }

    // MARK: - Recording

    /// Resumes capture for the session. Safe to call on every play/resume: the
    /// session audio file is opened once and kept, so resuming appends to the
    /// same recording instead of starting a new one.
    func startRecording() {
        if startTime == nil { startTime = Date() }

        openSessionAudioFileIfNeeded()
        applyDAFRouting()
        startEngine()
        startRecognitionChunk()
    }

    /// Pauses capture. The session audio file and everything transcribed so far
    /// are kept — only the engine and the in-flight recognition request stop.
    func stopRecording() {
        stopEngine()
        closeRecognitionChunk()
    }

    // ── Session audio file ────────────────────────────────────────────────

    private func openSessionAudioFileIfNeeded() {
        audioFileLock.lock()
        defer { audioFileLock.unlock() }
        guard tempAudioFile == nil else { return }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("reading_\(UUID().uuidString).wav")

        // Describe the file as plain interleaved 16-bit PCM. `settings` is the
        // on-disk format; `commonFormat`/`interleaved` describe the buffers we
        // hand to `write(from:)`, which AVAudioFile converts for us.
        let fileSettings: [String: Any] = [
            AVFormatIDKey:          kAudioFormatLinearPCM,
            AVSampleRateKey:        sessionAudioFormat.sampleRate,
            AVNumberOfChannelsKey:  Int(sessionAudioFormat.channelCount),
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey:  false,
            AVLinearPCMIsBigEndianKey: false
        ]

        do {
            tempAudioFile = try AVAudioFile(
                forWriting: url,
                settings: fileSettings,
                commonFormat: .pcmFormatInt16,
                interleaved: false
            )
            tempAudioURL = url
        } catch {
            print("Error creating session audio file: \(error)")
            tempAudioFile = nil
            tempAudioURL = nil
        }
    }

    /// Closes and deletes the session recording. Called when the session is
    /// reset, and once analysis has finished with the audio.
    private func discardSessionAudioFile() {
        audioFileLock.lock()
        let url = tempAudioURL
        tempAudioFile = nil
        tempAudioURL = nil
        audioConverter = nil
        audioFileLock.unlock()

        if let url { try? FileManager.default.removeItem(at: url) }
    }

    /// Converts a mic buffer to the session format, appends it to the file and
    /// folds it into the acoustic envelope.
    /// Runs on the audio tap's realtime thread.
    private func processCapturedBuffer(_ buffer: AVAudioPCMBuffer) {
        audioFileLock.lock()
        defer { audioFileLock.unlock() }

        if audioConverter?.inputFormat != buffer.format {
            audioConverter = AVAudioConverter(from: buffer.format, to: sessionAudioFormat)
        }
        guard let converter = audioConverter else { return }

        let ratio = sessionAudioFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1024
        guard let converted = AVAudioPCMBuffer(pcmFormat: sessionAudioFormat, frameCapacity: capacity) else { return }

        var didSupplyInput = false
        var conversionError: NSError?
        let status = converter.convert(to: converted, error: &conversionError) { _, inputStatus in
            if didSupplyInput {
                inputStatus.pointee = .noDataNow
                return nil
            }
            didSupplyInput = true
            inputStatus.pointee = .haveData
            return buffer
        }

        guard status != .error, converted.frameLength > 0 else {
            if let conversionError { print("Audio conversion failed: \(conversionError)") }
            return
        }

        // The envelope is the session's audio clock as well as its acoustics,
        // so it is fed even if the file write is unavailable.
        envelopeBuilder.append(converted)
        try? tempAudioFile?.write(from: converted)
    }

    // ── Audio engine ──────────────────────────────────────────────────────

    private func startEngine() {
        guard !audioEngine.isRunning else { return }

        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)

        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self = self else { return }
            // Read through the property each time: a recogniser restart swaps
            // the request out from under the tap without reinstalling it.
            self.recognitionRequest?.append(buffer)
            self.processCapturedBuffer(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("Audio engine failed to start: \(error)")
        }
    }

    private func stopEngine() {
        guard audioEngine.isRunning else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        releaseAudioSession()
    }

    /// Hands the audio session back.
    ///
    /// It was activated with `.duckOthers` and never deactivated, so after a
    /// reading session the orange microphone indicator stayed lit in the status
    /// bar and every other app's audio stayed ducked until Spasht was killed.
    private func releaseAudioSession() {
        do {
            try AVAudioSession.sharedInstance()
                .setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session failed to deactivate: \(error)")
        }
    }

    private func applyDAFRouting() {
        if selectedDAFDelay > 0 && areHeadphonesConnected() {
            delayNode.delayTime = selectedDAFDelay
            delayNode.wetDryMix = 100
            audioEngine.mainMixerNode.outputVolume = 1.0
        } else {
            delayNode.wetDryMix = 0
            audioEngine.mainMixerNode.outputVolume = 0.0
        }
    }

    // ── Recognition chunks ────────────────────────────────────────────────

    /// Opens a new recognition request on the session clock. The audio engine,
    /// the tap and the session file are untouched, so a chunk can start and end
    /// mid-recording without interrupting capture.
    private func startRecognitionChunk() {
        // Fold away anything still open — a paused chunk whose final result
        // never arrived, for instance — so no chunk is ever abandoned.
        finalizeRecognitionChunk()

        // No recogniser on this device (non-en-US region, dictation off). Audio
        // capture carries on regardless, so the session still records and
        // Whisper still has a file to transcribe; only the live highlight and
        // the Apple transcript are lost.
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            print("⚠️ Speech recognition unavailable — continuing with audio capture only")
            isChunkOpen = false
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        // Dictation rather than the default: the general hint applies heavier
        // language-model smoothing, which tidies away the repetitions this
        // whole feature exists to count.
        request.taskHint = .dictation
        request.addsPunctuation = false
        recognitionRequest = request

        // Anchor on captured audio, not wall-clock time. Segment timings and
        // the envelope then share one clock exactly, which is what lets a
        // silence between two words be looked up in the audio. Wall-clock time
        // drifts against the sample count and jumps at every pause.
        chunkStartOffset = envelopeBuilder.recordedDuration
        liveTranscript = ""
        liveSegments = []
        isChunkOpen = true
        isChunkClosing = false
        scheduleChunkRotation()

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            // Marshalled to main so capture state has a single owner: the
            // recogniser delivers on its own queue, while analysis reads this
            // state from the main actor.
            DispatchQueue.main.async {
                guard let self = self, self.recognitionRequest === request else { return }

                if let result = result {
                    self.liveTranscript = result.bestTranscription.formattedString
                    self.liveSegments   = result.bestTranscription.segments
                    // The reader's own voice paces the highlight.
                    self.refreshReadingPosition()
                    if result.isFinal { self.finalizeRecognitionChunk() }
                }

                if error != nil {
                    // On-device recognition times out after roughly a minute.
                    // Fold away what this chunk heard and open a new one — the
                    // engine, the tap and the session file keep running, so the
                    // reading is never interrupted. Stopping the engine here
                    // would silently end the recording mid-session while the
                    // UI carried on highlighting words.
                    //
                    // Reaching this path at all means the chunk died without a
                    // final result, so its word timings are whatever the last
                    // partial happened to carry. `scheduleChunkRotation` exists
                    // to make that rare.
                    self.finalizeRecognitionChunk()
                    if self.isPlaying { self.startRecognitionChunk() }
                }
            }
        }
    }

    /// Ends the current chunk cleanly before the recogniser times out.
    ///
    /// Word timings on *partial* results are unreliable — often zero — and a
    /// chunk that dies on timeout is finalised from its last partial, which
    /// leaves a whole minute of segments carrying no usable timing. Blocks and
    /// prolongations are measured from those timings, so such a chunk silently
    /// contributes nothing and the session looks fluent. Rotating early means
    /// every chunk ends with a final result and real timings.
    private func scheduleChunkRotation() {
        cancelChunkRotation()
        chunkRotationTimer = Timer.scheduledTimer(withTimeInterval: chunkRotationInterval,
                                                  repeats: false) { [weak self] _ in
            self?.rotateRecognitionChunk()
        }
    }

    private func cancelChunkRotation() {
        chunkRotationTimer?.invalidate()
        chunkRotationTimer = nil
    }

    private func rotateRecognitionChunk() {
        guard isPlaying, isChunkOpen, !isChunkClosing,
              finalResultContinuation == nil else { return }

        Task { @MainActor in
            closeRecognitionChunk()
            // Resolves on the final result, or forces the fold on timeout.
            await awaitFinalTranscript()
            guard isPlaying else { return }
            startRecognitionChunk()
        }
    }

    /// Signals the end of audio but leaves the chunk open, so the recogniser
    /// can still deliver the tail of what it heard. Pair with
    /// `awaitFinalTranscript()` before reading the transcript.
    private func closeRecognitionChunk() {
        guard isChunkOpen, !isChunkClosing else { return }
        isChunkClosing = true
        recognitionRequest?.endAudio()
    }

    /// Folds the in-progress chunk into the session totals and releases anyone
    /// waiting on the final result. Idempotent.
    private func finalizeRecognitionChunk() {
        guard isChunkOpen else {
            resumeFinalResultWaiter()
            return
        }
        isChunkOpen = false

        let trimmed = liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            finalizedTranscriptChunks.append(trimmed)
            finalizedSegments.append(contentsOf: liveSegments.map {
                SpeechSegment($0, sessionOffset: chunkStartOffset)
            })
        }

        liveTranscript = ""
        liveSegments = []

        if !isChunkClosing { recognitionRequest?.endAudio() }
        isChunkClosing = false
        cancelChunkRotation()

        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil

        resumeFinalResultWaiter()
    }

    private func resumeFinalResultWaiter() {
        finalResultContinuation?.resume()
        finalResultContinuation = nil
    }

    /// Waits for the recogniser to deliver its final result before analysis
    /// reads the transcript. `endAudio()` is asynchronous, so without this the
    /// last few words of a reading are routinely missing — and every segment
    /// analysed is a partial one, whose `confidence` is always zero.
    @MainActor
    private func awaitFinalTranscript(timeout: TimeInterval = 2.0) async {
        guard isChunkOpen else { return }

        let timeoutTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            guard !Task.isCancelled else { return }
            // The recogniser can go quiet after endAudio(). Keep whatever the
            // last partial gave us rather than blocking the result screen.
            self.finalizeRecognitionChunk()
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            finalResultContinuation = continuation
        }
        timeoutTask.cancel()
    }

    func areHeadphonesConnected() -> Bool {
        let route = AVAudioSession.sharedInstance().currentRoute
        return route.outputs.contains { port in
            [.headphones, .bluetoothA2DP, .bluetoothHFP, .bluetoothLE, .usbAudio].contains(port.portType)
        }
    }

    // MARK: - Session Limit Timer

    private func startSessionLimitTimer() {
        cancelSessionLimitTimer()
        // Remaining time = cap minus what the user has already accumulated
        let remaining = maxRecordingDuration - accumulatedDuration
        guard remaining > 0 else {
            // Already at or past limit — stop immediately
            handleSessionLimitReached()
            return
        }
        sessionLimitTimer = Timer.scheduledTimer(withTimeInterval: remaining, repeats: false) { [weak self] _ in
            self?.handleSessionLimitReached()
        }
    }

    private func cancelSessionLimitTimer() {
        sessionLimitTimer?.invalidate()
        sessionLimitTimer = nil
    }

    @objc private func handleSessionLimitReached() {
        guard isPlaying else { return }
        pausePlayback()

        // Show a non-blocking banner-style alert
        let alert = UIAlertController(
            title: "⏱ Session Limit Reached",
            message: "Reading sessions are capped at 15 minutes to protect device storage. Your session has been saved automatically.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "View Results", style: .default) { [weak self] _ in
            self?.didTapShowResult()
        })
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel))

        // Present on the sheet if visible, otherwise directly
        let presenter = sheetVC ?? self
        presenter.present(alert, animated: true)
    }

    /// Drives the highlight. Runs whether or not recognition is producing
    /// anything, because a reader who is being missed by the recogniser is
    /// still reading.
    private func startTimer() {
        highlightTimer?.invalidate()
        highlightTimer = Timer.scheduledTimer(withTimeInterval: pacingTick, repeats: true) { [weak self] _ in
            self?.advancePacing()
        }
    }

    private func advancePacing() {
        guard isPlaying, !wordRanges.isEmpty else { return }

        let recognitionIsLive = Date().timeIntervalSince(lastRecognitionResultAt) < recognitionStaleAfter
        let lead = highlightPosition - Double(confirmedPosition)

        // Two independent reasons to wait, and the microphone is the better
        // one. It knows whether the reader is making any sound at all, which
        // is what a block is; the recogniser going quiet says nothing about
        // the reader. Waiting on the microphone keeps the highlight within a
        // couple of words during a real block, while waiting on recognition
        // alone let it drift about six words past them.
        let readerIsSilent = envelopeBuilder.isSilent(forLast: silenceHoldWindow)
        let shouldWait = (readerIsSilent && lead >= silentLead)
                      || (recognitionIsLive && lead >= maximumLead)

        if !shouldWait {
            highlightPosition += paceWordsPerSecond * pacingTick
        }

        // The reader is past the highlight — catch up at once rather than
        // making them wait for the clock.
        if Double(confirmedPosition) > highlightPosition {
            highlightPosition = Double(confirmedPosition)
        }

        paintHighlight()
    }

    private func paintHighlight() {
        let wordIndex = min(Int(highlightPosition), wordRanges.count)
        guard wordIndex != lastPaintedIndex else { return }
        lastPaintedIndex = wordIndex

        if wordIndex >= wordRanges.count {
            highlightWords(from: max(0, wordRanges.count - wordsPerHighlight))
            pausePlayback()
            notifySheetOfStateChange()
        } else {
            highlightWords(from: wordIndex)
        }
    }

    /// Recomputes where the reader is from everything heard so far, and
    /// re-estimates their pace. Throttled: recognition callbacks arrive much
    /// faster than a reader moves.
    private func refreshReadingPosition() {
        lastRecognitionResultAt = Date()
        guard isPlaying, let tracker = readingTracker else { return }
        guard Date().timeIntervalSince(lastPositionEvaluation) >= positionEvaluationInterval else { return }
        lastPositionEvaluation = Date()

        let spoken = TextNormalizer.tokenize(recordedTranscript)
        guard !spoken.isEmpty else { return }

        let position = min(tracker.position(forSpoken: spoken), wordRanges.count)
        // Monotone: a recogniser revising its own partial results, or a reader
        // re-reading a line, must not drag the highlight back over covered text.
        guard position > confirmedPosition else { return }
        confirmedPosition = position
        updatePaceEstimate()
    }

    private func updatePaceEstimate() {
        let now = Date()
        paceSamples.append((now, confirmedPosition))
        paceSamples.removeAll { now.timeIntervalSince($0.time) > paceWindow }

        guard let oldest = paceSamples.first, paceSamples.count >= 2 else { return }
        let elapsed = now.timeIntervalSince(oldest.time)
        let words = Double(confirmedPosition - oldest.position)
        guard elapsed >= 1.5, words > 0 else { return }

        // Smoothed and clamped: one burst of recognition catching up should not
        // make the highlight sprint, and one block should not make it crawl.
        let observed = words / elapsed
        paceWordsPerSecond = min(maximumPace, max(minimumPace,
                                                  paceWordsPerSecond * 0.6 + observed * 0.4))
    }


    func togglePlayPause() {
        if isPlaying {
            pausePlayback()
        } else {
            startPlayback()
        }
    }

    func startPlayback() {
        // Finished last time? Start over.
        if Int(highlightPosition) >= wordRanges.count {
            highlightPosition = 0
            confirmedPosition = 0
            lastPaintedIndex = -1
            clearHighlight()
        }
        lastPositionEvaluation = .distantPast
        lastRecognitionResultAt = Date.distantPast
        paceSamples.removeAll()

        isPlaying = true
        startTime = Date()

        startRecording()
        startTimer()
        startSessionLimitTimer()
        paintHighlight()

        notifySheetOfStateChange()
        animateSheet(to: .init("quarter"))
    }

    func pausePlayback() {
        if let start = startTime {
            accumulatedDuration += Date().timeIntervalSince(start)
            startTime = nil
        }

        isPlaying = false
        stopRecording()
        highlightTimer?.invalidate()
        highlightTimer = nil
        cancelSessionLimitTimer()
        cancelChunkRotation()

        notifySheetOfStateChange()
        animateSheet(to: .init("half"))
    }

    func decreaseSpeed() {
        highlightDuration = max(minDuration, highlightDuration - 0.1)
        applySpeedToPace()
    }

    func increaseSpeed() {
        highlightDuration = min(maxDuration, highlightDuration + 0.1)
        applySpeedToPace()
    }

    func resetReading() {
        pausePlayback()  // also cancels sessionLimitTimer
        accumulatedDuration = 0.0
        startTime = nil
        highlightPosition = 0
        confirmedPosition = 0
        lastPaintedIndex = -1
        lastPositionEvaluation = .distantPast
        lastRecognitionResultAt = Date.distantPast
        paceSamples.removeAll()
        paceWordsPerSecond = Double(wordsPerHighlight) / highlightDuration

        clearHighlight()
        textView.setContentOffset(.zero, animated: true)

        // Discard the take completely. Leaving the audio file behind meant a
        // reset-then-end would transcribe the recording the user just threw away.
        finalizeRecognitionChunk()
        finalizedTranscriptChunks = []
        finalizedSegments = []
        liveTranscript = ""
        liveSegments = []
        chunkStartOffset = 0
        envelopeBuilder.reset()
        discardSessionAudioFile()

        sheetVC?.resetTimer()
        notifySheetOfStateChange()
    }

    private func animateSheet(to detentIdentifier: UISheetPresentationController.Detent.Identifier) {
        guard let sheet = sheetVC?.sheetPresentationController else { return }

        sheet.animateChanges {
            sheet.selectedDetentIdentifier = detentIdentifier
        }

        let isExpanded = (detentIdentifier == .init("half"))
        sheetVC?.toggleDoneButtonVisibility(isHidden: !isExpanded)
    }

    private func notifySheetOfStateChange() {
        let finished = Int(highlightPosition) >= wordRanges.count
        sheetVC?.updatePlaybackState(isPlaying: isPlaying, hasFinished: finished, currentTime: totalExerciseDuration)
    }

    private func clearHighlight() {
        guard !wordRanges.isEmpty else { return }
        let text = NSMutableAttributedString(attributedString: textView.attributedText)
        text.setAttributes(defaultAttributes, range: NSRange(location: 0, length: text.length))
        textView.attributedText = text
    }

    /// Highlights `wordsPerHighlight` words starting at a word index.
    ///
    /// Indexed by word rather than by block of three, because the reader's
    /// position is a word and rounding it to a block of three would put the
    /// highlight up to two words away from where they actually are.
    private func highlightWords(from startIndex: Int) {
        guard !wordRanges.isEmpty else { return }
        let mutableAttributedText = NSMutableAttributedString(attributedString: textView.attributedText)
        let fullRange = NSRange(location: 0, length: mutableAttributedText.length)
        mutableAttributedText.setAttributes(defaultAttributes, range: fullRange)

        let endIndex = min(startIndex + wordsPerHighlight, wordRanges.count)

        if startIndex >= 0, startIndex < wordRanges.count {
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

    /// Upper bounds on the "Analysing your reading" screen's two slow steps.
    private static let insightDeadline: TimeInterval = 8
    private static let whisperDeadline: TimeInterval = 45

    func didTapOpenButton() {
        let duration = totalExerciseDuration

        let loadingOverlay = WaveLoadingOverlay.show(in: view, message: "Analysing your reading")

        Task {
            // Step 0 — Let the recogniser deliver its final result. Without
            // this the tail of the reading is missing and every segment
            // analysed is a partial one, whose confidence is always zero.
            await self.awaitFinalTranscript()

            // Step 1 — Transcribe audio
            let (appleTranscript, segments, audioURL) = await MainActor.run {
                (self.recordedTranscript, self.recordedSegments, self.tempAudioURL)
            }
            let envelope = self.envelopeBuilder.makeEnvelope()

            // Apple's recogniser is the primary source. It is less normalised
            // than Whisper — which is trained to produce clean readable prose
            // and so collapses the repetitions being measured — and it ships
            // the word timings, so transcript and timings come from one engine.
            //
            // Whisper is the fallback for when Apple heard nothing at all. In
            // that case the timings are deliberately dropped: segment indices
            // from one recogniser cannot be matched against another's words,
            // and analysing them together produced flags with no relationship
            // to the transcript.
            var finalTranscript = appleTranscript
            var timedSegments = segments
            var acousticEnvelope: SpeechEnvelope? = envelope

            if appleTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let url = audioURL {
                // Bounded because transcribe() first waits for the 464 MB
                // model to finish loading, which on a first run can take far
                // longer than anyone will watch a spinner for.
                let whisperOutcome = await withDeadline(seconds: Self.whisperDeadline) { () -> Result<String?, Error> in
                    do { return .success(try await WhisperDetectionManager.shared.transcribe(audioURL: url)) }
                    catch { return .failure(error) }
                }
                do {
                    guard let whisperOutcome else {
                        throw NSError(domain: "DetailViewController", code: -1, userInfo: [
                            NSLocalizedDescriptionKey: "timed out after \(Int(Self.whisperDeadline))s"])
                    }
                    if let whisperResult = try whisperOutcome.get(),
                       !whisperResult.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        finalTranscript = whisperResult
                        timedSegments = []
                        // Without segment timings there is nothing to index the
                        // envelope against, so the acoustic pass is skipped too.
                        acousticEnvelope = nil
                        print("⚠️ Apple Speech returned nothing — using WhisperKit transcript (\(whisperResult.count) chars), timing and acoustic analysis skipped")
                    }
                } catch {
                    print("WhisperKit fallback failed: \(error)")
                }
            }

            // Step 2 — Analyze
            let referenceText = self.textToDisplay
            let jsonResult = await Task.detached(priority: .userInitiated) {
                return StutterAnalyzer.analyze(
                    reference: referenceText,
                    transcript: finalTranscript,
                    segments: timedSegments,
                    envelope: acousticEnvelope,
                    duration: duration
                )
            }.value

            guard let jsonData = jsonResult.data(using: .utf8),
                  let report = try? JSONDecoder().decode(StutterJSONReport.self, from: jsonData) else {
                await MainActor.run {
                    self.discardSessionAudioFile()
                    loadingOverlay.dismiss()
                }
                return
            }

            // Step 3 — Save stats while overlay is still visible. The audio has
            // served its purpose by now, so release the file rather than
            // leaving a session-sized WAV in the temp directory.
            await MainActor.run {
                self.discardSessionAudioFile()
                LogManager.shared.updateStutterStats(letterCounts: report.letterAnalysis)
            }

            // Step 4 — Pre-fetch insight so result screen is fully ready on first paint.
            // Bounded: this is one friendly sentence, and it used to hold
            // "Analysing your reading" up for as long as the on-device model
            // was busy. Past the deadline the rule-based sentence is used.
            BackgroundParagraphManager.shared.beginForegroundWork()
            let insightText = await withDeadline(seconds: Self.insightDeadline) {
                await InsightEngine.shared.sessionInsight(report: report)
            } ?? InsightEngine.shared.sessionInsightOffline(report: report)
            BackgroundParagraphManager.shared.endForegroundWork()

            // Step 5 — Everything ready: dismiss overlay, then present result
            await MainActor.run {
                loadingOverlay.dismiss {
                    // Using ReadingResultViewController2 (programmatic, no storyboard)
                    // Switch back to ReadingResultViewController if needed
                    let resultVC = ReadingResultViewController2()
                    resultVC.report = report
                    resultVC.preloadedInsight = insightText

                    let resultNav = UINavigationController(rootViewController: resultVC)
                    resultNav.modalPresentationStyle = .fullScreen
                    self.present(resultNav, animated: true)
                    self.logReadingActivity()
                }
            }
        }
    }

    func logReadingActivity() {
        self.exerciseDuration = Int(totalExerciseDuration)
        LogManager.shared.addLog(exerciseName: titleToDisplay, source: .reading, exerciseDuration: self.exerciseDuration)
    }

    @objc private func handleAudioRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

        print("🔊 [DetailViewController] Audio route changed. Reason: \(reasonValue)")

        if reason == .oldDeviceUnavailable || reason == .newDeviceAvailable {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let headphonesConnected = self.areHeadphonesConnected()
                print("🔊 [DetailViewController] Headphones connected: \(headphonesConnected)")

                self.applyDAFRouting()

                if self.isPlaying {
                    print("🔊 [DetailViewController] Re-initializing audio engine for new route...")
                    // Rewire for the new route without disturbing the session:
                    // the audio file stays open (incoming buffers are converted
                    // to the session format, so a format change is harmless)
                    // and the transcript so far is folded in rather than lost.
                    self.stopEngine()
                    self.finalizeRecognitionChunk()

                    let inputNode = self.audioEngine.inputNode
                    let format = inputNode.outputFormat(forBus: 0)
                    self.audioEngine.disconnectNodeInput(self.delayNode)
                    self.audioEngine.disconnectNodeInput(self.audioEngine.mainMixerNode)
                    self.audioEngine.connect(inputNode, to: self.delayNode, format: format)
                    self.audioEngine.connect(self.delayNode, to: self.audioEngine.mainMixerNode, format: format)

                    self.startEngine()
                    self.startRecognitionChunk()
                }
            }
        }
    }
}

extension DetailViewController: WorkoutSheetDelegate {
    func didTapPlayPause() { togglePlayPause() }

    func didChangeSpeed(_ speed: Double) {
            currentPlaybackSpeed = speed
            updatePlaybackSpeed()
        }

    func didTapReset() {
        resetReading()
    }

    func didTapShowResult() {
        guard totalExerciseDuration >= 5 else {
            let alert = UIAlertController(
                title: "Session Too Short",
                message: "Please read for at least a few seconds so we can analyse your speech.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            sheetVC?.present(alert, animated: true)
            return
        }
        pausePlayback()
        self.dismiss(animated: true) { self.didTapOpenButton() }
    }

    func didUpdateDAFDelay(_ delay: Double) {
        self.selectedDAFDelay = delay
        applyDAFRouting()
    }
}

extension DetailViewController: UISheetPresentationControllerDelegate {
    func sheetPresentationControllerDidChangeSelectedDetentIdentifier(_ sheetPresentationController: UISheetPresentationController) {

        let isExpanded = sheetPresentationController.selectedDetentIdentifier == .init("half")
        sheetVC?.toggleDoneButtonVisibility(isHidden: !isExpanded)

        // Dragging the sheet is a layout gesture, not a transport control. It
        // used to pause and resume recording, which restarted the recogniser
        // mid-reading — so an ordinary grab of the sheet handle silently
        // truncated the session. Only the play/pause button changes playback.
    }
}
