import Foundation

// MARK: - Report Models

struct StutterJSONReport: Codable {
    let fluencyScore: Int
    let duration: String
    /// Words showing a stuttering-like disfluency: repetitions, prolongations
    /// and blocks. Misreadings are deliberately excluded — see `misreadWords`.
    let stutteredWords: [String]
    /// Words read differently from the paragraph, or not recognised clearly.
    /// Useful reading feedback, but not a clinical disfluency: at word level
    /// there is no way to tell a genuine misreading from a recogniser error.
    let misreadWords: [String]
    let blocks: [String]
    let breakdown: StutterBreakdown
    let percentages: StutterPercentages
    let letterAnalysis: [String: Int]
    let reading: ReadingAccuracy
    /// "typical", "mild", "moderate" or "severe", banded on %SS.
    let severity: String
    /// How far the transcript can be trusted as an index into the paragraph:
    /// "high", "moderate" or "low". Low means the figures are indicative and
    /// should be presented as such.
    let confidence: String
    /// `false` when no acoustic envelope was available, so blocks and
    /// prolongations could not be measured and only repetitions contribute.
    let acousticAnalysisRan: Bool
    /// `false` when the session was too short to draw a conclusion from.
    let isReliable: Bool
    /// Why the report says what it says: counts and measurements from each
    /// stage of the pipeline. Surfaced behind a long press on the score ring
    /// so a session that behaves oddly on a device can be inspected instead
    /// of guessed at.
    let diagnostics: [String: String]
}

struct StutterBreakdown: Codable {
    let repetition: [String]
    /// Sounds held abnormally long, measured from the audio envelope.
    let prolongation: [String]
    let misread: [String]
    let blocks: Int
}

struct StutterPercentages: Codable {
    /// Events per 100 attempted words.
    let repetition: Double
    let prolongation: Double
    let misread: Double
    let blocks: Double
    /// Share of attempted words read correctly.
    let correct: Double
    /// Percent syllables stuttered — the clinical measure.
    let stutteredSyllables: Double
}

/// How much of the paragraph was read, and how closely.
struct ReadingAccuracy: Codable {
    let referenceWords: Int
    /// Reference words the reader actually reached. Everything past the point
    /// where they stopped is excluded, so ending early is not an error.
    let attemptedWords: Int
    let matchedWords: Int
    let spokenWords: Int
    /// Words skipped *while reading*, as opposed to never reached.
    let skippedWords: Int
    /// Words the reader audibly said that the recogniser did not transcribe.
    /// Excluded from every judgement rather than counted against them.
    let unrecognisedWords: Int
    /// Reference words about which a judgement was possible: reached, minus
    /// the ones the recogniser dropped. The denominator for `completeness`
    /// and for every rate in `StutterPercentages`.
    let judgeableWords: Int
    /// Extra words spoken inside the attempted region that were not
    /// repetitions — backtracking, re-reads and filler.
    let extraWords: Int
    let syllablesAttempted: Int
    /// matched / judgeable
    let completeness: Double
    /// matched / spoken
    let accuracy: Double
    /// attempted / reference — how far through the paragraph they got.
    let coverage: Double
}

// MARK: - Analyzer

class StutterAnalyzer {

    enum Operation: Equatable {
        case match, insert, delete, substitute
    }

    // MARK: Tuning

    /// Decay constant for the fluency term, in %SS.
    ///
    /// The previous `1 - %SS/12` ramp hit zero at 12% SS and stayed there, so
    /// improving detection began handing severe readers a flat 0 — the one
    /// session where a score can do real harm. Exponential decay never
    /// reaches zero and maps cleanly onto the severity bands:
    /// typical 81-100, mild 61-81, moderate 42-61, severe below 42.
    private static let scoreDecayRate = 14.0
    /// Below this many syllables a session cannot support a conclusion.
    private static let minimumReliableSyllables = 30
    /// How far back a trailing aligned word may look for company before it is
    /// treated as a stray match rather than the end of the reading.
    private static let alignmentSupportWindow = 6

    /// Produces the session report as JSON.
    ///
    /// - Parameters:
    ///   - segments: word timings **from the same recogniser that produced
    ///     `transcript`**. Pass an empty array when the transcript came from a
    ///     different engine: timings from one recogniser cannot be indexed
    ///     against another's words, so timing analysis is skipped rather than
    ///     run on mismatched data.
    ///   - envelope: the session's acoustic envelope, on the same clock as
    ///     `segments`. Blocks and prolongations are measured from it. Pass
    ///     `nil` when unavailable — the report then says so through
    ///     `acousticAnalysisRan` instead of quietly reporting zero events.
    static func analyze(
        reference: String,
        transcript: String,
        segments: [SpeechSegment],
        envelope: SpeechEnvelope? = nil,
        duration: TimeInterval
    ) -> String {

        // ── Duration string ───────────────────────────────────────────────────
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let durationString = minutes > 0 ? "\(minutes) min \(seconds) sec" : "\(seconds) sec"

        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return encode(emptyReport(duration: durationString))
        }

