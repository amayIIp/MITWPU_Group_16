import Foundation
import Speech

// MARK: - Report Models

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

// MARK: - Analyzer

class StutterAnalyzer {

    enum Operation {
        case match, insert, delete, substitute
    }

    static func analyze(
        reference: String,
        transcript: String,
        segments: [SFTranscriptionSegment],
        duration: TimeInterval
    ) -> String {

        // ── Duration string ───────────────────────────────────────────────────
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let durationString = minutes > 0 ? "\(minutes) min \(seconds) sec" : "\(seconds) sec"

        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return emptyReport(duration: durationString)
        }

        // ── Normalize ─────────────────────────────────────────────────────────
        // Unicode normalization (.precomposedStringWithCanonicalMapping) ensures
        // accented / composed characters compare correctly across locales.
        let refWords   = normalize(reference)
        let transWords = normalize(transcript)

        // Allowlist: only surface stutter events on words that exist in the
        // reference paragraph — prevents filler sounds / ASR artefacts leaking in.
        let paragraphWordsAllowlist = Set(refWords)

        // ── Levenshtein alignment ─────────────────────────────────────────────
        let ops = levenshteinAlignment(ref: refWords, hyp: transWords)

        // Calculate the furthest point the user successfully read
        var tempRefIndex = 0
        var lastMatchRefIndex = -1
        for op in ops {
            switch op {
            case .match:
                lastMatchRefIndex = tempRefIndex
                tempRefIndex += 1
            case .substitute, .delete:
                tempRefIndex += 1
            case .insert:
                break
            }
        }

        var correctCount      = 0
        var rawRepetitions: [String] = []
        var rawProlongations: [String] = []
        var rawAllStuttered: [String] = []

        var refIndex   = 0
        var transIndex = 0

        for op in ops {
            switch op {

            case .match:
                correctCount += 1
                refIndex   += 1
                transIndex += 1

            case .substitute:
                // Speaker said a different word → no repetition/block model → prolongation.
                if refIndex < refWords.count {
                    let word = refWords[refIndex]
                    if refIndex <= lastMatchRefIndex + 1 {
                        rawProlongations.append(word)
                        rawAllStuttered.append(word)
                    }
                }
                refIndex   += 1
                transIndex += 1

            case .insert:
                let insertedWord = transWords[transIndex]

                // ── REPETITION DETECTION ──────────────────────────────────────
                // FIX (Bug #2): Only ONE condition is kept.
                //
                // REMOVED condition → insertedWord == refWords[refIndex]
                //   This was a false-positive trigger: it marked a word as a
                //   repetition simply because it matched the *next* reference
                //   word. That is not a stutter; the speaker was just slightly
                //   shifted. It produced phantom repetitions.
                //
                // KEPT condition → insertedWord == transWords[transIndex - 1]
                //   This is the only true repetition signal: the speaker
                //   literally just said the identical word immediately before
                //   this one (e.g. "the the cat").
                let isRepetition = transIndex > 0 && insertedWord == transWords[transIndex - 1]

                let targetWord: String
                if isRepetition {
                    targetWord = insertedWord   // the word that was actually repeated
                } else {
                    // Extra word that isn't a repetition → prolongation bucket.
                    targetWord = refIndex < refWords.count ? refWords[refIndex] : insertedWord
                }

                if refIndex <= lastMatchRefIndex + 1 {
                    if isRepetition {
                        rawRepetitions.append(targetWord)
                    } else {
                        rawProlongations.append(targetWord)
                    }
                    rawAllStuttered.append(targetWord)
                }
                transIndex += 1

            case .delete:
                // Speaker skipped a reference word — lowers fluency, not a stutter event.
                refIndex += 1
            }
        }

        // Apply case-insensitive whitelist filter for repetitions and prolongations.
        let repetitions     = rawRepetitions.filter { paragraphWordsAllowlist.contains($0.lowercased()) }
        let prolongations   = rawProlongations.filter { paragraphWordsAllowlist.contains($0.lowercased()) }

        // ── BLOCK DETECTION ───────────────────────────────────────────────────
        // A "block" = a word the speaker took significantly longer to say than
        // their natural pace for a word of that length.
        //
        // WHY LENGTH-NORMALISATION:
        //   A raw duration threshold (even adaptive ones like avgDuration * 1.8)
        //   is word-length-blind. "Encyclopedia" spoken fluently in 0.6 s will
        //   always exceed any threshold derived from short words like "the"
        //   (0.15 s), producing false positives no matter where you set the floor.
        //
        //   The correct signal is duration-per-character (a syllable proxy):
        //     "the"          0.15 s / 3 chars = 0.050 s/char  ← normal
        //     "encyclopedia" 0.60 s / 12 chars = 0.050 s/char ← normal, NOT a block
        //     "encyclopedia" (blocked) 1.20 s / 12 chars = 0.100 s/char ← 2× ratio → block
        //
        //   By comparing each word's s/char ratio against the speaker's own
        //   average s/char ratio, long words and short words are held to the
        //   same proportional standard.
        //
        // MULTIPLIER (1.8×): a word must take 80% longer per character than the
        //   speaker's average before it is flagged. Tune to adjust sensitivity.

        var detectedBlocks: [String] = []

        // Filter out near-zero artefacts (breath puffs, silence tokens < 50 ms).
        let validSegments = segments.filter { $0.duration > 0.05 }

