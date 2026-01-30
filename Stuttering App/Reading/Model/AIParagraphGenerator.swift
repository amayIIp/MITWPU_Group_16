
import Foundation
import FoundationModels

class AIParagraphGenerator {
    
    static let shared = AIParagraphGenerator()
    
    private init() {}
    
    @MainActor
    func generate(for letters: [String]) async throws -> String {
        let model = SystemLanguageModel.default
        
        guard model.availability == .available else {
            throw NSError(domain: "AIGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "AI Model not available on this device."])
        }
        
        let targetLetters = letters.isEmpty ? ["S", "R"] : letters
        let lettersString = targetLetters.joined(separator: ", ")
        
        // Persona and Prompt Construction
        let instructions = """
        You are a creative writing assistant for speech therapy. 
        Your goal is to write a cohesive, interesting short story (about 1500-2000 words).
        Crucially, you must frequently use words starting with the letters: [\(lettersString)].
        Keep the sentence structure simple but engaging. 
        Do not mention that this is for speech therapy. Just write the story.
        """
        
        let session = LanguageModelSession(model: model, instructions: instructions)
        
        let prompt = "Write a story now."
        
        do {
            let response = try await session.respond(to: prompt)
            return response.content
        } catch {
            print("AI Generation Error: \(error)")
            throw error
        }
    }
}