        // ── Normalize ─────────────────────────────────────────────────────────
        // Both sides pass through the same folding: one spelling variety,
        // punctuation stripped, numbers spelled out. See `TextNormalizer`.
        let (refWords, refEndsClause) = TextNormalizer.tokenizeWithBoundaries(reference)
        let (transWords, wordToSegment) = spokenStream(transcript: transcript, segments: segments)

        guard !refWords.isEmpty, !transWords.isEmpty else {
            return encode(emptyReport(duration: durationString))
        }

        let refChars   = refWords.map { Array($0) }
        let transChars = transWords.map { Array($0) }

        // Allowlist: only surface stutter events on words that exist in the
        // reference paragraph — prevents filler sounds / ASR artefacts leaking in.
        let paragraphWordsAllowlist = Set(refWords)

        // ── Alignment ─────────────────────────────────────────────────────────
        let ops = alignment(ref: refChars, hyp: transChars)

        var tally = tallyAlignment(
            ops: ops,
            lastAttemptedOpIndex: lastAttemptedOpIndex(in: ops),
            refWords: refWords,
            transWords: transWords,
            transChars: transChars
        )
        resolveUnalignedWords(
            in: &tally,
            refWords: refWords,
            segments: segments,
            wordToSegment: wordToSegment,
            envelope: envelope
        )

        // Repetitions come from the spoken stream, so they need the allowlist
        // to keep filler and recogniser artefacts out. Misreadings are already
        // reference words by construction.
        let filteredRepetitions = tally.repetitions.filter { paragraphWordsAllowlist.contains($0) }
        let filteredMisreadings = tally.misreadings

        // ── BLOCKS AND PROLONGATIONS ──────────────────────────────────────────
        let timingsAreUsable = segmentTimingsAreUsable(segments)
        let acousticAnalysisRan = timingsAreUsable && !(envelope?.isEmpty ?? true)

        var acoustic = AcousticFindings()
        if acousticAnalysisRan, let envelope {
            acoustic = detectAcousticEvents(
                segments: segments,
                envelope: envelope,
                wordToSegment: wordToSegment,
                tally: tally,
                refWords: refWords,
                refEndsClause: refEndsClause,
                transWords: transWords,
                paragraphWordsAllowlist: paragraphWordsAllowlist
            )
        }

        // ── TROUBLE WORDS ─────────────────────────────────────────────────────
        // The three stuttering-like disfluencies. Misreadings are reported
        // separately, so recogniser noise no longer feeds the letter histogram.
        let stutteredWords = uniqued(filteredRepetitions + acoustic.prolongationWords + acoustic.blockWords)
        let uniqueMisread  = uniqued(filteredMisreadings)

        // ── READING ACCURACY ──────────────────────────────────────────────────
        let spokenCount        = tally.spokenInRegion
        let syllablesAttempted = TextNormalizer.syllableCount(of: tally.attemptedRefWords)
        // Words the recogniser dropped are excluded from every judgement:
        // they were reached (so they count toward coverage) but nothing can be
        // concluded about how they were read.
        let judgeableCount     = max(0, tally.attemptedCount - tally.unrecognisedCount)
        let completeness       = judgeableCount > 0 ? Double(tally.correctCount) / Double(judgeableCount) : 0
        let accuracy           = spokenCount    > 0 ? Double(tally.correctCount) / Double(spokenCount)    : 0
        let coverage           = refWords.count > 0 ? Double(tally.attemptedCount) / Double(refWords.count) : 0

        // ── FLUENCY SCORE ─────────────────────────────────────────────────────
        // Percent syllables stuttered is the clinical measure, so it is the
        // spine of the score. Syllables rather than words, because a long word
        // offers more opportunities to stutter than a short one.
        //
        // Completeness and accuracy enter as square roots: they temper the
        // score without dominating it, so reading a passage carefully and
        // correctly is what earns a high number — and reading three words
        // fluently no longer scores 100, because a session that short is also
        // marked unreliable below.
        //
        // All three disfluency types now count. Prolongations rejoined the
        // total once they became a measurement rather than a label pinned on
        // whatever the aligner could not explain.
        let stutterEvents = filteredRepetitions.count
                          + acoustic.prolongationWords.count
                          + acoustic.detectedBlocks.count
        let percentSyllablesStuttered = syllablesAttempted > 0
            ? Double(stutterEvents) / Double(syllablesAttempted) * 100
            : 0

