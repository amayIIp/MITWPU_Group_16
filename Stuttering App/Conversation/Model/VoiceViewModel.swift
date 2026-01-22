// VoiceViewModel.swift - UPDATED

import UIKit
import AVFoundation
import Speech
import FoundationModels

protocol VoiceViewModelDelegate: AnyObject {
    func didUpdateState(_ state: VoiceViewModel.VoiceState)
    func didUpdateTranscript(_ text: String, isUser: Bool)
    func didEncounterError(_ message: String)
    func addMessageToConversation(speaker: String, text: String)
}

class VoiceViewModel: NSObject, AVSpeechSynthesizerDelegate {

    enum VoiceState {
        case idle, speaking, listening, thinking
        
        var isActive: Bool {
            return self != .idle
        }
    }
    
    weak var delegate: VoiceViewModelDelegate?
    private(set) var state: VoiceState = .idle {
        didSet {
            delegate?.didUpdateState(state)
            print("State changed: \(state)")
        }
    }
    
    private var session: LanguageModelSession?
    private let synthesizer = AVSpeechSynthesizer()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // Data
    private var currentBufferText: String = ""
    private var conversationHistory: [(speaker: String, text: String)] = []
    
    // STUTTER DETECTION DATA
    private var allUserSegments: [SFTranscriptionSegment] = []
    private var fullUserTranscript: String = ""
    private var conversationStartTime: Date?
    
    // Silence detection for auto-stop
    private var silenceTimer: Timer?
    private let silenceThreshold: TimeInterval = 2.5
    private var hasDetectedSpeech = false // 🆕 Track if ANY speech detected
    
