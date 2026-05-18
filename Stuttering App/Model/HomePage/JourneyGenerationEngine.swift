import Foundation
import SQLite3

final class JourneyGenerationEngine {

    static let shared = JourneyGenerationEngine()

    private let lastRunKey = "journeyGenerationEngine.lastRunDate"
    private let activatedKey = "journeyGenerationEngine.isActivated"
    private let analysisWindowDays = 5
    private let generatedJourneyLength = 10

    private init() {}

    @discardableResult
    func runIfNeeded() -> Bool {
        guard shouldRun else { return false }

        let generatedJourney = buildGeneratedJourney()
        guard !generatedJourney.isEmpty else {
            print("🧠 JourneyGenerationEngine: No generated journey could be produced.")
            return false
        }

        DatabaseManager.shared.replacePendingJourney(with: generatedJourney)
        UserDefaults.standard.set(true, forKey: activatedKey)
        UserDefaults.standard.set(Date(), forKey: lastRunKey)

        if SessionManager.shared.isAccountMode {
            SupabaseSyncManager.shared.pushFullJourneyToCloud()
        }

        print("🧠 JourneyGenerationEngine: Generated \(generatedJourney.count) future journey steps.")
        return true
    }

    func markActivatedFromRestoreIfNeeded(journeyCount: Int) {
        guard journeyCount > DatabaseManager.initialJourneySeedCount else { return }
        UserDefaults.standard.set(true, forKey: activatedKey)
        if UserDefaults.standard.object(forKey: lastRunKey) == nil {
            UserDefaults.standard.set(Date(), forKey: lastRunKey)
        }
    }

    func resetState() {
        UserDefaults.standard.removeObject(forKey: lastRunKey)
        UserDefaults.standard.removeObject(forKey: activatedKey)
    }

    private var shouldRun: Bool {
        let defaults = UserDefaults.standard
        let isActivated = defaults.bool(forKey: activatedKey)

        if !isActivated {
            let total = DatabaseManager.shared.getTotalJourneyCount()
            let completed = DatabaseManager.shared.getCompletedJourneyCount()
            return total > 0 && completed >= total
        }

        guard let lastRun = defaults.object(forKey: lastRunKey) as? Date else {
            return true
        }

        let elapsed = Date().timeIntervalSince(lastRun)
        return elapsed >= TimeInterval(analysisWindowDays * 24 * 60 * 60)
    }

