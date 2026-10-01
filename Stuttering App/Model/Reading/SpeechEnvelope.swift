import Foundation
import AVFoundation

/// A coarse acoustic description of the session: one frame every 10 ms holding
/// loudness and a spectral proxy.
///
/// Repetitions are the only stuttering-like disfluency a word-level transcript
/// can evidence. Blocks and prolongations are acoustic events, and the audio
/// they live in was previously written to a file and then thrown away. This
/// envelope keeps just enough of it — two floats per frame, about 1.4 MB for a
/// full 15-minute session — to measure them.
///
/// **Loudness (`rms`)** separates silence from speech, which is what a block
/// is: a tense, silent stoppage before a word.
///
/// **Zero-crossing rate** is a cheap spectral proxy. Voiced sounds (vowels,
/// "mmm", "nnn") cross zero slowly; fricatives ("sss", "fff", "shh") cross it
/// rapidly. A prolongation is a sound *held*, so what identifies it is not the
/// value of either measure but their **stability**: loudness and spectrum both
/// stop changing while sound continues. That covers voiced and voiceless
/// prolongations with one test.
struct AcousticFrame {
    let rms: Float
    let zeroCrossingRate: Float
}

struct SpeechEnvelope {

    // MARK: - Tuning
    //
    // ⚠️ These are reasoned starting points, not validated thresholds. They
    // were chosen from the phonetics of each event and checked against
    // synthetic signals; none of them has been calibrated against real
    // recordings of real speakers. Expect to move them once labelled sessions
    // exist, and treat every number in this block as one experiment.

    enum Tuning {
        /// Silence shorter than this is ordinary articulation, not a stoppage.
        static let minimumBlockGap: TimeInterval = 0.25
        /// After a comma or full stop, a pause is expected — a gap there must
        /// be considerably longer before it means anything.
        static let minimumBoundaryGap: TimeInterval = 0.70
        /// Beyond this the speaker has stopped, taken a breath, or been
        /// interrupted. Calling that a block would flag ordinary pauses.
        ///
        /// Lowered from 3.0 s: simulated readers taking a 2.4 s breath
        /// mid-clause were being reported as blocked. A block is short and
        /// tense; multi-second silence is a breath or a lost place.
        static let maximumBlockGap: TimeInterval = 1.5
        /// Most speech a silent gap may contain and still count as silent.
        /// Below any real word's length, so a word the recogniser dropped
        /// cannot masquerade as a block.
        static let maximumGapSpeechTime: TimeInterval = 0.10
        /// A held sound must last this long to be a prolongation rather than a
        /// slow syllable.
        static let minimumProlongation: TimeInterval = 0.30
        /// Window over which stability is judged.
        static let stabilityWindow: TimeInterval = 0.10
        /// Loudness may vary by this much (coefficient of variation) inside a
        /// stable stretch.
        static let maximumRMSVariation: Float = 0.28
        /// Spectrum may vary by this much (standard deviation of ZCR).
        static let maximumZCRVariation: Float = 0.08
    }

    let frameDuration: TimeInterval
    let frames: [AcousticFrame]

    /// Quiet-room level for this session.
    let noiseFloor: Float
    /// Typical loudness while actually speaking.
    let speechLevel: Float

    var duration: TimeInterval { Double(frames.count) * frameDuration }
    var isEmpty: Bool { frames.isEmpty }

    /// Everything below this counts as silence. Derived from the speaker and
    /// their room rather than fixed, because microphone gain and background
    /// noise vary far more between sessions than between speakers.
    var silenceThreshold: Float { noiseFloor + 0.15 * max(0, speechLevel - noiseFloor) }
    /// Above this, sound is present rather than merely audible.
    var voicingThreshold: Float { noiseFloor + 0.35 * max(0, speechLevel - noiseFloor) }

    init(frameDuration: TimeInterval, frames: [AcousticFrame]) {
        self.frameDuration = frameDuration
        self.frames = frames

        guard !frames.isEmpty else {
            self.noiseFloor = 0
            self.speechLevel = 0
            return
        }
        let sorted = frames.map(\.rms).sorted()
        func percentile(_ p: Double) -> Float {
            let index = min(sorted.count - 1, max(0, Int(Double(sorted.count - 1) * p)))
            return sorted[index]
        }
        // 10th percentile is the room; 75th is the speaker. Means would be
        // dragged by whichever of the two dominates the session.
        self.noiseFloor  = percentile(0.10)
        self.speechLevel = percentile(0.75)
    }