    override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
    }
    
    var isConversationActive: Bool {
        return state.isActive
    }
    
    var hasConversationHistory: Bool {
        return !conversationHistory.isEmpty
    }
    
    var isModelReady: Bool {
        return session != nil
    }
    
    func getTotalWordCount() -> Int {
        return conversationHistory
            .filter { $0.speaker == "User" }
            .map { $0.text.split(separator: " ").count }
            .reduce(0, +)
    }
    
    func getStutterAnalysisJSON() -> String {
        guard !fullUserTranscript.isEmpty else {
            return """
            {
              "fluencyScore": 0,
              "duration": "0 sec",
              "stutteredWords": [],
              "blocks": [],
              "breakdown": { "repetition": [], "prolongation": [], "blocks": 0 },
              "percentages": { "repetition": 0, "prolongation": 0, "blocks": 0, "correct": 0 },
              "letterAnalysis": {}
            }
            """
        }
        
        let duration = conversationStartTime.map { Date().timeIntervalSince($0) } ?? 0
        
        print("Analyzing stutter data:")
        print("   - Full transcript: \(fullUserTranscript)")
        print("   - Total segments: \(allUserSegments.count)")
        print("   - Duration: \(duration)s")
        
        return StutterAnalyzer.analyze(
            reference: fullUserTranscript,
            transcript: fullUserTranscript,
            segments: allUserSegments,
            duration: duration
        )
    }
    
    func stopSession() {
        print("Stopping voice session...")
        
        silenceTimer?.invalidate()
        silenceTimer = nil
        
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        stopListening()
        
        state = .idle
        currentBufferText = ""
        
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            print("Audio session deactivated")
        } catch {
            print("Error deactivating audio session: \(error)")
        }
    }
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // Updated options to suppress deprecation warning and ensure modern routing behavior
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            print("Audio session configured successfully")
        } catch {
            print("Audio Session Error: \(error)")
            // Updated error handling for the pitch
            delegate?.didEncounterError("Unable to initialize audio configuration. Please verify your device settings.")
        }
    }
    
    @MainActor
    func prepareModel() async {
        let model = SystemLanguageModel.default
        let personaInstructions = """
        You are a warm, supportive conversation partner helping someone practice speaking. 
        Keep responses very short (1-2 sentences maximum). 
        Be encouraging and natural. 
        Never correct grammar or pronunciation - just have a friendly conversation.
        Ask simple, open-ended questions to keep the conversation flowing.
        """
        
        if model.availability == .available {
            self.session = LanguageModelSession(model: model, instructions: personaInstructions)
            print("AI Model ready")
        } else {
            print("Model unavailable: \(model.availability)")
            delegate?.didEncounterError("AI model is not available on this device.")
        }
    }
    
    func startConversation() {
        guard session != nil else {
            delegate?.didEncounterError("AI is not ready yet")
            return
        }
        
        conversationStartTime = Date()
        speak("Hi there! I'm ready to chat. How are you doing today?")
    }
    
    func speak(_ text: String) {
        guard !text.isEmpty else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.stopListening()
            self.state = .speaking
            
            self.conversationHistory.append((speaker: "AI", text: text))
            self.delegate?.addMessageToConversation(speaker: "AI", text: text)
            
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
            utterance.pitchMultiplier = 1.0
            utterance.volume = 1.0
            
            self.synthesizer.speak(utterance)
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self, self.state == .speaking else { return }
            self.startListening()
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        print("Speech was cancelled")
        if state == .speaking {
            state = .idle
        }
    }
        
    func startListening() {
        guard !audioEngine.isRunning else {
            print("Audio engine already running")
            return
        }
        
        SFSpeechRecognizer.requestAuthorization { status in
            if status != .authorized {
                DispatchQueue.main.async {
                    self.delegate?.didEncounterError("Microphone access denied")
                }
            }
        }
        
        state = .listening
        currentBufferText = ""
        hasDetectedSpeech = false
        delegate?.didUpdateTranscript("Listening...", isUser: true)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let req = recognitionRequest else { return }
        req.shouldReportPartialResults = true
        req.requiresOnDeviceRecognition = false
        
        let inputNode = audioEngine.inputNode
        recognitionTask = speechRecognizer?.recognitionTask(with: req) { [weak self] result, error in
            guard let self = self else { return }
            
            if let res = result {
                let newText = res.bestTranscription.formattedString
                
                if !newText.trimmingCharacters(in: .whitespaces).isEmpty {
                    if !self.hasDetectedSpeech {
                        self.hasDetectedSpeech = true
                        print("Speech detected: '\(newText)'")
                    }
                    
                    self.currentBufferText = newText
                    self.delegate?.didUpdateTranscript(self.currentBufferText, isUser: true)
                    
                    // COLLECT SEGMENTS FOR STUTTER DETECTION
                    if !res.bestTranscription.segments.isEmpty {
                        self.allUserSegments.append(contentsOf: res.bestTranscription.segments)
                        print("Collected \(res.bestTranscription.segments.count) segments")
                    }
                    
                    // Only reset timer if we have speech
                    self.resetSilenceTimer()
                }
                
                if res.isFinal {
                    self.handleSpeechComplete()
                }
            }
            
            if let error = error {
                let nsError = error as NSError
                
                // IGNORE "No speech detected" errors - they're normal
                if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1110 {
                    print("Waiting for speech input...")
                    return // Don't stop listening
                }
                
                // Ignore cancellation errors (code 301)
                if nsError.domain == "kLSRErrorDomain" && nsError.code == 301 {
                    print("Recognition was canceled (expected)")
                } else {
                    print("Recognition error: \(error)")
                    self.stopListening()
                }
            }
        }
        
        let format = inputNode.outputFormat(forBus: 0)
        
        guard format.sampleRate > 0 && format.channelCount > 0 else {
            print("Invalid audio format")
            delegate?.didEncounterError("Microphone format error")
            return
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak req] buffer, _ in
            guard buffer.frameLength > 0 else { return }
            req?.append(buffer)
        }
        
        do {
            audioEngine.prepare()
            try audioEngine.start()
            print("Audio engine started - waiting for speech...")
            // DON'T start timer until speech is detected
        } catch {
            print("Audio engine start error: \(error)")
            delegate?.didEncounterError("Microphone failed to start")
        }
    }
    
    func stopListening() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        recognitionRequest?.endAudio()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.recognitionTask?.cancel()
            self?.recognitionRequest = nil
            self?.recognitionTask = nil
        }
        
        print("Listening stopped")
    }
    
    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceThreshold, repeats: false) { [weak self] _ in
            self?.handleSilenceDetected()
        }
    }
    
    private func handleSilenceDetected() {
        guard hasDetectedSpeech else {
            print("Silence timeout but no speech detected - continuing...")
            return
        }
        
        print("Silence detected after speech - auto-submitting")
        DispatchQueue.main.async {
            self.commitUserBuffer()
        }
    }
    
    private func handleSpeechComplete() {
        silenceTimer?.invalidate()
        silenceTimer = nil
    }
    
    func resetConversation() {
        stopSession()
        conversationHistory.removeAll()
        
        allUserSegments.removeAll()
        fullUserTranscript = ""
        conversationStartTime = nil
        hasDetectedSpeech = false
        
        do {
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Error reactivating audio: \(error)")
        }
        
        state = .idle
        speak("Okay, let's start fresh. What would you like to talk about?")
    }
    
    func commitUserBuffer() {
        if state == .speaking {
            synthesizer.stopSpeaking(at: .immediate)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.startListening()
            }
            return
        }
        
        stopListening()
        
        guard !currentBufferText.isEmpty,
              currentBufferText != "Listening...",
              currentBufferText.count > 1 else {
            print("No valid input detected")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.startListening()
            }
            return
        }
        
        let userInput = currentBufferText
        conversationHistory.append((speaker: "User", text: userInput))
        
        if !fullUserTranscript.isEmpty {
            fullUserTranscript += " "
        }
        fullUserTranscript += userInput
        
        print("User said: \(userInput)")
        print("Full transcript now: \(fullUserTranscript)")
        
        delegate?.addMessageToConversation(speaker: "User", text: userInput)
        
        state = .thinking
        
        Task {
            guard let session = self.session else {
                await MainActor.run {
                    self.delegate?.didEncounterError("AI session not initialized")
                    self.state = .idle
                }
                return
            }
            
            do {
                let response = try await session.respond(to: userInput)
                await MainActor.run {
                    self.speak(response.content)
                }
            } catch {
                print("AI response error: \(error)")
                await MainActor.run {
                    self.speak("Sorry, could you say that again?")
                }
            }
        }
    }
}
