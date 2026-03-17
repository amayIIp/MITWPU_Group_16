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
        
        for topic in topics {
            let key = getStorageKey(for: topic)
            if UserDefaults.standard.string(forKey: key) == nil {
                print("DEBUG: No existing paragraph for topic '\(topic)'. Generating one in background.")
                generateAndStoreParagraph(for: topic, troubledLetters: troubledLetters)
            } else {
                print("DEBUG: Pre-generated paragraph exists for topic '\(topic)'.")
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
            
            // Queue up the next one
            print("DEBUG: Consumed paragraph for '\(topic)'. Queuing background generation for next time.")
            generateAndStoreParagraph(for: topic, troubledLetters: troubledLetters)
        }
        
        return paragraph
    }
    
    @MainActor
    private func generateAndStoreParagraph(for topic: String, troubledLetters: [String]) {
        Task {
            do {
                print("DEBUG: Starting actual AI generation for '\(topic)'.")
                let generatedText = try await AIParagraphGenerator.shared.generate(for: troubledLetters, topic: topic)
                print("DEBUG: AI generation complete for '\(topic)'. Storing in UserDefaults.")
                
                UserDefaults.standard.set(generatedText, forKey: self.getStorageKey(for: topic))
            } catch {
                print("DEBUG: Failed to generate background paragraph for '\(topic)': \(error.localizedDescription)")
            }
        }
    }
    
    private func getStorageKey(for topic: String) -> String {
        return "ai_paragraph_\(topic.lowercased())"
    }
}