    // MARK: - Lookups

    private func frameRange(from start: TimeInterval, to end: TimeInterval) -> Range<Int>? {
        guard !frames.isEmpty, end > start else { return nil }
        let first = max(0, Int(start / frameDuration))
        let last  = min(frames.count, Int((end / frameDuration).rounded(.up)))
        guard first < last else { return nil }
        return first..<last
    }

    /// Seconds of speech-level sound inside a span, however broken up.
    /// `nil` when the span falls outside the recorded audio, so callers can
    /// tell "quiet" from "unknown" and abstain rather than accuse.
    ///
    /// This replaced a "what fraction of the span is quiet" test, which a
    /// dropped word beside a comma pause could pass at 77% quiet. The question
    /// a block actually poses is whether a *word* was in there, and total
    /// speech content answers it.
    ///
    /// It deliberately does **not** ask for an unbroken run of speech. Stop
    /// consonants — the /t/ in "structure", the /k/ in "curiosity" — are
    /// genuinely silent for 40-100 ms, so real words contain no unbroken run;
    /// requiring one dropped precision from 0.96 to 0.70 in simulation.
    func speechTime(from start: TimeInterval, to end: TimeInterval) -> TimeInterval? {
        guard let range = frameRange(from: start, to: end) else { return nil }
        let loud = frames[range].filter { $0.rms > voicingThreshold }.count
        return Double(loud) * frameDuration
    }

    /// Longest stretch of held sound inside a span, in seconds.
    ///
    /// The measure is deliberately conservative: because stability is judged
    /// over a window centred on each frame, the frames at either edge of a held
    /// sound have windows straddling the articulated speech around it and fail
    /// the test. A held sound therefore measures roughly 40 ms shorter than it
    /// really is. Under-reporting is the right bias for a clinical claim.
    ///
    /// A frame is part of a held sound when, over a short window around it,
    /// there is sound present and neither loudness nor spectrum is changing
    /// much. Articulated speech fails this constantly; a held "sss" or "mmm"
    /// passes it for as long as the speaker sustains the sound.
    func longestSustainedStretch(from start: TimeInterval, to end: TimeInterval) -> TimeInterval {
        guard let range = frameRange(from: start, to: end) else { return 0 }

        let windowFrames = max(2, Int(Tuning.stabilityWindow / frameDuration))
        guard range.count >= windowFrames else { return 0 }

        var longestRun = 0
        var currentRun = 0

        for index in range {
            let windowStart = max(range.lowerBound, index - windowFrames / 2)
            let windowEnd   = min(range.upperBound, windowStart + windowFrames)
            guard windowEnd - windowStart >= windowFrames else {
                currentRun = 0
                continue
            }

            let window = frames[windowStart..<windowEnd]
            let rmsValues = window.map(\.rms)
            let zcrValues = window.map(\.zeroCrossingRate)

            let meanRMS = rmsValues.reduce(0, +) / Float(rmsValues.count)
            guard meanRMS > voicingThreshold else {
                currentRun = 0
                continue
            }

            let rmsVariation = standardDeviation(rmsValues) / max(meanRMS, .leastNonzeroMagnitude)
            let zcrVariation = standardDeviation(zcrValues)

            if rmsVariation <= Tuning.maximumRMSVariation && zcrVariation <= Tuning.maximumZCRVariation {
                currentRun += 1
                longestRun = max(longestRun, currentRun)
            } else {
                currentRun = 0
            }
        }
        return Double(longestRun) * frameDuration
    }

    private func standardDeviation(_ values: [Float]) -> Float {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Float(values.count)
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Float(values.count)
        return variance.squareRoot()
    }
}

// MARK: - Builder

