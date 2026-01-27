import Foundation
import Speech

struct StutterJSONReport: Codable {
    let fluencyScore: Int
    let duration: String
    let stutteredWords: [String]
    let blocks: [String]
    let breakdown: StutterBreakdown
    let percentages: StutterPercentages
    let letterAnalysis: [String: Int]
}

struct StutterBreakdown: Codable {
    let repetition: [String]
    let prolongation: [String]
    let blocks: Int
}

struct StutterPercentages: Codable {
    let repetition: Double
    let prolongation: Double
    let blocks: Double
    let correct: Double
}

class StutterAnalyzer {
    
    enum Operation {
        case match, insert, delete, substitute
    }

    static func analyze(reference: String, transcript: String, segments: [SFTranscriptionSegment], duration: TimeInterval) -> String {
        
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let durationString = minutes > 0 ? "\(minutes) min \(seconds) sec" : "\(seconds) sec"
        
        if transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return emptyReport(duration: durationString)
        }
        
        let refWords = normalize(reference)
        let transWords = normalize(transcript)
        
        // --- DISPLAY FILTER SETUP ---
        // Create a set of words that actually exist in the original paragraph
        let paragraphWordsWhitelist = Set(refWords)
        
        let ops = levenshteinAlignment(ref: refWords, hyp: transWords)
        
        var correctCount = 0
        var rawRepetitions: [String] = []
        var rawProlongations: [String] = []
        var rawAllStutteredWords: [String] = []
        
        var refIndex = 0
        var transIndex = 0
        
        for op in ops {
            switch op {
            case .match:
                correctCount += 1
                refIndex += 1; transIndex += 1
            case .substitute:
                if refIndex < refWords.count {
                    let word = refWords[refIndex]
                    rawProlongations.append(word)
                    rawAllStutteredWords.append(word)
                }
                refIndex += 1; transIndex += 1
            case .insert:
                let insertedWord = transWords[transIndex]
                var isRepetition = false
                if refIndex < refWords.count && insertedWord == refWords[refIndex] { isRepetition = true }
                else if transIndex > 0 && insertedWord == transWords[transIndex - 1] { isRepetition = true }
                
                let targetWord = (refIndex < refWords.count) ? refWords[refIndex] : insertedWord
                if isRepetition { rawRepetitions.append(targetWord) }
                else { rawProlongations.append(targetWord) }
                rawAllStutteredWords.append(targetWord)
                transIndex += 1
            case .delete:
                refIndex += 1
            }
        }
        
        // --- FILTERING FOR DISPLAY ---
        // We keep the logic above the same, but only "Display" words that are in the original paragraph
        let stutteredWords = rawAllStutteredWords.filter { paragraphWordsWhitelist.contains($0) }
        let repetitions = rawRepetitions.filter { paragraphWordsWhitelist.contains($0) }
        let prolongations = rawProlongations.filter { paragraphWordsWhitelist.contains($0) }

        // --- BLOCK LOGIC (Unchanged) ---
        var detectedBlocks: [String] = []
        let validSegments = segments.filter { !$0.substring.trimmingCharacters(in: .whitespaces).isEmpty }
        let warmUpCount = 2
        let sensitivityMultiplier = 1.5
        let minimumPauseDuration = 0.9
        
        if validSegments.count > warmUpCount {
            var totalGapDuration: TimeInterval = 0
            var gapCount = 0
            for i in 1..<validSegments.count {
                let previousEnd = validSegments[i-1].timestamp + validSegments[i-1].duration
                let currentStart = validSegments[i].timestamp
                let gap = currentStart - previousEnd
                if gap > 0 && gap < 1.5 {
                    totalGapDuration += gap
                    gapCount += 1
                }
            }
            let averageGap = gapCount > 0 ? (totalGapDuration / Double(gapCount)) : 0.1
            let blockThreshold = max(minimumPauseDuration, averageGap * sensitivityMultiplier)
            
            for i in warmUpCount..<validSegments.count {
                let previousEnd = validSegments[i-1].timestamp + validSegments[i-1].duration
                let currentStart = validSegments[i].timestamp
                let gap = currentStart - previousEnd
                if gap > blockThreshold {
                    let rawWord = validSegments[i].substring.lowercased().trimmingCharacters(in: .punctuationCharacters)
                    // Only display the block if the word is actually in the paragraph
                    if paragraphWordsWhitelist.contains(rawWord) {
                        let durationStr = String(format: "%.2f", gap)
                        detectedBlocks.append("\(rawWord) (Pause: \(durationStr)s)")
                    }
                }
            }
        }
        
