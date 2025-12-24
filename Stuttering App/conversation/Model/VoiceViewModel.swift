import UIKit
import AVFoundation
import Speech
import FoundationModels

protocol VoiceViewModelDelegate: AnyObject {
    func didUpdateState(_ state: VoiceViewModel.VoiceState)
    func didUpdateTranscript(_ text: String, isUser: Bool)
    func didEncounterError(_ message: String)
}

class VoiceViewModel: NSObject, AVSpeechSynthesizerDelegate {

    enum VoiceState { case idle, speaking, listening, thinking }
    
    weak var delegate: VoiceViewModelDelegate?
    private(set) var state: VoiceState = .idle {
        didSet { delegate?.didUpdateState(state) }
    }
    
    private var session: LanguageModelSession?
    private let synthesizer = AVSpeechSynthesizer()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // Data
    private var currentBufferText: String = ""
    
    override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
    }
    
    // MARK: - Lifecycle Management
    
    /// NEW: Completely halts all audio and AI processing.
    /// Call this when the View Controller is dismissing.
    func stopSession() {
        // 1. Stop Speaking immediately
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        // 2. Stop Listening (Audio Engine & Recognition)
        stopListening()
        
        // 3. Reset State
        state = .idle
        
        // 4. Deactivate Audio Session to release hardware resources
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        print("Voice Session Stopped")
    }
    
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio Session Error: \(error)")
        }
    }
    
    // MARK: - AI Initialization
    @MainActor
    func prepareModel() async {
        let model = SystemLanguageModel.default
        let personaInstructions = "You are a warm, calm friend. Keep responses short (1-2 sentences). Do not correct grammar."
        
        if model.availability == .available {
            self.session = LanguageModelSession(model: model, instructions: personaInstructions)
            speak("Hello there. How is your day going so far?")
        } else {
            delegate?.didEncounterError("Model Unavailable")
        }
    }
    
    // MARK: - Speech Synthesis (Output)
    
    func speak(_ text: String) {
        stopListening() // Ensure we aren't listening to ourselves
        state = .speaking
        delegate?.didUpdateTranscript(text, isUser: false)
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US") // Simplified for stability
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        
        synthesizer.speak(utterance)
    }
    
    // Delegate: Called when AI finishes speaking -> Start Listening
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // Only start listening if the session hasn't been stopped
        guard state != .idle else { return }
        Task { @MainActor in self.startListening() }
    }
    
    // MARK: - Speech Recognition (Input)
    
    func startListening() {
        guard !audioEngine.isRunning else { return }
        state = .listening
        currentBufferText = ""
        delegate?.didUpdateTranscript("Listening...", isUser: true)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let req = recognitionRequest else { return }
        req.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        recognitionTask = speechRecognizer?.recognitionTask(with: req) { [weak self] result, error in
            guard let self = self else { return }
            
            if let res = result {
                self.currentBufferText = res.bestTranscription.formattedString
                self.delegate?.didUpdateTranscript(self.currentBufferText, isUser: true)
            }
            
            if error != nil || (result?.isFinal ?? false) {
                self.stopListening()
            }
        }
        
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            req.append(buffer)
        }
        
        do {
            try audioEngine.start()
        } catch {
            delegate?.didEncounterError("Audio Engine Failed")
        }
    }
    
    func stopListening() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
    }
    
    // MARK: - Interaction Logic
    
    func resetConversation() {
        stopSession()
        // Re-activate session logic
        try? AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        state = .idle
        speak("Let's start fresh. What's on your mind?")
    }
    
    func commitUserBuffer() {
        // If we are currently speaking, this button acts as "Stop"
        if state == .speaking {
            synthesizer.stopSpeaking(at: .immediate)
            startListening()
            return
        }
        
        // Stop recording to process the result
        stopListening()
        
        guard !currentBufferText.isEmpty, currentBufferText != "Listening..." else {
            startListening() // Nothing said, resume listening
            return
        }
        
        state = .thinking
        Task {
            guard let session = session else { return }
            do {
                let response = try await session.respond(to: currentBufferText)
                speak(response.content)
            } catch {
                speak("I'm sorry, I didn't catch that.")
            }
        }
    }
}
