import Foundation

/// Near-match test used by the reading aligner.
///
/// Exact string comparison treats every recogniser near-miss as a reading
/// error: "astronomy" heard as "astronomer", a dropped plural, a swallowed
/// ending. Those are transcription noise, not stutters, and counting them as
/// disfluency is the single largest source of false positives in the report.
///
/// Jaro-Winkler is the right measure here because its prefix bonus rewards
/// words that begin alike — which is exactly how ASR near-misses look, and
/// also how a genuine reading of the intended word looks.
enum WordSimilarity {

    /// Below this length, only exact matches count. Short function words are
    /// where fuzzy matching does damage rather than good: "than"/"that",
    /// "then"/"them" and "a"/"at" all score high while being real differences.
    static let minimumFuzzyLength = 5

    /// Similarity at or above which two words are treated as the same word.
    static let matchThreshold = 0.87

    /// Whether two tokens should align as the same word.
    static func areEquivalent(_ a: [Character], _ b: [Character]) -> Bool {
        if a == b { return true }

        // Cheap rejections first — this predicate runs once per cell of the
        // alignment matrix, so a 700-word paragraph evaluates it ~500,000 times.
        guard a.count >= minimumFuzzyLength, b.count >= minimumFuzzyLength else { return false }
        guard abs(a.count - b.count) <= 3 else { return false }
        guard a[0] == b[0] else { return false }

        return jaroWinkler(a, b) >= matchThreshold
    }

    static func areEquivalent(_ a: String, _ b: String) -> Bool {
        a == b || areEquivalent(Array(a), Array(b))
    }

    /// Jaro-Winkler similarity in `0...1`.
    static func jaroWinkler(_ a: [Character], _ b: [Character]) -> Double {
        let jaro = jaroSimilarity(a, b)
        guard jaro > 0.7 else { return jaro }

        // Winkler bonus: up to four leading characters in common.
        var prefix = 0
        for index in 0..<min(4, min(a.count, b.count)) {
            if a[index] == b[index] { prefix += 1 } else { break }
        }
        return jaro + (Double(prefix) * 0.1 * (1 - jaro))
    }

    private static func jaroSimilarity(_ a: [Character], _ b: [Character]) -> Double {
        if a.isEmpty && b.isEmpty { return 1 }
        if a.isEmpty || b.isEmpty { return 0 }
        if a == b { return 1 }

        let window = max(max(a.count, b.count) / 2 - 1, 0)
        var aMatched = [Bool](repeating: false, count: a.count)
        var bMatched = [Bool](repeating: false, count: b.count)

        var matches = 0
        for i in 0..<a.count {
            let start = max(0, i - window)
            let end = min(i + window + 1, b.count)
            guard start < end else { continue }
            for j in start..<end where !bMatched[j] && a[i] == b[j] {
                aMatched[i] = true
                bMatched[j] = true
                matches += 1
                break
            }
        }
        guard matches > 0 else { return 0 }

        // Transpositions: matched characters that appear in a different order.
        var transpositions = 0
        var k = 0
        for i in 0..<a.count where aMatched[i] {
            while !bMatched[k] { k += 1 }
            if a[i] != b[k] { transpositions += 1 }
            k += 1
        }

        let m = Double(matches)
        return (m / Double(a.count)
                + m / Double(b.count)
                + (m - Double(transpositions) / 2) / m) / 3
    }
}
