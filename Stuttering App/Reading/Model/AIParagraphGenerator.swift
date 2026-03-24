import Foundation
import FoundationModels

class AIParagraphGenerator {
    
    static let shared = AIParagraphGenerator()
    private init() {}
    
    // MARK: - Public Function
    func generate(for letters: [String], topic: String) async throws -> String {
        
        let model = SystemLanguageModel.default
        
        // Check model availability
        guard model.availability == .available else {
            throw NSError(
                domain: "AIGenerator",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "AI Model not available on this device."]
            )
        }
        
        // Default letters if empty
        let targetLetters = letters.isEmpty ? ["S", "R"] : letters
        let lettersString = targetLetters.joined(separator: ", ")
        
        // MARK: - Instructions (System-level)
        let instructions = """
        Write a comprehension on "\(topic)".
        Naturally include words starting with these letters: [\(lettersString)].
        Keep the language simple and easy to read.
        Length should be between 1800 words.
        Break the content into small readable paragraphs.
        Do not use headings subheadings or bullet points.
        """
        
        let session = LanguageModelSession(
            model: model,
            instructions: instructions
        )
        
        // MARK: - Topic-specific prompt
        let topicPrompt = buildPrompt(for: topic)
        
        let prompt = """
        \(topicPrompt)
        Start directly with the paragraph no heading or subheading.
        Make it engaging and natural.
        """
        
        do {
            let response = try await session.respond(to: prompt)
            
            let rawContent = response.content
            
            // Clean formatting
            let formattedContent = rawContent
                .replacingOccurrences(of: "\n", with: "\n\n")
                .replacingOccurrences(of: "\n\n\n", with: "\n\n")
            
            return formattedContent
            
        } catch {
            print("Debug: AI generation failed → \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Topic Prompt Builder
    private func buildPrompt(for topic: String) -> String {
        
        switch topic.lowercased() {
            
        case "random":
            return """
            Write an interesting and slightly surprising comprehension based on a random real-life scenario or unexpected event.
            Keep it engaging and relatable.
            """
            
        case "science":
            return """
            Write a comprehension explaining basic scientific ideas such as energy, matter, simple experiments, and how science affects everyday life.
            """
            
        case "space":
            return """
            Write a comprehension about space including planets, stars, galaxies, astronauts, and space exploration.
            Make it easy to understand and slightly imaginative.
            """
            
        case "astronomy":
            return """
            Write a comprehension focused on astronomy including telescopes, constellations, black holes, and observation of the universe.
            """
            
        case "mindset":
            return """
            Write a motivational comprehension about growth mindset, discipline, habits, overcoming challenges, and self-improvement.
            """
            
        case "sports":
            return """
            Write a comprehension about sports including teamwork, competition, famous players, and the importance of physical fitness.
            """
            
        case "custom":
            return """
            Write a comprehension based on a custom topic provided by the user.
            Keep it clear, engaging, and meaningful.
            """
            
        default:
            return """
            Write a general comprehension about \(topic) in simple English.
            """
        }
    }
}
