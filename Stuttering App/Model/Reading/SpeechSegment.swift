import Foundation
import Speech

/// A single recognised word with timings expressed on the **session clock**.
///
/// `SFTranscriptionSegment` timestamps are relative to the start of the
/// recognition *request* that produced them. On-device `SFSpeechRecognizer`
/// times out after roughly a minute, so a single reading session is stitched
/// together from several requests — and each new request restarts its clock
/// at zero.
///
/// `SpeechSegment` re-bases those timings onto one continuous session clock by
/// adding the offset at which the owning request began. Downstream analysis can
/// therefore compare timings across the whole session, and — importantly for
/// block detection — measure the silent gap between two words that happen to
/// straddle a recogniser restart.
struct SpeechSegment {
    /// The recognised word, as the recogniser spelled it.
    let substring: String
    /// Seconds from the start of the session to the start of this word.
    let timestamp: TimeInterval
    /// Spoken length of this word in seconds.
    let duration: TimeInterval
    /// Recogniser confidence in `0...1`. Always `0` on partial results.
    let confidence: Float

    /// Seconds from the start of the session to the end of this word.
    var endTimestamp: TimeInterval { timestamp + duration }

    init(substring: String, timestamp: TimeInterval, duration: TimeInterval, confidence: Float) {
        self.substring  = substring
        self.timestamp  = timestamp
        self.duration   = duration
        self.confidence = confidence
    }

    /// Re-bases an Apple segment onto the session clock.
    /// - Parameter sessionOffset: session-clock time at which the owning
    ///   recognition request started listening.
    init(_ segment: SFTranscriptionSegment, sessionOffset: TimeInterval) {
        self.substring  = segment.substring
        self.timestamp  = segment.timestamp + sessionOffset
        self.duration   = segment.duration
        self.confidence = segment.confidence
    }
}

extension Array where Element == SpeechSegment {
    /// Silent gap in seconds between each segment and the one before it.
    ///
    /// Not used by the current analyser, which measures word duration rather
    /// than the pause preceding a word. It is the quantity a genuine block
    /// detector needs, so it lives here ready for that work.
    var interWordGaps: [TimeInterval] {
        guard count > 1 else { return [] }
        return (1..<count).map { self[$0].timestamp - self[$0 - 1].endTimestamp }
    }
}