        let fluencyTerm = exp(-percentSyllablesStuttered / scoreDecayRate)
        let rawScore = 100 * fluencyTerm * completeness.squareRoot() * accuracy.squareRoot()
        let score = min(100, max(0, Int(rawScore.rounded())))

        let severity = severityBand(forPercentSyllablesStuttered: percentSyllablesStuttered)

        // ── CONFIDENCE ────────────────────────────────────────────────────────
        // How much the transcript can be trusted as an index into the
        // paragraph. When a reader stutters heavily the recogniser degrades,
        // and a %SS printed to two decimals from a transcript full of holes
        // claims more than it knows.
        let misreadRate      = judgeableCount > 0 ? Double(filteredMisreadings.count) / Double(judgeableCount) : 0
        let unrecognisedRate = tally.attemptedCount > 0
            ? Double(tally.unrecognisedCount) / Double(tally.attemptedCount)
            : 0
        let confidence = confidenceBand(forWorstRate: max(misreadRate, unrecognisedRate))

        // ── PERCENTAGES ───────────────────────────────────────────────────────
        // Per 100 attempted words, so the figures mean the same thing whether
        // the paragraph was long or short.
        let attemptedDenominator = Double(max(1, judgeableCount))
        let repPercent = Double(filteredRepetitions.count)        / attemptedDenominator * 100
        let proPercent = Double(acoustic.prolongationWords.count) / attemptedDenominator * 100
        let misPercent = Double(filteredMisreadings.count)        / attemptedDenominator * 100
        let blkPercent = Double(acoustic.detectedBlocks.count)    / attemptedDenominator * 100
        let corPercent = completeness * 100

        // ── LETTER ANALYSIS ───────────────────────────────────────────────────
        // Still keyed on the first letter, which is spelling rather than sound —
        // that remains open work. It is at least now fed only by genuine
        // disfluencies rather than by every recogniser substitution.
        var letterCounts: [String: Int] = [:]
        for word in stutteredWords {
            if let firstChar = word.first {
                letterCounts[String(firstChar).uppercased(), default: 0] += 1
            }
        }

        let reportData = StutterJSONReport(
            fluencyScore: score,
            duration: durationString,
            stutteredWords: stutteredWords,
            misreadWords: uniqueMisread,
            blocks: acoustic.detectedBlocks,
            breakdown: StutterBreakdown(
                repetition: filteredRepetitions,
                prolongation: acoustic.prolongationWords,
                misread: filteredMisreadings,
                blocks: acoustic.detectedBlocks.count
            ),
            percentages: StutterPercentages(
                repetition: repPercent.rounded(toPlaces: 2),
                prolongation: proPercent.rounded(toPlaces: 2),
                misread: misPercent.rounded(toPlaces: 2),
                blocks: blkPercent.rounded(toPlaces: 2),
                correct: corPercent.rounded(toPlaces: 2),
                stutteredSyllables: percentSyllablesStuttered.rounded(toPlaces: 2)
            ),
            letterAnalysis: letterCounts,
            reading: ReadingAccuracy(
                referenceWords: refWords.count,
                attemptedWords: tally.attemptedCount,
                matchedWords: tally.correctCount,
                spokenWords: spokenCount,
                skippedWords: tally.skippedCount,
                unrecognisedWords: tally.unrecognisedCount,
                judgeableWords: judgeableCount,
                extraWords: tally.extraWordCount,
                syllablesAttempted: syllablesAttempted,
                completeness: completeness.rounded(toPlaces: 3),
                accuracy: accuracy.rounded(toPlaces: 3),
                coverage: coverage.rounded(toPlaces: 3)
            ),
            severity: severity,
            confidence: confidence,
            acousticAnalysisRan: acousticAnalysisRan,
            isReliable: syllablesAttempted >= minimumReliableSyllables,
            diagnostics: diagnostics(
                refWordCount: refWords.count,
                spokenWordCount: transWords.count,
                segments: segments,
                envelope: envelope,
                timingsAreUsable: timingsAreUsable,
                tally: tally,
                judgeableCount: judgeableCount,
                repetitionCount: filteredRepetitions.count,
                acoustic: acoustic
            )
        )