/// Accumulates an envelope from live microphone buffers.
///
/// Fed from the audio tap, so `append(_:)` runs on a realtime thread and is
/// guarded accordingly. The frame count is also the session's audio clock:
/// `recordedDuration` counts only audio actually captured, which is what
/// recogniser timestamps should be anchored to — wall-clock time drifts against
/// it across a long session and jumps at every pause.
final class SpeechEnvelopeBuilder {

    let frameDuration: TimeInterval = 0.01

    private let lock = NSLock()
    private var frames: [AcousticFrame] = []
    private var pending: [Float] = []
    private var currentSampleRate: Double = 0
    /// Slowly-decaying loudest frame seen. A running reference for "is the
    /// reader speaking right now", which the session percentiles cannot answer
    /// mid-session because the distribution is not complete yet.
    private var decayingPeak: Float = 0

    /// Seconds of audio captured so far.
    var recordedDuration: TimeInterval {
        lock.lock(); defer { lock.unlock() }
        return Double(frames.count) * frameDuration
    }

    /// Whether the microphone has heard nothing but room noise for `window`.
    ///
    /// This is what tells the reading highlight that a reader has genuinely
    /// stopped. The recogniser cannot: it goes quiet for seconds at a time
    /// while someone is speaking perfectly well, and treating that as silence
    /// is what stalled the highlight and made readers back up and re-read.
    ///
    /// Returns `false` whenever there is not enough evidence — the highlight
    /// should keep moving on ignorance, never freeze on it.
    func isSilent(forLast window: TimeInterval) -> Bool {
        lock.lock(); defer { lock.unlock() }
        let needed = max(1, Int(window / frameDuration))
        guard frames.count >= needed, decayingPeak > 0.0005 else { return false }

        let recent = frames.suffix(needed)
        let mean = recent.reduce(Float(0)) { $0 + $1.rms } / Float(recent.count)
        return mean < decayingPeak * 0.15
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        let count = Int(buffer.frameLength)
        guard count > 0 else { return }

        var samples = [Float](repeating: 0, count: count)
        if let floatData = buffer.floatChannelData {
            let channel = floatData[0]
            for index in 0..<count { samples[index] = channel[index] }
        } else if let intData = buffer.int16ChannelData {
            let channel = intData[0]
            for index in 0..<count { samples[index] = Float(channel[index]) / 32768.0 }
        } else {
            return
        }

        lock.lock()
        defer { lock.unlock() }

        let sampleRate = buffer.format.sampleRate
        if sampleRate != currentSampleRate {
            // A route change can hand us a different rate mid-session. Drop the
            // partial frame rather than splicing two rates into one.
            pending.removeAll(keepingCapacity: true)
            currentSampleRate = sampleRate
        }

        pending.append(contentsOf: samples)

        let samplesPerFrame = max(1, Int(sampleRate * frameDuration))
        var offset = 0
        while offset + samplesPerFrame <= pending.count {
            let slice = pending[offset..<(offset + samplesPerFrame)]
            let frame = Self.makeFrame(slice)
            frames.append(frame)
            // Decays with a half-life of roughly fourteen seconds, so the
            // reference tracks the speaker rather than one loud moment.
            decayingPeak = max(frame.rms, decayingPeak * 0.9995)
            offset += samplesPerFrame
        }
        if offset > 0 { pending.removeFirst(offset) }
    }

    private static func makeFrame(_ samples: ArraySlice<Float>) -> AcousticFrame {
        var sumOfSquares: Float = 0
        var crossings = 0
        var previous: Float = 0
        var isFirst = true

        for sample in samples {
            sumOfSquares += sample * sample
            if !isFirst && ((sample < 0) != (previous < 0)) { crossings += 1 }
            previous = sample
            isFirst = false
        }

        let rms = (sumOfSquares / Float(samples.count)).squareRoot()
        let zcr = Float(crossings) / Float(max(1, samples.count - 1))
        return AcousticFrame(rms: rms, zeroCrossingRate: zcr)
    }

    func makeEnvelope() -> SpeechEnvelope {
        lock.lock(); defer { lock.unlock() }
        return SpeechEnvelope(frameDuration: frameDuration, frames: frames)
    }

    func reset() {
        lock.lock(); defer { lock.unlock() }
        frames.removeAll()
        pending.removeAll()
        currentSampleRate = 0
    }
}
