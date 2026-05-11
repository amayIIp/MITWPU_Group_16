import Foundation
import FoundationModels

class AIParagraphGenerator {
    
    static let shared = AIParagraphGenerator()
    private init() {}
    
    // MARK: - Public Function
    func generate(for letters: [String], topic: String) async throws -> String {
        
        let targetLetters = letters.isEmpty ? ["S", "R"] : letters
        let lettersString = targetLetters.joined(separator: ", ")
        
        let instructions = """
        Write a comprehension on "\(topic)".
        Naturally include words starting with these letters: [\(lettersString)].
        Keep the language simple and easy to read.
        Length should be between 1800 words.
        Break the content into small readable paragraphs.
        Do not use headings subheadings or bullet points.
        """
        
        let topicPrompt = buildPrompt(for: topic)
        let prompt = """
        \(topicPrompt)
        Start directly with the paragraph no heading or subheading and don't include any mathematical digits and any other special character only aplhabets .
        Make it engaging and natural.
        """
        
        // ── Tier 1: On-device Foundation Model ─────────────────────────
        let model = SystemLanguageModel.default
        
        if model.availability == .available {
            do {
                let session = LanguageModelSession(model: model, instructions: instructions)
                let response = try await session.respond(to: prompt)
                let rawContent = response.content
                return rawContent
                    .replacingOccurrences(of: "\n", with: "\n\n")
                    .replacingOccurrences(of: "\n\n\n", with: "\n\n")
            } catch {
                print("AIParagraphGenerator: Foundation Model failed — \(error.localizedDescription)")
            }
        }
        
        // ── Tier 2: Gemini API Fallback ────────────────────────────────
        print("AIParagraphGenerator: Using Gemini API fallback")
        
        if let geminiResult = await GeminiService.shared.generateLongForm(
            systemInstruction: instructions, prompt: prompt
        ) {
            return geminiResult
                .replacingOccurrences(of: "\n", with: "\n\n")
                .replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        
        // ── Tier 3: Hardcoded Rule-Based Fallback ──────────────────────
        print("AIParagraphGenerator: Both AI layers failed. Using rule-based fallback.")
        return generateFallbackParagraph(for: topic)
    }
    
    // MARK: - Topic Prompt Builder
    private func buildPrompt(for topic: String) -> String {
        switch topic.lowercased() {
        case "random":
            return "Write an interesting and slightly surprising comprehension based on a random real-life scenario or unexpected event. Keep it engaging and relatable."
        case "science":
            return "Write a comprehension explaining basic scientific ideas such as energy, matter, simple experiments, and how science affects everyday life."
        case "space":
            return "Write a comprehension about space including planets, stars, galaxies, astronauts, and space exploration. Make it easy to understand and slightly imaginative."
        case "astronomy":
            return "Write a comprehension focused on astronomy including telescopes, constellations, black holes, and observation of the universe."
        case "mindset":
            return "Write a motivational comprehension about growth mindset, discipline, habits, overcoming challenges, and self-improvement."
        case "sports":
            return "Write a comprehension about sports including teamwork, competition, famous players, and the importance of physical fitness."
        case "custom":
            return "Write a comprehension based on a custom topic provided by the user. Keep it clear, engaging, and meaningful."
        default:
            return "Write a general comprehension about \(topic) in simple English."
        }
    }

    // MARK: - Rule-Based Fallback
    private func generateFallbackParagraph(for topic: String) -> String {
        switch topic.lowercased() {
        case "science":
            return """
            Science is the systematic study of the physical and natural world through observation and experiment. It helps us understand how things work, from the smallest atoms to the vastness of the universe. By asking questions and testing ideas, scientists discover new knowledge that improves our daily lives.
            
            Every time we use electricity, take medicine, or look at a weather forecast, we are relying on scientific discoveries. In laboratories around the globe, researchers continue to push the boundaries of what is possible, finding solutions to complex global challenges.
            
            Curiosity is at the heart of all scientific inquiry. When we remain curious and open to learning, we embrace the true spirit of science. This continuous pursuit of knowledge ensures that society keeps moving forward, unlocking new mysteries every single day.
            """
        case "space":
            return """
            Space is a vast, endless frontier that has fascinated humanity for thousands of years. Looking up at the night sky, we see stars that are millions of light-years away, reminding us of how small our world truly is. The exploration of space challenges our technology and our imagination.
            
            Astronauts who travel beyond our atmosphere experience true weightlessness and see the Earth as a fragile blue sphere. Their missions help us understand our solar system, the nature of gravity, and the potential for life on other planets. Every mission brings back valuable data that changes our perspective.
            
            As technology advances, the dream of traveling further into the cosmos becomes more realistic. We continue to build better rockets and more powerful telescopes, reaching deeper into the unknown. The mysteries of space will always inspire us to look up and wonder what lies beyond.
            """
        case "astronomy":
            return """
            Astronomy is one of the oldest sciences, dedicated to observing the stars, planets, and galaxies. Ancient civilizations used the movements of the stars to navigate oceans and track the changing seasons. Today, modern astronomy uses advanced telescopes to look deep into the universe.
            
            By studying the light from distant stars, astronomers can determine their age, temperature, and composition. They search for exoplanets orbiting other suns, hoping to find worlds similar to our own. This careful observation reveals the incredible scale and beauty of the cosmos.
            
            The universe is constantly expanding and changing over billions of years. Supernovas create the heavy elements needed for life, and black holes distort the very fabric of space and time. Astronomy connects us to these cosmic events, showing us our place in the grand design.
            """
        case "mindset":
            return """
            A strong mindset is the foundation of personal growth and resilience. How we think about our challenges directly affects how we overcome them. When we adopt a positive and determined attitude, obstacles become opportunities to learn rather than barriers to success.
            
            Building good habits takes time and steady effort. Discipline is simply the act of choosing what you want most over what you want right now. By staying focused on long-term goals and celebrating small victories along the way, we build the momentum needed to create lasting change.
            
            Believing in yourself is a powerful tool. When you trust your own abilities and refuse to give up, you unlock your true potential. Every great achievement starts with the decision to try, and the courage to keep going even when the path gets difficult.
            """
        case "sports":
            return """
            Sports bring people together from all walks of life, teaching the values of teamwork, dedication, and fair play. Whether playing on a local field or competing on a global stage, athletes show us what the human body and spirit can achieve through rigorous training.
            
            Physical fitness is a core benefit of engaging in sports, but the mental benefits are equally important. Learning how to win with grace and lose with dignity builds character. The discipline required to practice every day translates directly into everyday life and personal success.
            
            The excitement of a close match or a record-breaking performance inspires millions of fans worldwide. Sports remind us that with hard work and collaboration, incredible goals can be reached. The shared passion for the game unites communities and creates lasting memories.
            """
        default:
            return """
            Learning something new every day is a wonderful way to keep your mind sharp and engaged. Reading about different topics helps expand your vocabulary and improves your ability to communicate clearly. When you practice reading aloud, you gain confidence in your speech.
            
            Taking your time to read each sentence carefully allows you to fully absorb the meaning. There is no need to rush; steady and smooth pacing is always better than speed. This practice helps build a strong foundation for both reading comprehension and verbal expression.
            
            Keep practicing consistently, and you will notice steady improvement over time. Every small step forward is progress worth celebrating. Remember that patience and persistence are the most important tools on your journey to better communication.
            """
        }
    }
}