        if !validSegments.isEmpty {

            // Build per-segment duration-per-character ratios.
            // Guard against empty substrings with a minimum length of 1.
            let ratios = validSegments.map { seg -> Double in
                let charCount = max(1, seg.substring.trimmingCharacters(in: .punctuationCharacters).count)
                return seg.duration / Double(charCount)
            }

            let avgRatio       = ratios.reduce(0, +) / Double(ratios.count)
            let blockRatioThreshold = avgRatio * 1.8   // adaptive, length-normalised

            for (segment, ratio) in zip(validSegments, ratios) where ratio > blockRatioThreshold {
                let rawWord = segment.substring
                    .lowercased()
                    .trimmingCharacters(in: .punctuationCharacters)

                if paragraphWordsAllowlist.contains(rawWord) {
                    let durationStr = String(format: "%.2f", segment.duration)
                    detectedBlocks.append("\(rawWord) (Duration: \(durationStr)s)")
                    rawAllStuttered.append(rawWord)
                }
            }
        }

        // ── DEDUPLICATE TROUBLE WORDS ─────────────────────────────────────────
        let rawFiltered = rawAllStuttered.filter { paragraphWordsAllowlist.contains($0.lowercased()) }
        var uniqueStuttered = [String]()
        var seenWords = Set<String>()
        for word in rawFiltered {
            let lower = word.lowercased()
            if !seenWords.contains(lower) {
                seenWords.insert(lower)
                uniqueStuttered.append(word)
            }
        }
        let stutteredWords = uniqueStuttered

        // ── FLUENCY SCORE ─────────────────────────────────────────────────────
        // Weighted penalty against reference word count so score is independent
        // of how much the speaker repeated / inserted.
        //   Repetition   = 1.0 pt penalty per event  (mild)
        //   Prolongation = 1.5 pt penalty per event  (moderate)
        //   Block        = 2.0 pt penalty per event  (severe)
        let totalRefWords = Double(refWords.count)
        var score = 0
        if totalRefWords > 0 {
            let penalty = (Double(repetitions.count)   * 1.0)
                        + (Double(prolongations.count) * 1.5)
                        + (Double(detectedBlocks.count) * 2.0)
            score = Int(max(0, 100 - (penalty / totalRefWords * 100)))
        }

        // ── PERCENTAGES ───────────────────────────────────────────────────────
        let totalSpoken = Double(transWords.count)
        let repPercent  = totalSpoken > 0 ? (Double(repetitions.count)    / totalSpoken) * 100 : 0.0
        let proPercent  = totalSpoken > 0 ? (Double(prolongations.count)  / totalSpoken) * 100 : 0.0
        let blkPercent  = totalSpoken > 0 ? (Double(detectedBlocks.count) / totalSpoken) * 100 : 0.0
        let corPercent  = totalSpoken > 0 ? (Double(correctCount)          / totalSpoken) * 100 : 0.0

        // ── LETTER ANALYSIS ───────────────────────────────────────────────────
        var letterCounts: [String: Int] = [:]
        for word in stutteredWords {
            if let firstChar = word.first {
                letterCounts[String(firstChar).uppercased(), default: 0] += 1
            }
        }

        // ── BUILD JSON ────────────────────────────────────────────────────────
        let reportData = StutterJSONReport(
            fluencyScore: score,
            duration: durationString,
            stutteredWords: stutteredWords,
            blocks: detectedBlocks,
            breakdown: StutterBreakdown(
                repetition: repetitions,
                prolongation: prolongations,
                blocks: detectedBlocks.count
            ),
            percentages: StutterPercentages(
                repetition: repPercent.rounded(toPlaces: 2),
                prolongation: proPercent.rounded(toPlaces: 2),
                blocks: blkPercent.rounded(toPlaces: 2),
                correct: corPercent.rounded(toPlaces: 2)
            ),
            letterAnalysis: letterCounts
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let jsonData    = try? encoder.encode(reportData),
           let jsonString  = String(data: jsonData, encoding: .utf8) {
            return jsonString
        } else {
            return "{ \"error\": \"Failed to encode JSON\" }"
        }
    }

    // MARK: - Helpers

    /// Lowercases, Unicode-normalizes, and splits on punctuation + whitespace.
    private static func normalize(_ text: String) -> [String] {
        return text
            .precomposedStringWithCanonicalMapping       // ← Unicode normalization (from v3)
            .lowercased()
            .components(separatedBy: CharacterSet.punctuationCharacters.union(.whitespacesAndNewlines))
            .filter { !$0.isEmpty }
    }

    /// Full-matrix Levenshtein with traceback. Returns the alignment operation
    /// sequence between `ref` and `hyp`.
    private static func levenshteinAlignment(ref: [String], hyp: [String]) -> [Operation] {
        let n = ref.count, m = hyp.count
        if n == 0 { return Array(repeating: .insert, count: m) }
        if m == 0 { return Array(repeating: .delete, count: n) }

        var matrix = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in 0...n { matrix[i][0] = i }
        for j in 0...m { matrix[0][j] = j }

        for i in 1...n {
            for j in 1...m {
                if ref[i-1] == hyp[j-1] {
                    matrix[i][j] = matrix[i-1][j-1]
                } else {
                    matrix[i][j] = min(matrix[i-1][j-1] + 1,
                                   min(matrix[i-1][j]   + 1,
                                       matrix[i][j-1]   + 1))
                }
            }
        }

        var i = n, j = m
        var ops: [Operation] = []
        while i > 0 || j > 0 {
            if i > 0 && j > 0 && ref[i-1] == hyp[j-1] {
                ops.append(.match);      i -= 1; j -= 1
            } else if i > 0 && j > 0 && matrix[i][j] == matrix[i-1][j-1] + 1 {
                ops.append(.substitute); i -= 1; j -= 1
            } else if i > 0 && matrix[i][j] == matrix[i-1][j] + 1 {
                ops.append(.delete);     i -= 1
            } else {
                ops.append(.insert);     j -= 1
            }
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

// MARK: - Double Extension (from v3)

extension Double {
    /// Rounds to `places` decimal places.
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
