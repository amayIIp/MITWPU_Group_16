import Foundation

/// Main-actor isolated because `inFlightTasks` is shared between the launch
/// batch, on-demand requests and replacements. Those used to run on arbitrary
/// executors and mutate the dictionary concurrently. The generation itself
/// still runs off the main thread inside `AIParagraphGenerator`.
@MainActor
final class BackgroundParagraphManager {
    static let shared = BackgroundParagraphManager()

    private let topics = [
        "Science", "Space", "Astronomy", "Mindset", "Sports", "General"
    ]

    /// Tracks in-flight generation tasks so callers can await them instead of spawning duplicates.
    private var inFlightTasks: [String: Task<String?, Never>] = [:]

    private init() {}

    // MARK: - Foreground priority

    /// Screens the user is waiting on. While any exist, the batch holds off
    /// starting its next passage so the on-device model is free for them.
    private var foregroundWaiters = 0

    /// Brackets AI work a user is actively waiting on — the story they picked,
    /// the analysis of the reading they just finished.
    func beginForegroundWork() { foregroundWaiters += 1 }
    func endForegroundWork() { foregroundWaiters = max(0, foregroundWaiters - 1) }

    // MARK: - Initial Batch (called at app launch)

    func startInitialBatch() {
        print("DEBUG: BackgroundParagraphManager starting initial batch.")

        let troubledLetters = LogManager.shared.getTopStruggledLetters(limit: 5)

        var topicsToGenerate: [String] = []
        for topic in topics {
            let key = getStorageKey(for: topic)
            if UserDefaults.standard.string(forKey: key) == nil {
                print("DEBUG: No existing paragraph for topic '\(topic)'. Queuing for generation.")
                topicsToGenerate.append(topic)
            } else {
                print("DEBUG: Pre-generated paragraph exists for topic '\(topic)'.")
            }
        }

        // Generate sequentially in a single task to avoid hitting API rate limits
        if !topicsToGenerate.isEmpty {
            Task {
                await self.generateSequentially(topics: topicsToGenerate, troubledLetters: troubledLetters)
            }
        }
    }

    // MARK: - Await Paragraph (primary entry point for Reading Mode)

    /// Returns a paragraph for the given topic, waiting for AI generation if needed:
    /// 1. If a cached paragraph exists in UserDefaults, returns it immediately.
    /// 2. If background generation is already in-flight for this topic, awaits its result.
    /// 3. Otherwise, generates on-demand with the AI pipeline.
    /// After consuming, queues a background replacement for the next read.
    func awaitParagraph(for topic: String, troubledLetters: [String]) async -> String? {
        let key = getStorageKey(for: topic)
        let lowerTopic = topic.lowercased()

        // 1. Already cached in UserDefaults — fast path
        if let cached = UserDefaults.standard.string(forKey: key) {
            UserDefaults.standard.removeObject(forKey: key)
            print("DEBUG: Consumed cached paragraph for '\(topic)'. Queuing background replacement.")
            queueReplacement(topic: topic, troubledLetters: troubledLetters)
            return cached
        }

        // 2. In-flight background generation — await its result instead of spawning a duplicate
        if let existingTask = inFlightTasks[lowerTopic] {
            print("DEBUG: Background generation in-flight for '\(topic)'. Awaiting...")
            let result = await existingTask.value
            if result != nil {
                UserDefaults.standard.removeObject(forKey: key)
                queueReplacement(topic: topic, troubledLetters: troubledLetters)
            }
            return result
        }

        // 3. Nothing cached, nothing in-flight — generate on-demand
        print("DEBUG: No cache or in-flight task for '\(topic)'. Generating on-demand.")
        let result = await generateSingle(topic: topic, troubledLetters: troubledLetters)
        if result != nil {
            // generateSingle caches in case the caller gave up waiting; the
            // caller didn't, so this one is consumed now.
            UserDefaults.standard.removeObject(forKey: key)
            queueReplacement(topic: topic, troubledLetters: troubledLetters)
        }
        return result
    }

    // MARK: - Internal Generation

    /// Generates paragraphs one at a time with a short delay between each
    /// to stay within API rate limits.
    private func generateSequentially(topics: [String], troubledLetters: [String]) async {
        for (index, topic) in topics.enumerated() {
            let lowerTopic = topic.lowercased()

            // Let a screen the user is waiting on have the model first. The
            // passage already being written can't be interrupted, but the
            // next one doesn't start until they're served.
            while foregroundWaiters > 0 {
                try? await Task.sleep(nanoseconds: 500_000_000)
            }

            // Skip if already cached (another path may have generated it)
            let alreadyCached = UserDefaults.standard.string(forKey: getStorageKey(for: topic)) != nil
            if alreadyCached {
                print("DEBUG: '\(topic)' already cached. Skipping.")
                continue
            }

            let task = Task<String?, Never> {
                do {
                    print("DEBUG: Starting actual AI generation for '\(topic)'.")
                    let text = try await AIParagraphGenerator.shared.generate(for: troubledLetters, topic: topic)
                    print("DEBUG: AI generation complete for '\(topic)'. Storing in UserDefaults.")
                    UserDefaults.standard.set(text, forKey: self.getStorageKey(for: topic))
                    return text
                } catch {
                    print("DEBUG: Failed to generate paragraph for '\(topic)': \(error.localizedDescription)")
                    return nil
                }
            }

            inFlightTasks[lowerTopic] = task
            _ = await task.value
            inFlightTasks[lowerTopic] = nil

            // Small delay between requests to avoid 429 rate limits (skip after last)
            if index < topics.count - 1 {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    /// Generates a single paragraph on-demand (not part of the batch).
    private func generateSingle(topic: String, troubledLetters: [String]) async -> String? {
        let lowerTopic = topic.lowercased()

        let task = Task<String?, Never> {
            do {
                print("DEBUG: On-demand AI generation for '\(topic)'.")
                let text = try await AIParagraphGenerator.shared.generate(for: troubledLetters, topic: topic)
                // Cached straight away: if the reader's screen stopped waiting
                // and fell back to other text, this is ready for next time
                // instead of thrown away.
                UserDefaults.standard.set(text, forKey: self.getStorageKey(for: topic))
                return text
            } catch {
                print("DEBUG: On-demand generation failed for '\(topic)': \(error.localizedDescription)")
                return nil
            }
        }

        inFlightTasks[lowerTopic] = task
        let result = await task.value
        inFlightTasks[lowerTopic] = nil
        return result
    }

    /// Queues a background replacement so the next read has fresh content ready.
    private func queueReplacement(topic: String, troubledLetters: [String]) {
        Task {
            await self.generateSequentially(topics: [topic], troubledLetters: troubledLetters)
        }
    }

    private func getStorageKey(for topic: String) -> String {
        return "ai_paragraph_\(topic.lowercased())"
    }
}
