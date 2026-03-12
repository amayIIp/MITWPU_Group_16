
import Foundation
import FoundationModels

class AIParagraphGenerator {
    
    static let shared = AIParagraphGenerator()
    
    private init() {}
    
    @MainActor
    func generate(for letters: [String], topic: String) async throws -> String {
        let model = SystemLanguageModel.default
        
        guard model.availability == .available else {
            throw NSError(domain: "AIGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "AI Model not available on this device."])
        }
        
        let targetLetters = letters.isEmpty ? ["S", "R"] : letters
        let lettersString = targetLetters.joined(separator: ", ")
        
        let instructions = """
                write a comprehension on "\(topic)".
                this comprehension must include the following words: [\(lettersString)].
                it must be atleast 3000 words.
                it must change paragraphs at an interval of 50 words approx .
        """
        
        let session = LanguageModelSession(model: model, instructions: instructions)
        
        let prompt = "Write a 3000 word paragraph about \(topic) in simple English don't write headings or subheadings just start with paragraph ."
        
        do {
            let response = try await session.respond(to: prompt)
            let rawContent = response.content
            let spacedContent = rawContent.replacingOccurrences(of: "\n", with: "\n\n")
                                          .replacingOccurrences(of: "\n\n\n", with: "\n\n") // Normalize massive gaps
            
            return spacedContent
        } catch {
            print("Debug: AI Model skipped generation (Safety/Reference). Error: \(error.localizedDescription)")
            throw error
        }
    }
}
