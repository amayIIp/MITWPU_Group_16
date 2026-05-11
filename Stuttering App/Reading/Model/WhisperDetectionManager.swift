import Foundation
import WhisperKit

class WhisperDetectionManager {
    static let shared = WhisperDetectionManager()
    
    private var initTask: Task<WhisperKit, Error>?
    private(set) var isReady = false
    
    private init() {
        initTask = Task {
            print("Loading WhisperKit model (small.en)...")
            // Initializes and automatically downloads the model if it's not present
            let kit = try await WhisperKit(model: "small.en")
            self.isReady = true
            print("WhisperKit is ready!")
            return kit
        }
    }
    
    /// Transcribes the audio file located at the specified URL using WhisperKit
    func awaitReady() async {
        guard let initTask = initTask else { return }
        _ = try? await initTask.value
    }
    
    func transcribe(audioURL: URL) async throws -> String? {
        guard let initTask = initTask else {
            throw NSError(domain: "WhisperDetectionManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "WhisperKit initialization not started."])
        }
        
        // Wait for the model to finish loading before attempting transcription
        let whisperKit = try await initTask.value
        
        let path = audioURL.path
        
        // WhisperKit provides an easy audioPath transcription taking care of resampling
        let transcriptionResult = try await whisperKit.transcribe(audioPath: path)
        
        // WhisperKit transcribe returns an array of TranscriptionResult if chunked,
        // or a single result depending on the library syntax.
        // It's safest to map and joined if it's an array, or just use the first.
        // Usually, in WhisperKit `.transcribe` returns `[TranscriptionResult]`.
        if let arrayResult = transcriptionResult as? [TranscriptionResult] {
            return arrayResult.map { $0.text }.joined(separator: " ")
        } else if let singleResult = transcriptionResult as? TranscriptionResult {
            return singleResult.text
        } else if let genericArray = transcriptionResult as? [Any] { // Sometimes mapped loosely
            // Best effort generic fallback for `.text` property resolution
            let stringValues = genericArray.compactMap { (item: Any) -> String? in
                let mirror = Mirror(reflecting: item)
                for child in mirror.children {
                    if child.label == "text", let text = child.value as? String {
                        return text
                    }
                }
                return nil
            }
            return stringValues.joined(separator: " ")
        }
        
        // Fallback if the return type is an unexpected structural type containing a text property
        let mirror = Mirror(reflecting: transcriptionResult)
        for child in mirror.children {
            if child.label == "text", let text = child.value as? String {
                return text
            }
        }
        
        throw NSError(domain: "WhisperDetectionManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unrecognized WhisperKit response format."])
    }
}
