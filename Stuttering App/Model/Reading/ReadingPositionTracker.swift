import Foundation

/// Works out which word of the paragraph the reader has reached.
///
/// The reading highlight used to advance on a fixed timer — three words every
/// 1.7 s, about 106 words per minute — with nothing connecting it to what the
/// microphone heard. Across 26 simulated readers that timer drifted from the
/// reader by between 4 and 39 words, and it drifted worst for the slow,
/// deliberate reader this app exists for: they finished 39 words behind the
/// highlight. Losing the pace then causes real scoring damage, because readers
/// skip text to catch up.
///
/// The fix is not to estimate the reader's speed. A rate estimate is always
/// behind them, it cannot tell a block from a slow patch — during a block it
/// would slow down, then lurch when the word finally came — and an estimator
/// that adapts to a stuttering reader keeps adapting downward. The recogniser
/// already knows which word they are on, so follow that instead. Drift then
/// becomes the lookahead you chose, for every reader.
final class ReadingPositionTracker {

    // MARK: - Tuning

    /// How far ahead of the current position a spoken word may match.
    /// Skipping a few words is ordinary; matching something twenty words away
    /// is the aligner inventing progress.
    private static let lookaheadWindow = 8
    /// Short words appear everywhere, so they get a tighter window: "the" can
    /// otherwise pull the position forward to the next "the" in the paragraph.
    private static let shortWordWindow = 3
    private static let shortWordLength = 4
    /// Consecutive unmatched words before the position is assumed lost.
    private static let resyncAfterMisses = 3
    /// How far ahead a resync will look for an anchor.
    private static let resyncWindow = 40
    /// How far behind to look before concluding the reader jumped forward
    /// rather than went back.
    private static let backtrackWindow = 14

    private let referenceWords: [[Character]]

    /// Number of words on screen. Matches a `\S+` scan of the same paragraph.
    var wordCount: Int { referenceWords.count }

    init(reference: String) {
        referenceWords = TextNormalizer.displayWordForms(reference).map { Array($0) }
    }

    /// The index of the next word the reader is expected to say.
    ///
    /// Recomputed from the whole spoken list rather than advanced
    /// incrementally: partial recognition results revise their own earlier
    /// words, and an incremental position would be stranded by that. A greedy
    /// forward scan over a few hundred words costs little and cannot drift.
    func position(forSpoken spokenWords: [String]) -> Int {
        var index = 0
        var previous: [Character] = []
        var misses = 0

        for word in spokenWords {
            let chars = Array(word)
            guard !chars.isEmpty else { continue }

            // A word identical to the one before it is a repetition, not
            // progress. Without this, "the the" walks the position forward to
            // whatever "the" comes next in the paragraph.
            if chars == previous { continue }
            let priorWord = previous
            previous = chars

            guard index < referenceWords.count else { break }

            let window = chars.count < Self.shortWordLength
                ? Self.shortWordWindow
                : Self.lookaheadWindow
            let end = min(referenceWords.count, index + window)

            var matched = false
            for candidate in index..<end {
                if WordSimilarity.areEquivalent(chars, referenceWords[candidate]) {
                    index = candidate + 1
                    matched = true
                    break
                }
            }
            if matched {
                misses = 0
                continue
            }

            misses += 1
            guard misses >= Self.resyncAfterMisses, !priorWord.isEmpty else { continue }

            // Did the reader go *back*? A restart or a re-read anchors behind
            // the current position, and the answer there is to hold still:
            // they will reach the highlight again on the way forward. Leaping
            // ahead on a backtrack sent the highlight 26 words past a reader
            // who had restarted the clause from word 12.
            let behindStart = max(1, index - Self.backtrackWindow)
            if behindStart < index {
                let wentBack = (behindStart..<index).contains { candidate in
                    WordSimilarity.areEquivalent(chars, referenceWords[candidate])
                        && WordSimilarity.areEquivalent(priorWord, referenceWords[candidate - 1])
                }
                if wentBack {
                    misses = 0
                    continue
                }
            }

            // Otherwise the reader has jumped forward past the window —
            // usually skipping text to catch up with a highlight that ran
            // ahead. Without this the position stayed stranded for the rest of
            // the session: one simulated reader froze at word 18 of 63.
            //
            // The anchor is three consecutive words. Two is not specific
            // enough in a paragraph that repeats phrasing.
            let forwardEnd = min(referenceWords.count - 1, index + Self.resyncWindow)
            if index + 1 < forwardEnd {
                for candidate in (index + 1)..<forwardEnd {
                    if WordSimilarity.areEquivalent(priorWord, referenceWords[candidate - 1]),
                       WordSimilarity.areEquivalent(chars, referenceWords[candidate]) {
                        index = candidate + 1
                        misses = 0
                        break
                    }
                }
            }
        }
        return index
    }
}
