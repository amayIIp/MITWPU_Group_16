import Foundation

class BackgroundParagraphManager {
    static let shared = BackgroundParagraphManager()
    
    private let topics = [
        "Science", "Space", "Astronomy", "Mindset", "Sports", "General"
    ]
    
    private init() {}
    
    @MainActor
    func startInitialBatch() {
        print("DEBUG: BackgroundParagraphManager starting initial batch.")
        
        let troubledLetters = LogManager.shared.getTopStruggledLetters(limit: 5)
        
        // Collect topics that need generation
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
        
        // Generate sequentially in a single task to avoid hitting Gemini rate limits
        if !topicsToGenerate.isEmpty {
            Task {
                await self.generateSequentially(topics: topicsToGenerate, troubledLetters: troubledLetters)
            }
        }
    }
    
    @MainActor
    func consumeParagraph(for topic: String, troubledLetters: [String]) -> String? {
        let key = getStorageKey(for: topic)
        let paragraph = UserDefaults.standard.string(forKey: key)
        
        if paragraph != nil {
            // Remove it so it doesn't repeat
            UserDefaults.standard.removeObject(forKey: key)
            
            // Queue up the next one (single topic, no rate-limit risk)
            print("DEBUG: Consumed paragraph for '\(topic)'. Queuing background generation for next time.")
            Task {
                await self.generateSequentially(topics: [topic], troubledLetters: troubledLetters)
            }
        }
        
        return paragraph
    }
    
    /// Generates paragraphs one at a time with a short delay between each
    /// to stay within Gemini's free-tier rate limits.
    private func generateSequentially(topics: [String], troubledLetters: [String]) async {
        for (index, topic) in topics.enumerated() {
            do {
                print("DEBUG: Starting actual AI generation for '\(topic)'.")
                let generatedText = try await AIParagraphGenerator.shared.generate(for: troubledLetters, topic: topic)
                print("DEBUG: AI generation complete for '\(topic)'. Storing in UserDefaults.")
                
                await MainActor.run {
                    UserDefaults.standard.set(generatedText, forKey: self.getStorageKey(for: topic))
                }
            } catch {
                print("DEBUG: Failed to generate background paragraph for '\(topic)': \(error.localizedDescription)")
            }
            
            // Small delay between requests to avoid 429 rate limits (skip after last)
            if index < topics.count - 1 {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            }
        }
    }
    
    private func getStorageKey(for topic: String) -> String {
        return "ai_paragraph_\(topic.lowercased())"
    }
}
