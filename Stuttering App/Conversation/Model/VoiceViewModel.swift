// VoiceViewModel.swift

import UIKit
import AVFoundation
import Speech
import FoundationModels

// MARK: - Delegate Protocol

protocol VoiceViewModelDelegate: AnyObject {
    func didUpdateState(_ state: VoiceViewModel.VoiceState)
    func didUpdateTranscript(_ text: String, isUser: Bool)
    func didEncounterError(_ message: String)
    func addMessageToConversation(speaker: String, text: String)
    func didUpdateAudioLevel(_ level: Float)
}

class VoiceViewModel: NSObject, AVSpeechSynthesizerDelegate {
    
    // MARK: - Types
    
    enum VoiceState {
        case idle, speaking, listening, thinking
        
        var isActive: Bool {
            return self != .idle
        }
    }
    
    // MARK: - Properties
    
    weak var delegate: VoiceViewModelDelegate?
    
    private(set) var state: VoiceState = .idle {
        didSet {
            delegate?.didUpdateState(state)
        }
    }
    
    private var session: LanguageModelSession?
    private let synthesizer = AVSpeechSynthesizer()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    private var currentBufferText: String = ""
    private var conversationHistory: [(speaker: String, text: String)] = []
    
    private var silenceTimer: Timer?
    private let silenceThreshold: TimeInterval = 2.5
    private var hasDetectedSpeech = false
    
    // MARK: - Init
    
    override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
    }
    
    // MARK: - Public Interface
    
    var isConversationActive: Bool {
        return state.isActive
    }
    
    var hasConversationHistory: Bool {
        return !conversationHistory.isEmpty
    }
    
    var isModelReady: Bool {
        return session != nil
    }
    
    func resetConversationHistory() {
        conversationHistory.removeAll()
        hasDetectedSpeech = false
    }
    
    // MARK: - Session Lifecycle
    
    func stopSession() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        stopListening()
        state = .idle
        currentBufferText = ""
    }
    
    func resetConversation() {
        stopSession()
        conversationHistory.removeAll()
        hasDetectedSpeech = false
        
        do {
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            delegate?.didEncounterError("Failed to restart audio session")
        }
        
        Task { @MainActor in
            await self.prepareModel()
            self.state = .idle
            self.speak("Okay, let's start fresh. What would you like to talk about?")
        }
    }
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetoothA2DP])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            delegate?.didEncounterError("Audio setup failed. Please restart the app.")
        }
    }
    
    // MARK: - AI / Language Model
    
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
        } else {
            delegate?.didEncounterError("AI model is not available on this device.")
        }
    }
    
    func startConversation() {
        guard session != nil else {
            delegate?.didEncounterError("AI is not ready yet")
            return
        }
        speak("Hi there! I'm ready to chat. How are you doing today?")
    }
    
    // MARK: - Speech Synthesis
    
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
        if state == .speaking {
            state = .idle
        }
    }
    
    // MARK: - Speech Recognition & Audio Metering
    
    func startListening() {
        guard !audioEngine.isRunning else { return }
        
        configureAudioSession()
        
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
                    }
                    
                    self.currentBufferText = newText
                    self.delegate?.didUpdateTranscript(self.currentBufferText, isUser: true)
                    self.resetSilenceTimer()
                }
                
                if res.isFinal {
                    self.handleSpeechComplete()
                }
            }
            
            if let error = error {
                let nsError = error as NSError
                
                if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1110 {
                    return
                }
                
                if nsError.domain == "kLSRErrorDomain" && nsError.code == 301 {
                    return
                }
                
                self.stopListening()
            }
        }
        
        let format = inputNode.outputFormat(forBus: 0)
        
        guard format.sampleRate > 0 && format.channelCount > 0 else {
            delegate?.didEncounterError("Microphone format error")
            return
        }
        
        inputNode.removeTap(onBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak req, weak self] buffer, _ in
            guard buffer.frameLength > 0 else { return }
            req?.append(buffer)
            
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frames = Int(buffer.frameLength)
            
            var sumSquares: Float = 0.0
            for i in 0..<frames {
                let sample = channelData[i]
                sumSquares += sample * sample
            }
            let rms = sqrt(sumSquares / Float(frames))
            let power = rms > 0 ? 20.0 * log10(rms) : -160.0
            
            let minDb: Float = -65.0
            let normalizedLevel = max(0.0, min(1.0, (power - minDb) / (0.0 - minDb)))
            
            DispatchQueue.main.async {
                self?.delegate?.didUpdateAudioLevel(normalizedLevel)
            }
        }
        
        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
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
        
        // Ensure state updates to idle if we manually hit stop (mute)
        if state == .listening {
            state = .idle
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.didUpdateAudioLevel(0.0)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.recognitionTask?.cancel()
            self?.recognitionRequest = nil
            self?.recognitionTask = nil
        }
    }
    
    // MARK: - Silence Detection
    
    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceThreshold, repeats: false) { [weak self] _ in
            self?.handleSilenceDetected()
        }
    }
    
    private func handleSilenceDetected() {
        guard hasDetectedSpeech else { return }
        
        DispatchQueue.main.async {
            self.commitUserBuffer()
        }
    }
    
    private func handleSpeechComplete() {
        silenceTimer?.invalidate()
        silenceTimer = nil
    }
    
    // MARK: - Conversation Management
    
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.startListening()
            }
            return
        }
        
        let userInput = currentBufferText
        conversationHistory.append((speaker: "User", text: userInput))
        
        delegate?.addMessageToConversation(speaker: "User", text: userInput)
        state = .thinking
        
        Task { @MainActor in
            guard let session = self.session else {
                self.delegate?.didEncounterError("AI session not initialized")
                self.state = .idle
                return
            }
            
            do {
                let response = try await session.respond(to: userInput)
                let responseContent = response.content
                self.speak(responseContent)
            } catch {
                self.speak("Sorry, could you say that again?")
            }
        }
    }
}
