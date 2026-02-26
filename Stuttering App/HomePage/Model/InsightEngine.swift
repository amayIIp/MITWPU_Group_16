//
//  InsightEngine.swift
//  Spasht
//
//  Generates personalized insights using Apple's on-device Foundation model.
//  Falls back to rule-based generation if the model is unavailable or fails.
//
//  Requirements: iOS 18.0+ (Apple Intelligence device or simulator)
//  Import: FoundationModels (add to target — no API key needed, fully on-device)
//

import Foundation
import FoundationModels

// MARK: - Input Context

/// Everything the engine needs to generate a Day insight.
struct DayInsightContext {
    let avgFluency: Double
    let avgBlock: Double
    let avgAccuracy: Double
    let fluencyGrowth: Double           // vs yesterday, in score points
    let improvementPercent: Double      // vs yesterday, as %
    let sessionCount: Int
    let topImprovedLetters: [(letter: String, improvementPct: Double)]   // top 2 max, already filtered ≥10%
}

/// Everything the engine needs to generate an Overall Progress headline.
struct OverallInsightContext {
    let fluencyGrowthPercent: Double    // first session → latest session
    let avgAccuracy: Double
    let avgBlock: Double
    let streak: Int
    let weekOverWeekImprovementPct: Double
    let daysPracticed: Int
    let mostCommonStutterType: String   // "repetition" | "prolongation" | "block"
}

// MARK: - InsightEngine

actor InsightEngine {

    static let shared = InsightEngine()

    // Reuse a single session — creating one per call is wasteful
    private var session: LanguageModelSession?

    private init() {}

    // MARK: - Public API

    /// Generates a Day insight. Foundation model first, rule-based fallback.
    func dayInsight(context: DayInsightContext) async -> String {
        if let aiInsight = await generateDayInsightAI(context: context) {
            return aiInsight
        }
        return generateDayInsightRuleBased(context: context)
    }

    /// Generates an Overall Progress headline. Foundation model first, rule-based fallback.
    func overallHeadline(context: OverallInsightContext) async -> String {
        if let aiHeadline = await generateOverallHeadlineAI(context: context) {
            return aiHeadline
        }
        return generateOverallHeadlineRuleBased(context: context)
    }

    // MARK: - Foundation Model — Day Insight

    
    private func generateDayInsightAI(context: DayInsightContext) async -> String? {
        
        guard let session = getOrCreateSession() else {
            return nil
        }
        
        let prompt = buildDayPrompt(context: context)
        
        do {
            let response = try await session.respond(to: prompt)
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !text.isEmpty, text.count < 200 else {
                return nil
            }
            
            return text
        } catch {
            print("InsightEngine: Model failed — \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Foundation Model — Overall Headline

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

    // MARK: - Session Management

    
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
        You are a supportive speech therapy coach inside an app called Spasht.
        Your job is to write short, warm, motivating insights for users who stutter
        and are working on improving their speech fluency.

        Rules:
        - Maximum 2 sentences. Never more.
        - Be specific — use the actual numbers provided.
        - Warm and encouraging, never clinical or cold.
        - No emojis, no markdown, no bullet points.
        - If there is letter improvement data, always lead with that.
        - End with a brief forward-looking nudge when possible.
        - Output ONLY the insight text.
        """
        
        let newSession = LanguageModelSession(
            model: model,
            instructions: instructions
        )
        
        session = newSession
        return newSession
    }

    // MARK: - Prompt Builders

    private func buildDayPrompt(context: DayInsightContext) -> String {

        var parts: [String] = []

        // Letter improvement (most personal — always include if present)
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
            Maximum 2 sentences. Use the actual numbers. \
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
            their overall progress. Be specific to their numbers. \
            Output only the sentence — no quotes, no label.
            """
    }

    // MARK: - Rule-Based Fallback — Day Insight

    func generateDayInsightRuleBased(context: DayInsightContext) -> String {

        // 1. Letter improvement — most personal
        if !context.topImprovedLetters.isEmpty {
            let top    = context.topImprovedLetters.prefix(2)
            let avgPct = top.map(\.improvementPct).reduce(0, +) / Double(top.count)

            let lettersStr: String
            if top.count == 1 {
                lettersStr = "'\(top[0].letter)'"
            } else {
                lettersStr = "'\(top[0].letter)' and '\(top[1].letter)'"
            }
            return "Your \(lettersStr) sounds have improved \(Int(avgPct))% today!!"
        }

        // 2. High blocks
        if context.avgBlock > 30 {
            return "Blocks are your main challenge today (\(Int(context.avgBlock))%). Try slow, deliberate starts on each sentence."
        }

        // 3. Low accuracy
        if context.avgAccuracy < 60 {
            return "Accuracy was lower today (\(Int(context.avgAccuracy))%). Focus on shorter passages and give yourself time to breathe."
        }

        // 4. Fluency jump
        if context.fluencyGrowth > 5 {
            return "Great progress! Your fluency jumped \(String(format: "%.1f", context.fluencyGrowth)) points today. Keep that momentum!"
        }

        // 5. Fluency dip
        if context.fluencyGrowth < -5 {
            return "Fluency dipped a little today — that's completely normal. A gentle warm-up before your next session will help."
        }

        // 6. High session count
        if context.sessionCount >= 3 {
            return "Solid consistency — \(context.sessionCount) sessions today! Multiple short sessions are one of the best ways to improve."
        }

        // 7. High score
        if context.avgFluency >= 80 {
            return "Excellent day! A fluency score of \(Int(context.avgFluency)) shows real control. Challenge yourself with a harder passage tomorrow."
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
