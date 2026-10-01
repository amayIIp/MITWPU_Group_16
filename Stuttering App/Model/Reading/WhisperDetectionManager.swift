import Foundation
import WhisperKit

class WhisperDetectionManager {
    static let shared = WhisperDetectionManager()

    private var initTask: Task<Void, Error>?
    private var whisperKit: WhisperKit?
    private(set) var isReady = false

    private init() {}

    /// Starts loading the model, once.
    ///
    /// Previously this ran from the singleton's initialiser, which
    /// `AppDelegate.didFinishLaunchingWithOptions` triggered — so a 464 MB model
    /// began loading while the app was still launching, competing for I/O and
    /// memory with everything else on the launch path. iOS kills apps that take
    /// too long to launch, and App Review runs on devices under load.
    ///
    /// It is now called once the home screen is up and the app is interactive,
    /// which keeps the pre-warm (so the first reading session doesn't wait on a
    /// cold load) without putting it in front of the watchdog.
    func prewarm() {
        guard initTask == nil else { return }
        initTask = Task { @MainActor in
            guard let modelFolderURL = Self.bundledModelFolder() else {
                print("❌ WhisperKit: bundled model folder not found in app bundle.")
                throw NSError(
                    domain: "WhisperDetectionManager",
                    code: -3,
                    userInfo: [NSLocalizedDescriptionKey: "Bundled model weights not found in the app bundle."]
                )
            }

            print("Loading WhisperKit from bundled model at: \(modelFolderURL.path)")
            let config = WhisperKitConfig(
                model: "openai_whisper-small.en",
                modelFolder: modelFolderURL.path
            )
            whisperKit = try await WhisperKit(config)
            self.isReady = true
            print("✅ WhisperKit is ready (loaded from bundle)!")
        }
    }

    /// Finds the model weights in the app bundle.
    ///
    /// The target uses a file-system-synchronized group, which does not keep
    /// "openai_whisper-small.en" as a directory — it copies the five files
    /// inside it to the bundle root as loose resources. So the folder the old
    /// code looked for has never existed in a build, and every Whisper load
    /// failed with `modelsUnavailable(".../openai_whisper-small.en/MelSpectrogram.mlmodelc")`.
    ///
    /// Checks for the real subdirectory first, so this keeps working if the
    /// weights are later added as a folder reference, and otherwise uses the
    /// bundle root, which is where they actually are today. Presence of
    /// MelSpectrogram.mlmodelc is what tells the two apart.
    private static func bundledModelFolder() -> URL? {
        guard let resources = Bundle.main.resourceURL else { return nil }

        let marker = "MelSpectrogram.mlmodelc"
        let nested = resources.appendingPathComponent("openai_whisper-small.en")
        let fm = FileManager.default

        if fm.fileExists(atPath: nested.appendingPathComponent(marker).path) {
            return nested
        }
        if fm.fileExists(atPath: resources.appendingPathComponent(marker).path) {
            return resources
        }
        return nil
    }

    /// Waits for WhisperKit to finish initialising (near-instant when bundled).
    /// Starts the load if nothing has yet, so a caller that arrives before the
    /// pre-warm still gets a model rather than silence.
    func awaitReady() async {
        prewarm()
        guard let initTask = initTask else { return }
        _ = try? await initTask.value
    }

    func transcribe(audioURL: URL) async throws -> String? {
        prewarm()
        guard let initTask = initTask else {
            throw NSError(domain: "WhisperDetectionManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "WhisperKit initialization not started."])
        }

        // Wait for the model to finish loading before attempting transcription
        try await initTask.value
        guard let whisperKit else {
            throw NSError(domain: "WhisperDetectionManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "WhisperKit initialization did not finish."])
        }

        let path = audioURL.path

        // WhisperKit provides an easy audioPath transcription taking care of resampling.
        // Return nil if WhisperKit produced no usable transcript (empty segments or silence)
        // so the caller can fall back to the Apple Speech result instead.
        let transcriptionResult = try await whisperKit.transcribe(audioPath: path)
        let joined = transcriptionResult.map { $0.text }.joined(separator: " ")
        let trimmed = joined.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
