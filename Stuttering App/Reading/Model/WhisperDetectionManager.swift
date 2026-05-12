import Foundation
import WhisperKit

class WhisperDetectionManager {
    static let shared = WhisperDetectionManager()
    
    private var initTask: Task<WhisperKit, Error>?
    private(set) var isReady = false
    
    private init() {
        initTask = Task {
            // Locate the bundled model folder shipped inside the app bundle.
            // The folder "openai_whisper-small.en" must be added to the Xcode
            // project as a folder reference (blue folder icon) with "Copy items
            // if needed" checked and the app target selected.
            guard let modelFolderURL = Bundle.main.resourceURL?
                .appendingPathComponent("openai_whisper-small.en") else {
                print("❌ WhisperKit: bundled model folder not found in app bundle.")
                throw NSError(
                    domain: "WhisperDetectionManager",
                    code: -3,
                    userInfo: [NSLocalizedDescriptionKey: "Bundled model folder 'openai_whisper-small.en' not found. Make sure it is added to the Xcode target."]
                )
            }

            print("Loading WhisperKit from bundled model at: \(modelFolderURL.path)")
            let config = WhisperKitConfig(
                model: "openai_whisper-small.en",
                modelFolder: modelFolderURL.path
            )
            let kit = try await WhisperKit(config)
            self.isReady = true
            print("✅ WhisperKit is ready (loaded from bundle)!")
            return kit
        }
    }
    
    /// Waits for WhisperKit to finish initialising (near-instant when bundled).
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
        
        if let arrayResult = transcriptionResult as? [TranscriptionResult] {
            return arrayResult.map { $0.text }.joined(separator: " ")
        } else if let singleResult = transcriptionResult as? TranscriptionResult {
            return singleResult.text
        } else if let genericArray = transcriptionResult as? [Any] {
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
        
        let mirror = Mirror(reflecting: transcriptionResult)
        for child in mirror.children {
            if child.label == "text", let text = child.value as? String {
                return text
            }
        }
        
        throw NSError(domain: "WhisperDetectionManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unrecognized WhisperKit response format."])
    }
}
