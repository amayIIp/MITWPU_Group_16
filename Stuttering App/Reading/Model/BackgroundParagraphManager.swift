import Foundation

class BackgroundParagraphManager {
    static let shared = BackgroundParagraphManager()
    
    private let topics = [
        "Science", "Space", "Astronomy", "Mindset", "Sports", "General"
    ]
    
    /// Tracks in-flight generation tasks so callers can await them instead of spawning duplicates.
    private var inFlightTasks: [String: Task<String?, Never>] = [:]
    
    private init() {}
    
    // MARK: - Initial Batch (called at app launch)
    
    @MainActor
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
        let cached: String? = await MainActor.run {
            UserDefaults.standard.string(forKey: key)
        }
        if let cached = cached {
            await MainActor.run {
                UserDefaults.standard.removeObject(forKey: key)
            }
            print("DEBUG: Consumed cached paragraph for '\(topic)'. Queuing background replacement.")
            queueReplacement(topic: topic, troubledLetters: troubledLetters)
            return cached
        }
        
        // 2. In-flight background generation — await its result instead of spawning a duplicate
        if let existingTask = inFlightTasks[lowerTopic] {
            print("DEBUG: Background generation in-flight for '\(topic)'. Awaiting...")
            let result = await existingTask.value
            if result != nil {
                await MainActor.run {
                    UserDefaults.standard.removeObject(forKey: key)
                }
                queueReplacement(topic: topic, troubledLetters: troubledLetters)
            }
            return result
        }
        
        // 3. Nothing cached, nothing in-flight — generate on-demand
        print("DEBUG: No cache or in-flight task for '\(topic)'. Generating on-demand.")
        let result = await generateSingle(topic: topic, troubledLetters: troubledLetters)
        if result != nil {
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
            
            // Skip if already cached (another path may have generated it)
            let alreadyCached: Bool = await MainActor.run {
                UserDefaults.standard.string(forKey: getStorageKey(for: topic)) != nil
            }
            if alreadyCached {
                print("DEBUG: '\(topic)' already cached. Skipping.")
                continue
            }
            
            let task = Task<String?, Never> {
                do {
                    print("DEBUG: Starting actual AI generation for '\(topic)'.")
                    let text = try await AIParagraphGenerator.shared.generate(for: troubledLetters, topic: topic)
                    print("DEBUG: AI generation complete for '\(topic)'. Storing in UserDefaults.")
                    await MainActor.run {
                        UserDefaults.standard.set(text, forKey: self.getStorageKey(for: topic))
                    }
                    return text
                } catch {
                    print("DEBUG: Failed to generate paragraph for '\(topic)': \(error.localizedDescription)")
                    return nil
                }
            }
            
            inFlightTasks[lowerTopic] = task
            let _ = await task.value
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
                return try await AIParagraphGenerator.shared.generate(for: troubledLetters, topic: topic)
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