        return encode(reportData)
    }

    // MARK: - Analysis stages

    /// What walking the alignment found. Filled by `tallyAlignment`, then
    /// refined by `resolveUnalignedWords`.
    private struct AlignmentTally {
        var correctCount      = 0
        var skippedCount      = 0
        var unrecognisedCount = 0
        /// Extra spoken words that were not repetitions: backtracking,
        /// re-reads and filler. They cost the reader through the accuracy
        /// term, so the report has to be able to say they happened.
        var extraWordCount = 0
        var attemptedCount = 0
        /// Reference words with nothing aligned to them, awaiting the
        /// skipped-or-dropped verdict. `spokenIndex` is the spoken word that
        /// will be consumed next, which brackets the silence to inspect.
        var pendingDeletes: [(referenceIndex: Int, spokenIndex: Int)] = []
        /// Spoken words inside the attempted region. Recogniser noise after the
        /// reader stopped is outside the analysis entirely, so it neither earns
        /// credit nor drags the accuracy term down.
        var spokenInRegion = 0
        var repetitions:  [String] = []
        var misreadings:  [String] = []
        var attemptedRefWords: [String] = []
        /// For each spoken word, the reference word it aligned to (-1 if none).
        /// Chained with `wordToSegment`, this turns a timing event on a segment
        /// into a position in the paragraph.
        var spokenToReference: [Int]
        /// Spoken words that fell inside the attempted region.
        var spokenWasAttempted: [Bool]

        init(spokenWordCount: Int) {
            spokenToReference  = [Int](repeating: -1, count: spokenWordCount)
            spokenWasAttempted = [Bool](repeating: false, count: spokenWordCount)
        }
    }

    /// Blocks and prolongations measured from the envelope, plus the counters
    /// that explain an empty result.
    private struct AcousticFindings {
        var detectedBlocks:    [String] = []
        var blockWords:        [String] = []
        var prolongationWords: [String] = []

        // Counted purely so a session that reports nothing can explain why.
        var gapsConsidered         = 0
        var gapsRejectedTooShort   = 0
        var gapsRejectedAtBoundary = 0
        var gapsRejectedNotSilent  = 0
        var gapsRejectedUnnamed    = 0
        var wordsCheckedForHold    = 0
        var longestHoldSeen: TimeInterval = 0
    }

    /// The spoken words, and for each one the segment it came from.
    ///
    /// When timings are available the spoken stream is built **from the
    /// segments**, not from the formatted transcript string. That keeps a
    /// word's index and its timing provably the same object, which is what
    /// lets a silence be attributed to the right word further down.
    private static func spokenStream(
        transcript: String,
        segments: [SpeechSegment]
    ) -> (words: [String], wordToSegment: [Int]) {
        guard !segments.isEmpty else {
            return (TextNormalizer.tokenize(transcript), [])
        }
        var spoken: [String] = []
        var wordToSegment: [Int] = []
        for (segmentIndex, segment) in segments.enumerated() {
            for token in TextNormalizer.tokenize(segment.substring) {
                spoken.append(token)
                wordToSegment.append(segmentIndex)
            }
        }
        return (spoken, wordToSegment)
    }

    /// The index of the last operation the reader actually reached.
    ///
    /// The last operation that consumed a spoken word against a reference
    /// word marks how far the reading got. Reference words after that were
    /// never reached — the reader stopped — so they are not errors.
    ///
    /// This replaces the old "ignore everything after the last *match*"
    /// rule, which also threw away genuine errors in a stretch that was read
    /// badly enough to produce no matches at all.
    ///
    /// The last aligned operation has to be *supported* by another one close
    /// behind it. A common word carries enormous stray-match potential: a
    /// reader who says only "Science uncovers the" will have that final
    /// "the" aligned against some "the" forty words downstream, which would
    /// otherwise report thirty-odd skipped words for a three-word reading.
    /// Requiring company inside a short window discards those strays.
    private static func lastAttemptedOpIndex(in ops: [Operation]) -> Int {
        var lastAlignedFallback = -1
        for (index, op) in ops.enumerated() where op == .match || op == .substitute {
            lastAlignedFallback = index
        }
        var scanIndex = ops.count - 1
        while scanIndex >= 0 {
            if ops[scanIndex] == .match || ops[scanIndex] == .substitute {
                let windowStart = max(0, scanIndex - alignmentSupportWindow)
                let isSupported = (windowStart..<scanIndex).contains {
                    ops[$0] == .match || ops[$0] == .substitute
                }
                if isSupported { return scanIndex }
            }
            scanIndex -= 1
        }
        // A reading too short to contain a supported run still gets scored on
        // what it has; the reliability flag is what marks it as thin.
        return lastAlignedFallback
    }

    /// Walks the alignment once, classifying every operation inside the
    /// attempted region.
    private static func tallyAlignment(
        ops: [Operation],
        lastAttemptedOpIndex: Int,
        refWords: [String],
        transWords: [String],
        transChars: [[Character]]
    ) -> AlignmentTally {
        var tally = AlignmentTally(spokenWordCount: transWords.count)
        var refIndex   = 0
        var transIndex = 0

        for (opIndex, op) in ops.enumerated() {
            let wasAttempted = opIndex <= lastAttemptedOpIndex

            switch op {

            case .match:
                tally.spokenToReference[transIndex] = refIndex
                tally.spokenWasAttempted[transIndex] = wasAttempted
                if wasAttempted {
                    tally.correctCount   += 1
                    tally.attemptedCount += 1
                    tally.spokenInRegion += 1
                    tally.attemptedRefWords.append(refWords[refIndex])
                }
                refIndex   += 1
                transIndex += 1

            case .substitute:
                // A different word reached the recogniser. That is a misreading
                // or a recognition error — at word level the two are
                // indistinguishable, so it is reported as "misread" rather than
                // dressed up as a prolongation. It still costs the reader, via
                // the accuracy term in the score.
                tally.spokenToReference[transIndex] = refIndex
                tally.spokenWasAttempted[transIndex] = wasAttempted
                if wasAttempted {
                    tally.attemptedCount += 1
                    tally.spokenInRegion += 1
                    tally.attemptedRefWords.append(refWords[refIndex])
                    tally.misreadings.append(refWords[refIndex])
                }
                refIndex   += 1
                transIndex += 1

            case .insert:
                let insertedWord = transWords[transIndex]

                // A repetition is the speaker saying the same word twice in a
                // row. That is the only disfluency a word-level transcript can
                // evidence; anything else extra is filler or recogniser noise.
                //
                // Both neighbours are checked, because which of the two copies
                // the aligner labels as the insertion is arbitrary. Looking
                // only backwards missed every repetition where the *first*
                // copy was the one marked extra.
                let repeatsPrevious = transIndex > 0
                    && WordSimilarity.areEquivalent(transChars[transIndex], transChars[transIndex - 1])
                let repeatsNext = transIndex + 1 < transChars.count
                    && WordSimilarity.areEquivalent(transChars[transIndex], transChars[transIndex + 1])
                let isRepetition = repeatsPrevious || repeatsNext

                if wasAttempted {
                    tally.spokenInRegion += 1
                    if isRepetition {
                        tally.repetitions.append(insertedWord)
                    } else {
                        tally.extraWordCount += 1
                    }
                }
                // Extra words that are not repetitions are filler or
                // recogniser noise. They cost the reader through the accuracy
                // term already; naming them as a disfluency would be a guess.
                transIndex += 1

            case .delete:
                // A reference word with nothing spoken against it. Past the
                // attempted region the reader simply stopped. Inside it, the
                // word was either skipped or said-but-not-transcribed, and
                // only the audio can tell those apart — so defer the verdict
                // until the envelope can be consulted.
                if wasAttempted {
                    tally.pendingDeletes.append((referenceIndex: refIndex, spokenIndex: transIndex))
                }
                refIndex += 1
            }
        }
        return tally
    }

    /// Skipped, or said and not transcribed?
    ///
    /// A reference word with nothing aligned to it only counts against the
    /// reader if the reader was silent there. If the envelope shows speech
    /// in the window where that word belongs, they said it and the
    /// recogniser dropped it — scoring that against them penalises the user
    /// for the recogniser's failure. It lowers confidence instead.
    ///
    /// Consecutive unaligned words share one window, so they are judged as
    /// a group: enough speech to account for their syllables means spoken.
    private static func resolveUnalignedWords(
        in tally: inout AlignmentTally,
        refWords: [String],
        segments: [SpeechSegment],
        wordToSegment: [Int],
        envelope: SpeechEnvelope?
    ) {
        var deletesBySpokenIndex: [Int: [Int]] = [:]
        for pending in tally.pendingDeletes {
            deletesBySpokenIndex[pending.spokenIndex, default: []].append(pending.referenceIndex)
        }

        for (spokenIndex, referenceIndices) in deletesBySpokenIndex.sorted(by: { $0.key < $1.key }) {
            let words = referenceIndices.compactMap { index -> String? in
                index >= 0 && index < refWords.count ? refWords[index] : nil
            }
            guard !words.isEmpty else { continue }

            var wasSpoken = false
            if let envelope, !segments.isEmpty,
               spokenIndex > 0, spokenIndex < wordToSegment.count,
               wordToSegment[spokenIndex - 1] < segments.count {
                let previous = segments[wordToSegment[spokenIndex - 1]]
                let next     = segments[wordToSegment[spokenIndex]]
                // Half the words' minimum spoken length is enough evidence:
                // under-crediting would put the penalty back on the reader.
                let expected = Double(TextNormalizer.syllableCount(of: words)) * 0.12
                if let heard = envelope.speechTime(from: previous.endTimestamp, to: next.timestamp),
                   expected > 0, heard >= expected * 0.5 {
                    wasSpoken = true
                }
            }

            tally.attemptedCount += words.count
            if wasSpoken {
                // Reached, but nothing can be concluded about how it was read.
                tally.unrecognisedCount += words.count
            } else {
                tally.skippedCount += words.count
                tally.attemptedRefWords.append(contentsOf: words)
            }
        }
    }

    /// Whether the word timings can be measured from at all.
    ///
    /// Partial recognition results routinely carry zero durations, and a
    /// chunk finalised from a partial hands over a whole minute of segments
    /// with no timing in them. Gaps and word spans computed from those are
    /// meaningless — and because every gap is then zero, the report comes
    /// back with no blocks and no prolongations, which reads as a fluent
    /// session rather than a failed measurement.
    private static func segmentTimingsAreUsable(_ segments: [SpeechSegment]) -> Bool {
        guard segments.count >= 2 else { return false }
        let timed = segments.filter { $0.duration > 0.01 }.count
        guard Double(timed) >= Double(segments.count) * 0.6 else { return false }
        let monotone = zip(segments, segments.dropFirst()).allSatisfy { $0.timestamp <= $1.timestamp }
        guard monotone else { return false }
        let span = (segments.last?.endTimestamp ?? 0) - (segments.first?.timestamp ?? 0)
        return span > 0.5
    }

    /// Blocks and prolongations, measured from the envelope.
    ///
    /// Both are acoustic events, measured from the envelope rather than
    /// guessed at from the transcript.
    ///
    /// A **block** is a tense, silent stoppage before a word. Its evidence
    /// is the gap between one word ending and the next beginning — not, as
    /// the previous implementation had it, the duration of the word itself,
    /// which is a prolongation's signature. Two conditions have to hold:
    /// the gap must be long enough for the position it occupies (a pause
    /// after a comma is the paragraph asking for one), and it must actually
    /// be silent. A "gap" full of sound is a filled pause or a word the
    /// recogniser clipped, and neither is a block.
    ///
    /// A **prolongation** is a sound held. Inside the word's own span, the
    /// envelope is asked for the longest stretch where sound is present and
    /// neither loudness nor spectrum is changing. Articulated speech never
    /// holds still for 300 ms; a held "sss" or "mmm" does.
    private static func detectAcousticEvents(
        segments: [SpeechSegment],
        envelope: SpeechEnvelope,
        wordToSegment: [Int],
        tally: AlignmentTally,
        refWords: [String],
        refEndsClause: [Bool],
        transWords: [String],
        paragraphWordsAllowlist: Set<String>
    ) -> AcousticFindings {
        var found = AcousticFindings()

        // First and last spoken-word index belonging to each segment.
        var firstWordOfSegment = [Int](repeating: -1, count: segments.count)
        var lastWordOfSegment  = [Int](repeating: -1, count: segments.count)
        for (wordIndex, segmentIndex) in wordToSegment.enumerated() {
            if firstWordOfSegment[segmentIndex] < 0 { firstWordOfSegment[segmentIndex] = wordIndex }
            lastWordOfSegment[segmentIndex] = wordIndex
        }

        /// The paragraph word an acoustic event belongs to.
        ///
        /// This used to require the *spoken* word to appear in the
        /// paragraph, which discarded the event whenever the disfluency
        /// distorted recognition — so the harder someone stuttered, the
        /// more evidence was thrown away, and a held sound came back as a
        /// misreading instead. Even a successful fuzzy match lost its
        /// event, because the matched word carried the recogniser's
        /// spelling rather than the paragraph's.
        ///
        /// The alignment already knows which reference word this is, so
        /// use that and let the acoustic evidence stand on its own.
        /// Removing the old condition took detection recall across 26
        /// simulated readers from 54% to 86%, and raised precision too.
        func attemptedWord(at wordIndex: Int) -> String? {
            guard wordIndex >= 0, wordIndex < transWords.count,
                  tally.spokenWasAttempted[wordIndex] else { return nil }
            let referenceIndex = tally.spokenToReference[wordIndex]
            if referenceIndex >= 0, referenceIndex < refWords.count {
                return refWords[referenceIndex]
            }
            let word = transWords[wordIndex]
            return paragraphWordsAllowlist.contains(word) ? word : nil
        }

        // ── Blocks: silence before a word ─────────────────────────────────────
        for segmentIndex in 1..<segments.count {
            let previous = segments[segmentIndex - 1]
            let current  = segments[segmentIndex]
            let gap = current.timestamp - previous.endTimestamp
            found.gapsConsidered += 1

            guard gap >= SpeechEnvelope.Tuning.minimumBlockGap,
                  gap <= SpeechEnvelope.Tuning.maximumBlockGap else {
                found.gapsRejectedTooShort += 1
                continue
            }

            // Does the paragraph put a clause break before this word? If so
            // the reader is pausing as written and needs more silence
            // before it means anything.
            let previousWordIndex = lastWordOfSegment[segmentIndex - 1]
            var isAtClauseBoundary = false
            if previousWordIndex >= 0 {
                let referenceIndex = tally.spokenToReference[previousWordIndex]
                if referenceIndex >= 0, referenceIndex < refEndsClause.count {
                    isAtClauseBoundary = refEndsClause[referenceIndex]
                }
            }
            if isAtClauseBoundary, gap < SpeechEnvelope.Tuning.minimumBoundaryGap {
                found.gapsRejectedAtBoundary += 1
                continue
            }

            // The gap has to be genuinely empty of speech. `nil` means the
            // span falls outside recorded audio, which is a reason to
            // abstain rather than to accuse.
            guard let gapSpeech = envelope.speechTime(from: previous.endTimestamp,
                                                      to: current.timestamp),
                  gapSpeech <= SpeechEnvelope.Tuning.maximumGapSpeechTime
            else {
                found.gapsRejectedNotSilent += 1
                continue
            }

            guard let word = attemptedWord(at: firstWordOfSegment[segmentIndex]) else {
                found.gapsRejectedUnnamed += 1
                continue
            }
            found.detectedBlocks.append("\(word) (blocked \(String(format: "%.2f", gap))s)")
            found.blockWords.append(word)
        }

        // ── Prolongations: sound held inside a word ───────────────────────────
        for (segmentIndex, segment) in segments.enumerated() {
            guard segment.duration > SpeechEnvelope.Tuning.minimumProlongation else { continue }
            found.wordsCheckedForHold += 1
            let held = envelope.longestSustainedStretch(
                from: segment.timestamp,
                to: segment.endTimestamp
            )
            found.longestHoldSeen = max(found.longestHoldSeen, held)
            guard held >= SpeechEnvelope.Tuning.minimumProlongation else { continue }
            guard let word = attemptedWord(at: firstWordOfSegment[segmentIndex]) else { continue }
            found.prolongationWords.append(word)
        }

        return found
    }

    /// The words in order of first appearance, each once.
    private static func uniqued(_ words: [String]) -> [String] {
        var seen = Set<String>()
        return words.filter { seen.insert($0).inserted }
    }

    /// Clinical %SS bands. Used internally and in diagnostics; the result
    /// screen deliberately doesn't show them (Guideline 1.4.1).
    private static func severityBand(forPercentSyllablesStuttered percent: Double) -> String {
        switch percent {
        case ..<3.0:  return "typical"
        case ..<7.0:  return "mild"
        case ..<12.0: return "moderate"
        default:      return "severe"
        }
    }

    private static func confidenceBand(forWorstRate worstRate: Double) -> String {
        switch worstRate {
        case ..<0.12: return "high"
        case ..<0.25: return "moderate"
        default:      return "low"
        }
    }

    /// Why the report says what it says: counts and measurements from each
    /// stage of the pipeline, for the diagnostics view.
    private static func diagnostics(
        refWordCount: Int,
        spokenWordCount: Int,
        segments: [SpeechSegment],
        envelope: SpeechEnvelope?,
        timingsAreUsable: Bool,
        tally: AlignmentTally,
        judgeableCount: Int,
        repetitionCount: Int,
        acoustic: AcousticFindings
    ) -> [String: String] {
        [
            "referenceWords": "\(refWordCount)",
            "spokenWords": "\(spokenWordCount)",
            "segments": "\(segments.count)",
            "segmentsWithDuration": "\(segments.filter { $0.duration > 0.01 }.count)",
            "segmentTimingSpan": String(format: "%.2fs",
                (segments.last?.endTimestamp ?? 0) - (segments.first?.timestamp ?? 0)),
            "timingsAreUsable": "\(timingsAreUsable)",
            "envelopeFrames": "\(envelope?.frames.count ?? 0)",
            "envelopeDuration": String(format: "%.2fs", envelope?.duration ?? 0),
            "envelopeNoiseFloor": String(format: "%.4f", envelope?.noiseFloor ?? 0),
            "envelopeSpeechLevel": String(format: "%.4f", envelope?.speechLevel ?? 0),
            "envelopeSilenceThreshold": String(format: "%.4f", envelope?.silenceThreshold ?? 0),
            "envelopeVoicingThreshold": String(format: "%.4f", envelope?.voicingThreshold ?? 0),
            "matched": "\(tally.correctCount)",
            "substituted": "\(tally.misreadings.count)",
            "skipped": "\(tally.skippedCount)",
            "unrecognised": "\(tally.unrecognisedCount)",
            "extra": "\(tally.extraWordCount)",
            "attempted": "\(tally.attemptedCount)",
            "judgeable": "\(judgeableCount)",
            "repetitionsFound": "\(repetitionCount)",
            "prolongationsFound": "\(acoustic.prolongationWords.count)",
            "blocksFound": "\(acoustic.detectedBlocks.count)",
            "gapsConsidered": "\(acoustic.gapsConsidered)",
            "gapsRejectedTooShort": "\(acoustic.gapsRejectedTooShort)",
            "gapsRejectedAtBoundary": "\(acoustic.gapsRejectedAtBoundary)",
            "gapsRejectedNotSilent": "\(acoustic.gapsRejectedNotSilent)",
            "gapsRejectedUnnamed": "\(acoustic.gapsRejectedUnnamed)",
            "wordsCheckedForHold": "\(acoustic.wordsCheckedForHold)",
            "longestHoldSeen": String(format: "%.3fs", acoustic.longestHoldSeen)
        ]
    }

    // MARK: - Helpers

    private static func encode(_ report: StutterJSONReport) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let jsonData = try? encoder.encode(report),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        return "{ \"error\": \"Failed to encode JSON\" }"
    }

    /// Full-matrix Levenshtein with traceback, using near-match equivalence
    /// rather than string equality so recogniser near-misses align as the same
    /// word instead of counting as errors.
    private static func alignment(ref: [[Character]], hyp: [[Character]]) -> [Operation] {
        let n = ref.count, m = hyp.count
        if n == 0 { return Array(repeating: .insert, count: m) }
        if m == 0 { return Array(repeating: .delete, count: n) }

        // Equivalence is resolved once per cell and reused by the traceback, so
        // the two passes can never disagree about what counts as a match.
        var equivalent = [[Bool]](repeating: [Bool](repeating: false, count: m), count: n)
        for i in 0..<n {
            for j in 0..<m {
                equivalent[i][j] = WordSimilarity.areEquivalent(ref[i], hyp[j])
            }
        }

        var matrix = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in 0...n { matrix[i][0] = i }
        for j in 0...m { matrix[0][j] = j }

        for i in 1...n {
            for j in 1...m {
                if equivalent[i-1][j-1] {
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
            if i > 0, j > 0, equivalent[i-1][j-1], matrix[i][j] == matrix[i-1][j-1] {
                ops.append(.match);      i -= 1; j -= 1
            } else if i > 0, j > 0, matrix[i][j] == matrix[i-1][j-1] + 1 {
                ops.append(.substitute); i -= 1; j -= 1
            } else if i > 0, matrix[i][j] == matrix[i-1][j] + 1 {
                ops.append(.delete);     i -= 1
            } else {
                ops.append(.insert);     j -= 1
            }
        }
        return ops.reversed()
    }

    private static func emptyReport(duration: String) -> StutterJSONReport {
        StutterJSONReport(
            fluencyScore: 0,
            duration: duration,
            stutteredWords: [],
            misreadWords: [],
            blocks: [],
            breakdown: StutterBreakdown(repetition: [], prolongation: [], misread: [], blocks: 0),
            percentages: StutterPercentages(
                repetition: 0, prolongation: 0, misread: 0, blocks: 0,
                correct: 0, stutteredSyllables: 0
            ),
            letterAnalysis: [:],
            reading: ReadingAccuracy(
                referenceWords: 0, attemptedWords: 0, matchedWords: 0, spokenWords: 0,
                skippedWords: 0, unrecognisedWords: 0, judgeableWords: 0,
                extraWords: 0, syllablesAttempted: 0,
                completeness: 0, accuracy: 0, coverage: 0
            ),
            severity: "typical",
            confidence: "low",
            acousticAnalysisRan: false,
            isReliable: false,
            diagnostics: ["note": "empty report — no transcript or no reference"]
        )
    }
}

// MARK: - Double Extension

extension Double {
    /// Rounds to `places` decimal places.
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