        let totalSpoken = Double(transWords.count)
        var score = 0
        if totalSpoken > 0 {
            let penalty = Double(detectedBlocks.count) * 2.0
            let rawScore = (Double(correctCount) / totalSpoken) * 100
            score = Int(max(0, rawScore - penalty))
        }
        
        let repPercent = totalSpoken > 0 ? (Double(repetitions.count) / totalSpoken) * 100 : 0.0
        let proPercent = totalSpoken > 0 ? (Double(prolongations.count) / totalSpoken) * 100 : 0.0
        let blkPercent = totalSpoken > 0 ? (Double(detectedBlocks.count) / totalSpoken) * 100 : 0.0
        let corPercent = totalSpoken > 0 ? (Double(correctCount) / totalSpoken) * 100 : 0.0
        
        var letterCounts: [String: Int] = [:]
        for word in stutteredWords {
            if let firstChar = word.first { letterCounts[String(firstChar).uppercased(), default: 0] += 1 }
        }
        
        let reportData = StutterJSONReport(
            fluencyScore: max(0, score),
            duration: durationString,
            stutteredWords: stutteredWords,
            blocks: detectedBlocks,
            breakdown: StutterBreakdown(repetition: repetitions, prolongation: prolongations, blocks: detectedBlocks.count),
            percentages: StutterPercentages(
                repetition: (repPercent * 100).rounded() / 100,
                prolongation: (proPercent * 100).rounded() / 100,
                blocks: (blkPercent * 100).rounded() / 100,
                correct: (corPercent * 100).rounded() / 100
            ),
            letterAnalysis: letterCounts
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let jsonData = try? encoder.encode(reportData), let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        } else { return "{ \"error\": \"Failed to encode JSON\" }" }
    }
    
    private static func normalize(_ text: String) -> [String] {
        return text.lowercased().components(separatedBy: CharacterSet.punctuationCharacters.union(.whitespacesAndNewlines)).filter { !$0.isEmpty }
    }
    
    // Memory-Optimized Levenshtein (Prevents crashes on long paragraphs)
    private static func levenshteinAlignment(ref: [String], hyp: [String]) -> [Operation] {
        let n = ref.count; let m = hyp.count
        if n == 0 { return Array(repeating: .insert, count: m) }
        if m == 0 { return Array(repeating: .delete, count: n) }
        
        var matrix = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in 0...n { matrix[i][0] = i }
        for j in 0...m { matrix[0][j] = j }
        for i in 1...n {
            for j in 1...m {
                if ref[i - 1] == hyp[j - 1] { matrix[i][j] = matrix[i - 1][j - 1] }
                else { matrix[i][j] = min(matrix[i - 1][j - 1] + 1, min(matrix[i - 1][j] + 1, matrix[i][j - 1] + 1)) }
            }
        }
        var i = n, j = m, ops: [Operation] = []
        while i > 0 || j > 0 {
            if i > 0 && j > 0 && ref[i - 1] == hyp[j - 1] { ops.append(.match); i -= 1; j -= 1 }
            else if i > 0 && j > 0 && matrix[i][j] == matrix[i - 1][j - 1] + 1 { ops.append(.substitute); i -= 1; j -= 1 }
            else if i > 0 && matrix[i][j] == matrix[i - 1][j] + 1 { ops.append(.delete); i -= 1 }
            else { ops.append(.insert); j -= 1 }
        }
        return ops.reversed()
    }
    
    private static func emptyReport(duration: String) -> String {
        return """
        {
          "fluencyScore": 0,
          "duration": "\(duration)",
          "stutteredWords": [],
          "blocks": [],
          "breakdown": { "repetition": [], "prolongation": [], "blocks": 0 },
          "percentages": { "repetition": 0, "prolongation": 0, "blocks": 0, "correct": 0 },
          "letterAnalysis": {}
        }
        """
    }
}