    private func buildGeneratedJourney() -> [String] {
        let catalog = loadExerciseCatalog()
        let availableTitles = Set(catalog.map(\.title))
        let signals = collectSignals()

        var scores: [String: Int] = [:]

        func bump(_ title: String, by value: Int) {
            guard availableTitles.contains(title) else { return }
            scores[title, default: 0] += value
        }

        // Keep a stable foundation in every generated journey.
        bump("Airflow Practice", by: 2)
        bump("Gentle Onset", by: 2)
        bump("Flexible Pacing", by: 1)

        let typeWeights = dominantTypeWeights(from: signals)
        for (type, weight) in typeWeights {
            switch type {
            case "block":
                bump("Preparatory Set", by: 4 + weight)
                bump("Pull-Out", by: 3 + weight)
                bump("Block Correction", by: 5 + weight)
                bump("Airflow Practice", by: 2)
                bump("Gentle Onset", by: 1)
            case "repetition":
                bump("Flexible Pacing", by: 4 + weight)
                bump("Light Contacts", by: 3 + weight)
                bump("Gentle Onset", by: 2)
                bump("Story Cubes", by: 1)
            case "prolongation":
                bump("Prolongation", by: 5 + weight)
                bump("Flexible Pacing", by: 2 + weight)
                bump("Airflow Practice", by: 2)
                bump("Video Diary", by: 1)
            default:
                break
            }
        }

        for group in signals.phonemeGroups {
            let normalized = group.lowercased()
            if normalized.contains("plosive") {
                bump("Light Contacts", by: 4)
            }
            if normalized.contains("fricative") {
                bump("Prolongation", by: 4)
            }
            if normalized.contains("vowel") || normalized.contains("voiced") {
                bump("Gentle Onset", by: 4)
                bump("Airflow Practice", by: 3)
            }
        }

        for letter in signals.topLetters {
            switch letter.uppercased() {
            case "P", "B", "T", "D", "K", "G":
                bump("Light Contacts", by: 2)
            case "S", "F", "H", "Z":
                bump("Prolongation", by: 2)
            case "A", "E", "I", "O", "U", "M", "N", "L":
                bump("Gentle Onset", by: 2)
                bump("Airflow Practice", by: 1)
            default:
                break
            }
        }

        if signals.totalSessions >= 5 && signals.totalEvents <= 10 {
            bump("Story Cubes", by: 3)
            bump("Video Diary", by: 3)
            bump("Tongue Twisters", by: 2)
        }

        let fallbackOrder = [
            "Airflow Practice",
            "Gentle Onset",
            "Flexible Pacing",
            "Light Contacts",
            "Prolongation",
            "Preparatory Set",
            "Pull-Out",
            "Block Correction",
            "Story Cubes",
            "Video Diary",
            "Tongue Twisters"
        ].filter { availableTitles.contains($0) }

        var ranked = scores
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key < rhs.key
                }
                return lhs.value > rhs.value
            }
            .map(\.key)

        for fallback in fallbackOrder where !ranked.contains(fallback) {
            ranked.append(fallback)
        }

        var generated: [String] = []
        for title in ranked {
            let repeatCount = min(3, max(1, (scores[title, default: 1] + 1) / 3))
            for _ in 0..<repeatCount {
                generated.append(title)
                if generated.count == generatedJourneyLength {
                    return generated
                }
            }
        }

        return Array(generated.prefix(generatedJourneyLength))
    }

    private func dominantTypeWeights(from signals: JourneyGenerationSignals) -> [String: Int] {
        let buckets = [
            ("block", signals.blockCount),
            ("repetition", signals.repetitionCount),
            ("prolongation", signals.prolongationCount)
        ]
        let maxCount = buckets.map(\.1).max() ?? 0
        guard maxCount > 0 else { return [:] }

        return Dictionary(
            uniqueKeysWithValues: buckets.compactMap { type, count in
                guard count > 0 else { return nil }
                let weight = count >= maxCount ? 2 : 1
                return (type, weight)
            }
        )
    }

    private func collectSignals() -> JourneyGenerationSignals {
        guard let userId = LogManager.shared.getCurrentUserId(),
              let logDB = LogManager.shared.db else {
            return JourneyGenerationSignals(
                repetitionCount: 0,
                prolongationCount: 0,
                blockCount: 0,
                totalEvents: 0,
                totalSessions: 0,
                topLetters: [],
                phonemeGroups: DatabaseManager.shared.fetchUserProblemPhonemes()
            )
        }

        let sinceEpoch = Date()
            .addingTimeInterval(TimeInterval(-analysisWindowDays * 24 * 60 * 60))
            .timeIntervalSince1970

        let sessionTotalsQuery = """
            SELECT COALESCE(SUM(repetitionCount), 0),
                   COALESCE(SUM(prolongationCount), 0),
                   COALESCE(SUM(blockCount), 0),
                   COALESCE(SUM(stutteredWordCount), 0),
                   COUNT(*)
            FROM ReadingSessions
            WHERE userId = ? AND date >= ?;
            """

        var repetitionCount = 0
        var prolongationCount = 0
        var blockCount = 0
        var totalEvents = 0
        var totalSessions = 0
        var statement: OpaquePointer?

        if sqlite3_prepare_v2(logDB, sessionTotalsQuery, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (userId as NSString).utf8String, -1, nil)
            sqlite3_bind_double(statement, 2, sinceEpoch)
            if sqlite3_step(statement) == SQLITE_ROW {
                repetitionCount = Int(sqlite3_column_int(statement, 0))
                prolongationCount = Int(sqlite3_column_int(statement, 1))
                blockCount = Int(sqlite3_column_int(statement, 2))
                totalEvents = Int(sqlite3_column_int(statement, 3))
                totalSessions = Int(sqlite3_column_int(statement, 4))
            }
        }
        sqlite3_finalize(statement)

        let topLettersQuery = """
            SELECT s.letter, COALESCE(SUM(s.stutterCount), 0) AS total_count
            FROM SessionLetterStats s
            INNER JOIN ReadingSessions r ON r.id = s.sessionId
            WHERE r.userId = ? AND r.date >= ?
            GROUP BY s.letter
            ORDER BY total_count DESC, s.letter ASC
            LIMIT 3;
            """

        var topLetters: [String] = []
        if sqlite3_prepare_v2(logDB, topLettersQuery, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (userId as NSString).utf8String, -1, nil)
            sqlite3_bind_double(statement, 2, sinceEpoch)
            while sqlite3_step(statement) == SQLITE_ROW {
                if let letterCString = sqlite3_column_text(statement, 0) {
                    topLetters.append(String(cString: letterCString))
                }
            }
        }
        sqlite3_finalize(statement)

        return JourneyGenerationSignals(
            repetitionCount: repetitionCount,
            prolongationCount: prolongationCount,
            blockCount: blockCount,
            totalEvents: totalEvents,
            totalSessions: totalSessions,
            topLetters: topLetters,
            phonemeGroups: DatabaseManager.shared.fetchUserProblemPhonemes()
        )
    }

    private func loadExerciseCatalog() -> [ExerciseCatalogItem] {
        let decoder = JSONDecoder()
        let resourceNames = ["ExerciseData", "exerciselogs"]

        for resource in resourceNames {
            if let url = Bundle.main.url(forResource: resource, withExtension: "json"),
               let data = try? Data(contentsOf: url),
               let payload = try? decoder.decode(ExerciseCatalogPayload.self, from: data) {
                return payload.modules.flatMap(\.exercises)
            }
        }

        return [
            ExerciseCatalogItem(title: "Airflow Practice", category: "Respiration", targetGroup: "Vowel Initiation"),
            ExerciseCatalogItem(title: "Flexible Pacing", category: "Phonation & Timing", targetGroup: "Multi-syllabic Words"),
            ExerciseCatalogItem(title: "Preparatory Set", category: "Anticipation Management", targetGroup: "Feared Words"),
            ExerciseCatalogItem(title: "Pull-Out", category: "In-Block Correction", targetGroup: "Release from a Block"),
            ExerciseCatalogItem(title: "Block Correction", category: "Post-Block Correction", targetGroup: "Recovery"),
            ExerciseCatalogItem(title: "Gentle Onset", category: "Easy Voicing", targetGroup: "Vowels and Voiced Sounds"),
            ExerciseCatalogItem(title: "Light Contacts", category: "Articulation", targetGroup: "Plosive Sounds"),
            ExerciseCatalogItem(title: "Prolongation", category: "Continuous Phonation", targetGroup: "Fricative Sounds"),
            ExerciseCatalogItem(title: "Tongue Twisters", category: "Challenge", targetGroup: "Precision"),
            ExerciseCatalogItem(title: "Video Diary", category: "Generalization", targetGroup: "Spontaneous Speech"),
            ExerciseCatalogItem(title: "Story Cubes", category: "Generalization", targetGroup: "Narration")
        ]
    }
}

private struct JourneyGenerationSignals {
    let repetitionCount: Int
    let prolongationCount: Int
    let blockCount: Int
    let totalEvents: Int
    let totalSessions: Int
    let topLetters: [String]
    let phonemeGroups: [String]
}

private struct ExerciseCatalogPayload: Decodable {
    let modules: [ExerciseCatalogModule]
}

private struct ExerciseCatalogModule: Decodable {
    let exercises: [ExerciseCatalogItem]
}

private struct ExerciseCatalogItem: Decodable {
    let title: String
    let category: String?
    let targetGroup: String?

    enum CodingKeys: String, CodingKey {
        case title
        case category
        case targetGroup = "target_group"
    }
}
