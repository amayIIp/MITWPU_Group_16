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

    /// True when this is the very first reading session ever recorded for this user.
    /// Prevents the AI from making comparisons against non-existent prior data.
    let isFirstEverSession: Bool

    /// True only when yesterday has at least one recorded session.
    /// Prevents the AI from saying "similar to yesterday" when there was no yesterday.
    let hasPreviousDay: Bool
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

    private init() {}
    func dayInsight(context: DayInsightContext) async -> String {
        if context.sessionCount == 0 {
            return "Let's get started! Do some exercises and start practicing today."
        }

        // First ever session — skip comparisons entirely
        if context.isFirstEverSession {
            return "Welcome! Great first session — we're just starting to learn your speech patterns."
        }

        // Tier 1: On-device Foundation Model
        if let aiInsight = await generateDayInsightAI(context: context) {
            return aiInsight
        }
        // Tier 2: Groq API (cloud fallback — skipped when offline)
        if await NetworkMonitor.shared.isConnected,
           let groqInsight = await generateDayInsightGroq(context: context) {
            return groqInsight
        }
        // Tier 3: Deterministic rule-based fallback
        return generateDayInsightRuleBased(context: context)
    }
    
    func overallHeadline(context: OverallInsightContext) async -> String {
        // Tier 1: On-device Foundation Model
        if let aiHeadline = await generateOverallHeadlineAI(context: context) {
            return aiHeadline
        }
        // Tier 2: Groq API (cloud fallback — skipped when offline)
        if await NetworkMonitor.shared.isConnected,
           let groqHeadline = await generateOverallHeadlineGroq(context: context) {
            return groqHeadline
        }
        // Tier 3: Deterministic rule-based fallback
        return generateOverallHeadlineRuleBased(context: context)
    }

    // MARK: - Session-Specific Insight (for Reading Result screen)

    /// Generates an insight about a single reading session, not the whole day.
    func sessionInsight(report: StutterJSONReport) async -> String {
        let prompt = buildSessionPrompt(report: report)

        // Tier 1: On-device Foundation Model
        let model = SystemLanguageModel.default
        if model.availability == .available {
            let session = LanguageModelSession(model: model, instructions: sessionSystemInstruction)
            do {
                let response = try await session.respond(to: prompt)
                let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                if isValidInsight(text) { return text }
            } catch {
                print("InsightEngine: Session insight Foundation Model failed — \(error.localizedDescription)")
            }
        }

        // Tier 2: Groq API (skipped when offline)
        if await NetworkMonitor.shared.isConnected,
           let groqResult = await GroqService.shared.generate(
               systemInstruction: sessionSystemInstruction, prompt: prompt
           ), isValidInsight(groqResult) {
            return groqResult
        }

        // Tier 3: Rule-based fallback
        return sessionInsightRuleBased(report: report)
    }

    private let sessionSystemInstruction = """
    You are a supportive speech therapy coach inside an app called Spasht.

    Rules:
    - Exactly 2 sentences, under 25 words total.
    - Speak about THIS specific reading session only.
    - Warm, encouraging, never clinical.
    - Do not use any numbers or percentages.
    - No emojis, no markdown, no bullet points.
    - Output ONLY the insight text.
    """

    private func buildSessionPrompt(report: StutterJSONReport) -> String {
        var parts: [String] = []
        parts.append("Fluency score: \(report.fluencyScore)/100.")
        parts.append("Block percentage: \(Int(report.percentages.blocks))%.")
        parts.append("Accuracy: \(Int(report.percentages.correct))%.")
        parts.append("Repetition percentage: \(Int(report.percentages.repetition))%.")
        parts.append("Prolongation percentage: \(Int(report.percentages.prolongation))%.")

        if !report.stutteredWords.isEmpty {
            let topWords = report.stutteredWords.prefix(5).joined(separator: ", ")
            parts.append("Troubled words: \(topWords).")
        } else {
            parts.append("No stuttered words detected.")
        }

        return """
        Here is the user's data for this specific reading session:

        \(parts.joined(separator: "\n"))

        Write a short, warm, specific insight about this session. \
        Maximum 2 sentences. Do not include any numbers.
        """
    }

    private func sessionInsightRuleBased(report: StutterJSONReport) -> String {
        if report.stutteredWords.isEmpty && report.fluencyScore >= 90 {
            return "Excellent reading! Your speech was smooth and confident throughout."
        }
        if report.percentages.blocks > 30 {
            return "Blocks were your main challenge this session. Try slow, deliberate starts on each sentence."
        }
        if report.percentages.correct < 60 {
            return "Take your time with each sentence. Steady pacing helps build confidence."
        }
        if report.fluencyScore >= 80 {
            return "Strong session! Your fluency shows real control. Keep building on this momentum."
        }
        if report.fluencyScore >= 50 {
            return "Good effort! Every session strengthens your speaking skills."
        }
        return "You showed up and practiced — that's what counts. Keep going!"
    }

    private func isValidInsight(_ text: String) -> Bool {
        let words = text.split { $0.isWhitespace }
        // The prompt asks for < 15 words, so let's allow up to 30 just to be safe.
        return !words.isEmpty && words.count <= 30
    }

    
    private func generateDayInsightAI(context: DayInsightContext) async -> String? {
        let model = SystemLanguageModel.default
        guard model.availability == .available else {
            print("InsightEngine: Model not available")
            return nil
        }

        // Fresh session each time — insights are independent, not a conversation
        let session = LanguageModelSession(model: model, instructions: dayInsightInstructions)
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
        let model = SystemLanguageModel.default
        guard model.availability == .available else {
            print("InsightEngine: Model not available")
            return nil
        }

        let session = LanguageModelSession(model: model, instructions: dayInsightInstructions)
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

    private let dayInsightInstructions = """
    You are a supportive speech therapy coach.

    Rules:
    - Exactly 2 sentences, under 25 words total.
    - Do not use any numbers or percentages in your response.
    - Warm and encouraging, never clinical.
    - No emojis, no markdown, no bullet points.
    - If letter improvement data exists, lead with it.
    - Output ONLY the insight text.
    """

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

        // Only include growth data when there is a real previous day to compare against
        if context.hasPreviousDay {
            if context.fluencyGrowth > 0 {
                parts.append("Fluency improved by \(String(format: "%.1f", context.fluencyGrowth)) points vs yesterday.")
            } else if context.fluencyGrowth < 0 {
                parts.append("Fluency was \(String(format: "%.1f", abs(context.fluencyGrowth))) points lower than yesterday.")
            } else {
                parts.append("Fluency was similar to yesterday.")
            }
        } else {
            parts.append("No previous day data available — do not make any day-over-day comparisons.")
        }

        parts.append("Sessions completed today: \(context.sessionCount).")

        return """
            Here is the user's speech practice data for today:

            \(parts.joined(separator: "\n"))

            Write a short, warm, specific insight for this user about their day. \
            Maximum 2 sentences. Do not include any numbers. \
            If letter improvement data is present, lead with that. \
            Do not make comparisons to previous days unless the data explicitly shows previous day data.
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

    // MARK: - Tier 2: Groq API Fallback

    private let groqSystemInstruction = """
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

    private func generateDayInsightGroq(context: DayInsightContext) async -> String? {
        let prompt = buildDayPrompt(context: context)

        guard let text = await GroqService.shared.generate(
            systemInstruction: groqSystemInstruction,
            prompt: prompt
        ) else {
            print("InsightEngine: Groq day insight failed, falling back to rules")
            return nil
        }

        // Apply the same validation as the Foundation Model path
        guard isValidInsight(text) else {
            print("InsightEngine: Groq day insight failed validation")
            return nil
        }

        return text
    }

    private func generateOverallHeadlineGroq(context: OverallInsightContext) async -> String? {
        let prompt = buildOverallPrompt(context: context)

        guard let text = await GroqService.shared.generate(
            systemInstruction: groqSystemInstruction,
            prompt: prompt
        ) else {
            print("InsightEngine: Groq headline failed, falling back to rules")
            return nil
        }

        guard !text.isEmpty, text.count < 150 else {
            print("InsightEngine: Groq headline failed validation")
            return nil
        }

        return text
    }

    // MARK: - Tier 3: Rule-Based Fallback — Day Insight

    func generateDayInsightRuleBased(context: DayInsightContext) -> String {

        // 1. Letter improvement — most personal signal
        if !context.topImprovedLetters.isEmpty {
            let top = context.topImprovedLetters.prefix(2)
            let lettersStr: String
            if top.count == 1 {
                lettersStr = "'\(top[0].letter)'"
            } else {
                lettersStr = "'\(top[0].letter)' and '\(top[1].letter)'"
            }
            return "Your \(lettersStr) sounds have improved today! Keep focusing on those and you'll feel the difference."
        }

        // 2. High blocks
        if context.avgBlock > 30 {
            return "Blocks are your main challenge today. Try slow, deliberate starts on each sentence."
        }

        // 3. Low accuracy
        if context.avgAccuracy < 60 {
            return "Focus on shorter passages and give yourself time to breathe."
        }

        // 4. Fluency jump — only when there is a real previous day to compare against
        if context.hasPreviousDay && context.fluencyGrowth > 5 {
            return "Great progress! Your fluency jumped today. Keep that momentum!"
        }

        // 5. Fluency dip — only when there is a real previous day to compare against
        if context.hasPreviousDay && context.fluencyGrowth < -5 {
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
