//
//  InsightEngine.swift
//  Spasht
//

import Foundation
import FoundationModels

struct DayInsightContext {
    let avgFluency: Double
    let avgBlock: Double
    let avgAccuracy: Double
    let fluencyGrowth: Double
    let improvementPercent: Double
    let sessionCount: Int
    let topImprovedLetters: [(letter: String, improvementPct: Double)]
}

struct OverallInsightContext {
    let fluencyGrowthPercent: Double
    let avgAccuracy: Double
    let avgBlock: Double
    let streak: Int
    let weekOverWeekImprovementPct: Double
    let daysPracticed: Int
    let mostCommonStutterType: String
}

actor InsightEngine {

    static let shared = InsightEngine()
    private var session: LanguageModelSession?

    private init() {}
    func dayInsight(context: DayInsightContext) async -> String {
        if context.sessionCount == 0 {
            return "Let's get started! Do some exercises and start practicing today."
        }
        
        // Tier 1: On-device Foundation Model
        if let aiInsight = await generateDayInsightAI(context: context) {
            return aiInsight
        }
        // Tier 2: Gemini API (cloud fallback)
        if let geminiInsight = await generateDayInsightGemini(context: context) {
            return geminiInsight
        }
        // Tier 3: Deterministic rule-based fallback
        return generateDayInsightRuleBased(context: context)
    }
    
    func overallHeadline(context: OverallInsightContext) async -> String {
        // Tier 1: On-device Foundation Model
        if let aiHeadline = await generateOverallHeadlineAI(context: context) {
            return aiHeadline
        }
        // Tier 2: Gemini API (cloud fallback)
        if let geminiHeadline = await generateOverallHeadlineGemini(context: context) {
            return geminiHeadline
        }
        // Tier 3: Deterministic rule-based fallback
        return generateOverallHeadlineRuleBased(context: context)
    }

    private func isValidInsight(_ text: String) -> Bool {
        let words = text.split { $0.isWhitespace }
        // The prompt asks for < 15 words, so let's allow up to 30 just to be safe.
        return !words.isEmpty && words.count <= 30
    }

    
    private func generateDayInsightAI(context: DayInsightContext) async -> String? {
        
        guard let session = getOrCreateSession() else {
            return nil
        }
        
        let prompt = buildDayPrompt(context: context)
        
        do {
            let response = try await session.respond(to: prompt)
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !text.isEmpty, isValidInsight(text) else {
                return nil
            }
            
            return text
        } catch {
            print("InsightEngine: Model failed — \(error.localizedDescription)")
            return nil
        }
    }

    private func generateOverallHeadlineAI(context: OverallInsightContext) async -> String? {
        
        guard let session = getOrCreateSession() else {
            return nil
        }
        
        let prompt = buildOverallPrompt(context: context)
        
        do {
            let response = try await session.respond(to: prompt)
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !text.isEmpty, text.count < 150 else {
                return nil
            }
            
            return text
        } catch {
            print("InsightEngine: Model failed — \(error.localizedDescription)")
            return nil
        }
    }

    private func getOrCreateSession() -> LanguageModelSession? {
        
        if let existing = session {
            return existing
        }
        
        let model = SystemLanguageModel.default
        
        guard model.availability == .available else {
            print("InsightEngine: Model not available")
            return nil
        }
        
        let instructions = """
        You are a supportive speech therapy coach .

        Rules:
        - Exactly 2 sentences.
        - Total length must be less than 15 words.
        - Both sentences must be similar length (roughly equal words).
        - Do not use any numbers or percentages in your response.
        - Warm and encouraging, never clinical.
        - No emojis, no markdown, no bullet points.
        - If letter improvement data exists, lead with it.
        - Output ONLY the insight text.
        """
        
        let newSession = LanguageModelSession(
            model: model,
            instructions: instructions
        )
        
        session = newSession
        return newSession
    }

    private func buildDayPrompt(context: DayInsightContext) -> String {

        var parts: [String] = []

        if !context.topImprovedLetters.isEmpty {
            let letterDesc = context.topImprovedLetters
                .prefix(2)
                .map { "'\($0.letter)' improved \(Int($0.improvementPct))%" }
                .joined(separator: " and ")
            parts.append("Letter improvements today: \(letterDesc).")
        }

        parts.append("Fluency score today: \(Int(context.avgFluency))/100.")
        parts.append("Block percentage: \(Int(context.avgBlock))%.")
        parts.append("Accuracy: \(Int(context.avgAccuracy))%.")

        if context.fluencyGrowth > 0 {
            parts.append("Fluency improved by \(String(format: "%.1f", context.fluencyGrowth)) points vs yesterday.")
        } else if context.fluencyGrowth < 0 {
            parts.append("Fluency was \(String(format: "%.1f", abs(context.fluencyGrowth))) points lower than yesterday.")
        } else {
            parts.append("Fluency was similar to yesterday.")
        }

        parts.append("Sessions completed today: \(context.sessionCount).")

        return """
            Here is the user's speech practice data for today:

            \(parts.joined(separator: "\n"))

            Write a short, warm, specific insight for this user about their day. \
            Maximum 2 sentences. Do not include any numbers. \
            If letter improvement data is present, lead with that.
            """
    }

    private func buildOverallPrompt(context: OverallInsightContext) -> String {

        let parts: [String] = [
            "Total days practiced: \(context.daysPracticed).",
            "Overall fluency growth since first session: \(Int(context.fluencyGrowthPercent))%.",
            "Average accuracy all time: \(Int(context.avgAccuracy))%.",
            "Average block percentage: \(Int(context.avgBlock))%.",
            "Current streak: \(context.streak) days.",
            "Week-over-week improvement: \(Int(context.weekOverWeekImprovementPct))%.",
            "Most common stutter type: \(context.mostCommonStutterType)."
        ]

        return """
            Here is the user's overall speech progress summary:

            \(parts.joined(separator: "\n"))

            Write a single motivating headline sentence (max 12 words) that captures \
            their overall progress. Do not include any numbers. \
            Output only the sentence — no quotes, no label.
            """
    }

    // MARK: - Tier 2: Gemini API Fallback

    private let geminiSystemInstruction = """
    You are a supportive speech therapy coach inside an app called Spasht.

    Rules:
    - Exactly 2 sentences.
    - Total length must be less than 15 words.
    - Both sentences must be similar length (roughly equal words).
    - Do not use any numbers or percentages in your response.
    - Warm and encouraging, never clinical.
    - No emojis, no markdown, no bullet points.
    - If letter improvement data exists, lead with it.
    - Output ONLY the insight text.
    """

    private func generateDayInsightGemini(context: DayInsightContext) async -> String? {
        let prompt = buildDayPrompt(context: context)

        guard let text = await GeminiService.shared.generate(
            systemInstruction: geminiSystemInstruction,
            prompt: prompt
        ) else {
            print("InsightEngine: Gemini day insight failed, falling back to rules")
            return nil
        }

        // Apply the same validation as the Foundation Model path
        guard isValidInsight(text) else {
            print("InsightEngine: Gemini day insight failed validation")
            return nil
        }

        return text
    }

    private func generateOverallHeadlineGemini(context: OverallInsightContext) async -> String? {
        let prompt = buildOverallPrompt(context: context)

        guard let text = await GeminiService.shared.generate(
            systemInstruction: geminiSystemInstruction,
            prompt: prompt
        ) else {
            print("InsightEngine: Gemini headline failed, falling back to rules")
            return nil
        }

        guard !text.isEmpty, text.count < 150 else {
            print("InsightEngine: Gemini headline failed validation")
            return nil
        }

        return text
    }

    // MARK: - Tier 3: Rule-Based Fallback — Day Insight

    func generateDayInsightRuleBased(context: DayInsightContext) -> String {

        // 1. Letter improvement — most personal
        if !context.topImprovedLetters.isEmpty {
            let top    = context.topImprovedLetters.prefix(2)

            let lettersStr: String
            if top.count == 1 {
                lettersStr = "'\(top[0].letter)'"
            } else {
                lettersStr = "'\(top[0].letter)' and '\(top[1].letter)'"
            }
            return "Your \(lettersStr) sounds have improved today!!"
        }

        // 2. High blocks
        if context.avgBlock > 30 {
            return "Blocks are your main challenge today. Try slow, deliberate starts on each sentence."
        }

        // 3. Low accuracy
        if context.avgAccuracy < 60 {
            return "Focus on shorter passages and give yourself time to breathe."
        }

        // 4. Fluency jump
        if context.fluencyGrowth > 5 {
            return "Great progress! Your fluency jumped today. Keep that momentum!"
        }

        // 5. Fluency dip
        if context.fluencyGrowth < -5 {
            return "Fluency dipped a little today — that's completely normal. A gentle warm-up before your next session will help."
        }

        // 6. High session count
        if context.sessionCount >= 3 {
            return "Solid consistency! Multiple short sessions are one of the best ways to improve."
        }

        // 7. High score
        if context.avgFluency >= 80 {
            return "Excellent day! Your fluency score shows real control. Challenge yourself with a harder passage tomorrow."
        }

        return "You showed up and practiced — that's what counts. Every session builds the habit. Keep going!"
    }

    // MARK: - Rule-Based Fallback — Overall Headline

    func generateOverallHeadlineRuleBased(context: OverallInsightContext) -> String {
        if context.fluencyGrowthPercent >= 50 && context.avgAccuracy >= 80 {
            return "You're speaking with remarkable smoothness and confidence!"
        }
        if context.fluencyGrowthPercent >= 30 {
            return "Fantastic progress — your fluency has come a long way!"
        }
        if context.streak >= 7 {
            return "A full week of practice! Consistency is your superpower."
        }
        if context.avgBlock < 15 {
            return "Blocks are barely slowing you down — great control!"
        }
        if context.avgAccuracy >= 85 {
            return "Your accuracy is excellent — keep building on it!"
        }
        if context.weekOverWeekImprovementPct >= 20 {
            return "Big week! You improved significantly compared to last week."
        }
        return "Every session counts. You're making real progress — keep going!"
    }
}
