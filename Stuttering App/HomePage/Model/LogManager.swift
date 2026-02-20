import Foundation
import SQLite3

// MARK: - Enums

enum TrendDirection {
    case up, down, neutral
}

// MARK: - Analytics Models

struct DayReport {
    let date: Date
    let sessionCount: Int
    let avgFluencyScore: Double
    let avgBlockPercent: Double
    let avgAccuracy: Double
    let fluencyGrowth: Double
    let improvementPercent: Double
    let insight: String                 // e.g. "Your 'r' and 's' sounds have improved 12% today!!"
}

struct OverallProgressReport {

    // MARK: Top Bar
    let daysPracticed: Int
    let activeStreak: Int
    let totalHours: Double

    // MARK: Headline
    let headlineInsight: String         // e.g. "You're speaking with remarkable smoothness and confidence!"

    // MARK: Key Metrics
    let fluencyGrowthPercent: Double
    let fluencyTrend: TrendDirection
    let avgBlockPercent: Double
    let blocksTrend: TrendDirection
    let avgAccuracy: Double
    let accuracyTrend: TrendDirection
    let improvementPercent: Double
    let improvementTrend: TrendDirection

    // MARK: Exercise
    let exercisesCompleted: Int
    let exercisesGoal: Int
    let totalExerciseMinutesThisWeek: Int
    let mostPracticedTechnique: String

    // MARK: Reading
    let avgBlocksPerReading: Double
    let readingBlockTrend: TrendDirection
    let avgReadingDuration: TimeInterval        // seconds
    let longestSmoothParagraph: Int             // seconds

    // MARK: Conversation
    let avgFillerWordPercent: Double
    let fillerTrend: TrendDirection
    let avgConversationDuration: TimeInterval   // seconds
    let longestSmoothTalk: Int                  // seconds

    // MARK: Weekly Trend
    let weeklyTrend: [WeeklyPoint]
}

struct WeeklyPoint {
    let date: Date
    let avgFluency: Double
}

// MARK: - LogManager

class LogManager {

    static let shared = LogManager()

    private var db: OpaquePointer?
    private let dbName = "ExerciseDatabase.sqlite"
    private var currentUserId: String?

    struct GoalKeys {
        static let exercise     = "Goal_Exercise"
        static let reading      = "Goal_Reading"
        static let conversation = "Goal_Conversation"
    }

    private init() {
        openDatabase()
        createTables()
        runMigrations()
        initializeDefaultGoals()
    }

    // MARK: - Database Setup

    private func openDatabase() {
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent(dbName)
        print("Database Path: \(fileURL.path)")
        if sqlite3_open(fileURL.path, &db) != SQLITE_OK {
            print("Error: Unable to open database.")
        }
    }

    private func createTables() {

        execute(sql: """
            CREATE TABLE IF NOT EXISTS ExerciseLog(
                id TEXT PRIMARY KEY,
                exerciseName TEXT,
                completionDate REAL,
                source TEXT,
                exerciseDuration INTEGER
            );
            """, successMessage: "ExerciseLog table ready.")

        execute(sql: """
            CREATE TABLE IF NOT EXISTS Goals(
                goalName TEXT PRIMARY KEY,
                goalValue INTEGER
            );
            """, successMessage: "Goals table ready.")

        execute(sql: """
            CREATE TABLE IF NOT EXISTS StutterStats(
                letter TEXT PRIMARY KEY,
                count INTEGER
            );
            """, successMessage: "StutterStats table ready.")

        execute(sql: """
            CREATE TABLE IF NOT EXISTS Users(
                id TEXT PRIMARY KEY,
                email TEXT UNIQUE NOT NULL,
                createdAt REAL
            );
            """, successMessage: "Users table ready.")

        // ReadingSessions — duration and longestSmoothParagraph included from the start
        execute(sql: """
            CREATE TABLE IF NOT EXISTS ReadingSessions(
                id TEXT PRIMARY KEY,
                userId TEXT,
                date REAL,
                duration REAL,
                fluencyScore INTEGER,
                repetitionPercent REAL,
                prolongationPercent REAL,
                blockPercent REAL,
                correctPercent REAL,
                longestSmoothParagraph INTEGER DEFAULT 0,
                FOREIGN KEY(userId) REFERENCES Users(id)
            );
            """, successMessage: "ReadingSessions table ready.")

        execute(sql: """
            CREATE TABLE IF NOT EXISTS TroubledWords(
                id TEXT PRIMARY KEY,
                sessionId TEXT,
                userId TEXT,
                word TEXT,
                type TEXT,
                firstLetter TEXT,
                FOREIGN KEY(sessionId) REFERENCES ReadingSessions(id),
                FOREIGN KEY(userId) REFERENCES Users(id)
            );
            """, successMessage: "TroubledWords table ready.")

        execute(sql: """
            CREATE TABLE IF NOT EXISTS LetterStats(
                userId TEXT,
                letter TEXT,
                count INTEGER,
                PRIMARY KEY(userId, letter),
                FOREIGN KEY(userId) REFERENCES Users(id)
            );
            """, successMessage: "LetterStats table ready.")

        // Per-session letter counts — enables day-level letter improvement insight
        execute(sql: """
            CREATE TABLE IF NOT EXISTS SessionLetterStats(
                sessionId TEXT,
                userId TEXT,
                letter TEXT,
                stutterCount INTEGER,
                PRIMARY KEY(sessionId, letter),
                FOREIGN KEY(sessionId) REFERENCES ReadingSessions(id),
                FOREIGN KEY(userId) REFERENCES Users(id)
            );
            """, successMessage: "SessionLetterStats table ready.")

        execute(sql: """
            CREATE TABLE IF NOT EXISTS ConversationSessions(
                id TEXT PRIMARY KEY,
                userId TEXT,
                date REAL,
                duration REAL,
                fillerWordPercent REAL,
                longestSmoothTalk INTEGER DEFAULT 0,
                FOREIGN KEY(userId) REFERENCES Users(id)
            );
            """, successMessage: "ConversationSessions table ready.")
    }

    /// Safe ALTER TABLE migrations for users upgrading from older schema versions.
    private func runMigrations() {
        let migrations = [
            "ALTER TABLE ReadingSessions ADD COLUMN longestSmoothParagraph INTEGER DEFAULT 0;"
        ]
        for sql in migrations {
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            sqlite3_step(stmt)  // silently fails if column already exists — that's fine
            sqlite3_finalize(stmt)
        }
    }

    private func execute(sql: String, successMessage: String) {
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_DONE { print(successMessage) }
        } else {
            print("SQL Execution Failed: \(sql)")
        }
        sqlite3_finalize(statement)
    }

    // MARK: - User Management

    func initializeUserIfNeeded() {
        guard let email = StorageManager.shared.getEmail() else {
            print("No email found in storage.")
            return
        }
        currentUserId = createOrGetUser(email: email)
    }

    func getCurrentUserId() -> String? {
        if currentUserId == nil { initializeUserIfNeeded() }
        return currentUserId
    }

    func createOrGetUser(email: String) -> String {
        let checkSQL = "SELECT id FROM Users WHERE email = ?;"
        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, checkSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (email as NSString).utf8String, -1, nil)
            if sqlite3_step(statement) == SQLITE_ROW,
               let idCStr = sqlite3_column_text(statement, 0) {
                let userId = String(cString: idCStr)
                sqlite3_finalize(statement)
                return userId
            }
        }
        sqlite3_finalize(statement)

        let insertSQL = "INSERT INTO Users (id, email, createdAt) VALUES (?, ?, ?);"
        let newId = UUID().uuidString
        let now   = Date().timeIntervalSince1970

        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (newId as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (email as NSString).utf8String, -1, nil)
            sqlite3_bind_double(statement, 3, now)
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
        return newId
    }

    // MARK: - Goals

    private func initializeDefaultGoals() {
        let defaults: [(String, Int)] = [
            (GoalKeys.exercise,     10),
            (GoalKeys.reading,      20),
            (GoalKeys.conversation, 20)
        ]
        let insertSQL = "INSERT OR IGNORE INTO Goals (goalName, goalValue) VALUES (?, ?);"
        for (name, value) in defaults {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (name as NSString).utf8String, -1, nil)
                sqlite3_bind_int(statement, 2, Int32(value))
                if sqlite3_step(statement) == SQLITE_DONE { print("Initialized default goal: \(name)") }
            }
            sqlite3_finalize(statement)
        }
    }

    func updateGoal(name: String, value: Int) {
        let sql = "INSERT OR REPLACE INTO Goals (goalName, goalValue) VALUES (?, ?);"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (name as NSString).utf8String, -1, nil)
            sqlite3_bind_int(statement, 2, Int32(value))
            if sqlite3_step(statement) == SQLITE_DONE { print("Updated \(name) to \(value)") }
            else { print("Failed to update goal.") }
        }
        sqlite3_finalize(statement)
    }

    func getGoal(name: String) -> Int {
        let sql = "SELECT goalValue FROM Goals WHERE goalName = ?;"
        var statement: OpaquePointer?
        var result = 0
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (name as NSString).utf8String, -1, nil)
            if sqlite3_step(statement) == SQLITE_ROW {
                result = Int(sqlite3_column_int(statement, 0))
            }
        }
        sqlite3_finalize(statement)
        return result
    }

    // MARK: - Exercise Log

    func addLog(exerciseName: String, source: ExerciseSource, exerciseDuration: Int) {
        let sql = "INSERT INTO ExerciseLog (id, exerciseName, completionDate, source, exerciseDuration) VALUES (?, ?, ?, ?, ?);"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1,   (UUID().uuidString as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2,   (exerciseName as NSString).utf8String, -1, nil)
            sqlite3_bind_double(statement, 3, Date().timeIntervalSince1970)
            sqlite3_bind_text(statement, 4,   (source.rawValue as NSString).utf8String, -1, nil)
            sqlite3_bind_int(statement, 5,    Int32(exerciseDuration))
            if sqlite3_step(statement) == SQLITE_DONE { print("Log inserted.") }
            else { print("Could not insert row.") }
        }
        sqlite3_finalize(statement)
    }

    func getLogs(for source: ExerciseSource, on date: Date? = nil) -> [ExerciseLog] {
        let sql = "SELECT * FROM ExerciseLog WHERE source = ?;"
        var statement: OpaquePointer?
        var resultLogs: [ExerciseLog] = []

        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (source.rawValue as NSString).utf8String, -1, nil)
            while sqlite3_step(statement) == SQLITE_ROW {
                guard
                    let idCStr     = sqlite3_column_text(statement, 0),
                    let nameCStr   = sqlite3_column_text(statement, 1),
                    let sourceCStr = sqlite3_column_text(statement, 3)
                else { continue }

                let idString     = String(cString: idCStr)
                let nameString   = String(cString: nameCStr)
                let dateDouble   = sqlite3_column_double(statement, 2)
                let sourceString = String(cString: sourceCStr)
                let durationInt  = Int(sqlite3_column_int(statement, 4))

                if let sourceEnum = ExerciseSource(rawValue: sourceString),
                   let uuid = UUID(uuidString: idString) {
                    resultLogs.append(ExerciseLog(
                        id: uuid,
                        exerciseName: nameString,
                        completionDate: Date(timeIntervalSince1970: dateDouble),
                        source: sourceEnum,
                        exerciseDuration: durationInt
                    ))
                }
            }
        }
        sqlite3_finalize(statement)

        if let targetDate = date {
            return resultLogs.filter {
                Calendar.current.isDate($0.completionDate, inSameDayAs: targetDate)
            }
        }
        return resultLogs
    }

    // MARK: - Reading Sessions

    /// Pass `duration` in seconds and `longestSmoothParagraph` in seconds.
    func saveReadingSession(report: StutterJSONReport,
                            duration: TimeInterval = 0,
                            longestSmoothParagraph: Int = 0) {
        guard let userId = getCurrentUserId() else {
            print("User not initialized.")
            return
        }

        let sessionId = UUID().uuidString
        let now       = Date().timeIntervalSince1970

        let sql = """
            INSERT INTO ReadingSessions
            (id, userId, date, duration, fluencyScore,
             repetitionPercent, prolongationPercent,
             blockPercent, correctPercent, longestSmoothParagraph)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1,   (sessionId as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2,   (userId as NSString).utf8String, -1, nil)
            sqlite3_bind_double(statement, 3, now)
            sqlite3_bind_double(statement, 4, duration)
            sqlite3_bind_int(statement, 5,    Int32(report.fluencyScore))
            sqlite3_bind_double(statement, 6, report.percentages.repetition)
            sqlite3_bind_double(statement, 7, report.percentages.prolongation)
            sqlite3_bind_double(statement, 8, report.percentages.blocks)
            sqlite3_bind_double(statement, 9, report.percentages.correct)
            sqlite3_bind_int(statement, 10,   Int32(longestSmoothParagraph))

            if sqlite3_step(statement) == SQLITE_DONE {
                print("ReadingSession inserted successfully.")
            } else {
                print("Error inserting ReadingSession.")
            }
        }
        sqlite3_finalize(statement)

        saveTroubledWords(report: report, userId: userId, sessionId: sessionId)
        updateLetterStats(userId: userId, letterCounts: report.letterAnalysis)
        saveSessionLetterStats(userId: userId, sessionId: sessionId, letterCounts: report.letterAnalysis)
        print("Saved reading session for user: \(userId)")
    }

    private func saveTroubledWords(report: StutterJSONReport, userId: String, sessionId: String) {
        let sql = """
            INSERT INTO TroubledWords (id, sessionId, userId, word, type, firstLetter)
            VALUES (?, ?, ?, ?, ?, ?);
            """
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            for word in report.stutteredWords {
                sqlite3_reset(statement)
                sqlite3_clear_bindings(statement)

                let wordId      = UUID().uuidString
                let firstLetter = String(word.prefix(1)).uppercased()
                let type: String

                if report.breakdown.repetition.contains(word)       { type = "repetition" }
                else if report.breakdown.prolongation.contains(word) { type = "prolongation" }
                else                                                  { type = "block" }

                sqlite3_bind_text(statement, 1, (wordId as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 2, (sessionId as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 3, (userId as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 4, (word as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 5, (type as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 6, (firstLetter as NSString).utf8String, -1, nil)
                sqlite3_step(statement)
            }
        }
        sqlite3_finalize(statement)
    }

    /// Saves per-session letter stutter counts for the letter-improvement insight engine.
    private func saveSessionLetterStats(userId: String, sessionId: String, letterCounts: [String: Int]) {
        let sql = """
            INSERT OR REPLACE INTO SessionLetterStats (sessionId, userId, letter, stutterCount)
            VALUES (?, ?, ?, ?);
            """
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            for (letter, count) in letterCounts {
                sqlite3_reset(statement)
                sqlite3_clear_bindings(statement)
                sqlite3_bind_text(statement, 1, (sessionId as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 2, (userId as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 3, (letter as NSString).utf8String, -1, nil)
                sqlite3_bind_int(statement, 4, Int32(count))
                sqlite3_step(statement)
            }
        }
        sqlite3_finalize(statement)
    }

    func updateLetterStats(userId: String, letterCounts: [String: Int]) {
        let sql = """
            INSERT INTO LetterStats (userId, letter, count)
            VALUES (?, ?, ?)
            ON CONFLICT(userId, letter)
            DO UPDATE SET count = count + excluded.count;
            """
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            for (letter, count) in letterCounts {
                sqlite3_reset(statement)
                sqlite3_clear_bindings(statement)
                sqlite3_bind_text(statement, 1, (userId as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 2, (letter as NSString).utf8String, -1, nil)
                sqlite3_bind_int(statement, 3, Int32(count))
                sqlite3_step(statement)
            }
        }
        sqlite3_finalize(statement)
    }

    func getAllTroubledWords(for userId: String) -> [String] {
        let sql = "SELECT word FROM TroubledWords WHERE userId = ?;"
        var statement: OpaquePointer?
        var words: [String] = []
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (userId as NSString).utf8String, -1, nil)
            while sqlite3_step(statement) == SQLITE_ROW {
                if let wordCStr = sqlite3_column_text(statement, 0) {
                    words.append(String(cString: wordCStr))
                }
            }
        }
        sqlite3_finalize(statement)
        return words
    }

    func getTopLetters(for userId: String, limit: Int) -> [String] {
        let sql = """
            SELECT letter FROM LetterStats
            WHERE userId = ?
            ORDER BY count DESC
            LIMIT ?;
            """
        var statement: OpaquePointer?
        var letters: [String] = []
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (userId as NSString).utf8String, -1, nil)
            sqlite3_bind_int(statement, 2, Int32(limit))
            while sqlite3_step(statement) == SQLITE_ROW {
                if let letterCStr = sqlite3_column_text(statement, 0) {
                    letters.append(String(cString: letterCStr))
                }
            }
        }
        sqlite3_finalize(statement)
        return letters
    }

    // MARK: - Conversation Sessions

    /// Call this at the end of every conversation session.
    func saveConversationSession(duration: TimeInterval,
                                 fillerWordPercent: Double,
                                 longestSmoothTalk: Int) {
        guard let userId = getCurrentUserId() else {
            print("User not initialized.")
            return
        }
        let sql = """
            INSERT INTO ConversationSessions
            (id, userId, date, duration, fillerWordPercent, longestSmoothTalk)
            VALUES (?, ?, ?, ?, ?, ?);
            """
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1,   (UUID().uuidString as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2,   (userId as NSString).utf8String, -1, nil)
            sqlite3_bind_double(statement, 3, Date().timeIntervalSince1970)
            sqlite3_bind_double(statement, 4, duration)
            sqlite3_bind_double(statement, 5, fillerWordPercent)
            sqlite3_bind_int(statement, 6,    Int32(longestSmoothTalk))
            if sqlite3_step(statement) == SQLITE_DONE { print("ConversationSession inserted.") }
        }
        sqlite3_finalize(statement)
    }

    // MARK: - Stutter Stats (global/legacy)

    func updateStutterStats(letterCounts: [String: Int]) {
        let sql = """
            INSERT INTO StutterStats (letter, count) VALUES (?, ?)
            ON CONFLICT(letter) DO UPDATE SET count = count + excluded.count;
            """
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            for (letter, count) in letterCounts {
                sqlite3_reset(statement)
                sqlite3_clear_bindings(statement)
                sqlite3_bind_text(statement, 1, (letter as NSString).utf8String, -1, nil)
                sqlite3_bind_int(statement, 2, Int32(count))
                if sqlite3_step(statement) != SQLITE_DONE { print("Failed to update letter: \(letter)") }
            }
            print("Stutter stats updated.")
        }
        sqlite3_finalize(statement)
    }

    func getTopStruggledLetters(limit: Int) -> [String] {
        let sql = "SELECT letter FROM StutterStats ORDER BY count DESC LIMIT ?;"
        var statement: OpaquePointer?
        var letters: [String] = []
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(limit))
            while sqlite3_step(statement) == SQLITE_ROW {
                if let letterCStr = sqlite3_column_text(statement, 0) {
                    letters.append(String(cString: letterCStr))
                }
            }
        }
        sqlite3_finalize(statement)
        return letters
    }

    func resetStutterStats() {
        execute(sql: "DELETE FROM StutterStats;", successMessage: "Stutter stats reset.")
    }

    // MARK: - Debug

    func debugPrintAllReadingSessions() {
        let sql = "SELECT id, userId, fluencyScore, date FROM ReadingSessions;"
        var statement: OpaquePointer?
        print("----- ReadingSessions Table -----")
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id     = String(cString: sqlite3_column_text(statement, 0))
                let userId = String(cString: sqlite3_column_text(statement, 1))
                let score  = sqlite3_column_int(statement, 2)
                let date   = sqlite3_column_double(statement, 3)
                print("SessionID:", id, "| UserID:", userId, "| Score:", score,
                      "| Date:", Date(timeIntervalSince1970: date))
            }
        }
        sqlite3_finalize(statement)
    }
}

// MARK: - Day Analytics

extension LogManager {

    /// All session rows for a given calendar day (current user).
    func getSessionsForDay(_ date: Date) -> [[String: Any]] {
        guard let userId = getCurrentUserId() else { return [] }

        let sql = """
            SELECT fluencyScore, repetitionPercent, prolongationPercent,
                   blockPercent, correctPercent, date, duration, longestSmoothParagraph
            FROM ReadingSessions
            WHERE userId = ? AND date >= ? AND date < ?;
            """

        let cal        = Calendar.current
        let startOfDay = cal.startOfDay(for: date).timeIntervalSince1970
        let endOfDay   = startOfDay + 86400

        var statement: OpaquePointer?
        var rows: [[String: Any]] = []

        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (userId as NSString).utf8String, -1, nil)
            sqlite3_bind_double(statement, 2, startOfDay)
            sqlite3_bind_double(statement, 3, endOfDay)
            while sqlite3_step(statement) == SQLITE_ROW {
                rows.append([
                    "fluencyScore":           Int(sqlite3_column_int(statement, 0)),
                    "repetitionPercent":      sqlite3_column_double(statement, 1),
                    "prolongationPercent":    sqlite3_column_double(statement, 2),
                    "blockPercent":           sqlite3_column_double(statement, 3),
                    "correctPercent":         sqlite3_column_double(statement, 4),
                    "date":                   sqlite3_column_double(statement, 5),
                    "duration":               sqlite3_column_double(statement, 6),
                    "longestSmoothParagraph": Int(sqlite3_column_int(statement, 7))
                ])
            }
        }
        sqlite3_finalize(statement)
        return rows
    }

    /// Full DayReport including a personalized insight.
    /// Foundation model is tried first; rule-based chain is the fallback.
    func getDayReport(for date: Date) async -> DayReport? {
        let sessions = getSessionsForDay(date)
        guard !sessions.isEmpty else { return nil }

        let count       = Double(sessions.count)
        let avgFluency  = sessions.map { $0["fluencyScore"] as! Int }.reduce(0, +).asDouble / count
        let avgBlock    = sessions.map { $0["blockPercent"] as! Double }.reduce(0, +) / count
        let avgAccuracy = sessions.map { $0["correctPercent"] as! Double }.reduce(0, +) / count

        let yesterday    = Calendar.current.date(byAdding: .day, value: -1, to: date)!
        let prevSessions = getSessionsForDay(yesterday)

        var fluencyGrowth      = 0.0
        var improvementPercent = 0.0

        if !prevSessions.isEmpty {
            let prevAvg        = prevSessions.map { $0["fluencyScore"] as! Int }.reduce(0, +).asDouble / Double(prevSessions.count)
            fluencyGrowth      = avgFluency - prevAvg
            improvementPercent = prevAvg > 0 ? (fluencyGrowth / prevAvg) * 100 : 0
        }

        let context = DayInsightContext(
            avgFluency: avgFluency,
            avgBlock: avgBlock,
            avgAccuracy: avgAccuracy,
            fluencyGrowth: fluencyGrowth,
            improvementPercent: improvementPercent,
            sessionCount: sessions.count,
            topImprovedLetters: buildTopImprovedLetters(for: date)
        )

        let insight = await InsightEngine.shared.dayInsight(context: context)

        return DayReport(
            date: date,
            sessionCount: sessions.count,
            avgFluencyScore: avgFluency,
            avgBlockPercent: avgBlock,
            avgAccuracy: avgAccuracy,
            fluencyGrowth: fluencyGrowth,
            improvementPercent: improvementPercent,
            insight: insight
        )
    }

    // MARK: - Letter Data Builder

    /// Computes top improved letters for today vs prior 7 days.
    /// Passed as context to InsightEngine so both AI and fallback have the same data.
    private func buildTopImprovedLetters(for date: Date) -> [(letter: String, improvementPct: Double)] {
        guard let userId = getCurrentUserId() else { return [] }

        let cal        = Calendar.current
        let startOfDay = cal.startOfDay(for: date).timeIntervalSince1970
        let endOfDay   = startOfDay + 86400

        let periodSQL = """
            SELECT s.letter, AVG(s.stutterCount) as avgCount
            FROM SessionLetterStats s
            INNER JOIN ReadingSessions r ON s.sessionId = r.id
            WHERE s.userId = ? AND r.date >= ? AND r.date < ?
            GROUP BY s.letter;
            """

        let todayCounts = fetchLetterAvgs(sql: periodSQL, userId: userId,
                                          start: startOfDay, end: endOfDay)
        guard !todayCounts.isEmpty else { return [] }

        let sevenDaysAgo = startOfDay - (7 * 86400)
        let prevCounts   = fetchLetterAvgs(sql: periodSQL, userId: userId,
                                           start: sevenDaysAgo, end: startOfDay)
        guard !prevCounts.isEmpty else { return [] }

        return todayCounts
            .compactMap { letter, todayAvg -> (String, Double)? in
                guard let prevAvg = prevCounts[letter], prevAvg > 0 else { return nil }
                let pct = ((prevAvg - todayAvg) / prevAvg) * 100
                return pct >= 10 ? (letter.lowercased(), pct) : nil
            }
            .sorted { $0.1 > $1.1 }
            .prefix(2)
            .map { $0 }
    }

    private func fetchLetterAvgs(sql: String, userId: String,
                                  start: Double, end: Double) -> [String: Double] {
        var stmt: OpaquePointer?
        var result: [String: Double] = [:]
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (userId as NSString).utf8String, -1, nil)
            sqlite3_bind_double(stmt, 2, start)
            sqlite3_bind_double(stmt, 3, end)
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let cStr = sqlite3_column_text(stmt, 0) {
                    result[String(cString: cStr)] = sqlite3_column_double(stmt, 1)
                }
            }
        }
        sqlite3_finalize(stmt)
        return result
    }
}

// MARK: - Overall Progress Report

extension LogManager {

    func getOverallProgressReport() async -> OverallProgressReport? {
        guard let userId = getCurrentUserId() else { return nil }

        // ── Top Bar ──────────────────────────────────────────────────────────
        let daysPracticed = getDaysPracticed(userId: userId)
        guard daysPracticed > 0 else { return nil }

        let activeStreak = calculateStreak(userId: userId)
        let totalHours   = getTotalReadingHours(userId: userId)

        // ── Key Metrics ──────────────────────────────────────────────────────
        let firstFluency  = getFirstSessionFluency(userId: userId)
        let latestFluency = getLatestSessionFluency(userId: userId)
        let fluencyGrowthPct: Double = firstFluency > 0
            ? ((latestFluency - firstFluency) / firstFluency) * 100 : 0

        let (avgBlock, avgAccuracy) = getAvgBlockAndAccuracy(userId: userId)

        let (thisWeekFluency, lastWeekFluency) = getWeekOverWeekFluency(userId: userId)
        let improvementPct: Double = lastWeekFluency > 0
            ? ((thisWeekFluency - lastWeekFluency) / lastWeekFluency) * 100 : 0

        // ── Trends ───────────────────────────────────────────────────────────
        let blockThisWeek = getAvgBlockThisWeek(userId: userId)
        let blockLastWeek = getAvgBlockLastWeek(userId: userId)
        let accThisWeek   = getAvgAccuracyThisWeek(userId: userId)
        let accLastWeek   = getAvgAccuracyLastWeek(userId: userId)
        let fillerThis    = getFillerThisWeek(userId: userId)
        let fillerLast    = getFillerLastWeek(userId: userId)

        let fluencyTrend      = trend(current: thisWeekFluency,  previous: lastWeekFluency)
        let blocksTrend       = trendInverse(current: blockThisWeek, previous: blockLastWeek)
        let accuracyTrend     = trend(current: accThisWeek,      previous: accLastWeek)
        let improvementTrend  = trend(current: improvementPct,   previous: 0)
        let fillerTrend       = trendInverse(current: fillerThis, previous: fillerLast)
        let readingBlockTrend = trendInverse(current: blockThisWeek, previous: blockLastWeek)

        // ── Exercise ─────────────────────────────────────────────────────────
        let exercisesCompleted          = getLogs(for: .exercises).count
        let exercisesGoal               = getGoal(name: GoalKeys.exercise)
        let totalExerciseMinutesThisWeek = getExerciseMinutesThisWeek()
        let mostPracticedTechnique      = getMostPracticedExercise()

        // ── Reading ──────────────────────────────────────────────────────────
        let avgReadingDuration    = getAvgReadingDuration(userId: userId)
        let longestSmoothParagraph = getLongestSmoothParagraph(userId: userId)

        // ── Conversation ─────────────────────────────────────────────────────
        let avgFillerWordPercent    = getAvgFillerWordPercent(userId: userId)
        let avgConversationDuration = getAvgConversationDuration(userId: userId)
        let longestSmoothTalk       = getLongestSmoothTalk(userId: userId)

        // ── Headline ─────────────────────────────────────────────────────────
        let overallContext = OverallInsightContext(
            fluencyGrowthPercent: fluencyGrowthPct,
            avgAccuracy: avgAccuracy,
            avgBlock: avgBlock,
            streak: activeStreak,
            weekOverWeekImprovementPct: improvementPct,
            daysPracticed: daysPracticed,
            mostCommonStutterType: getMostCommonStutterType(userId: userId)
        )
        let headline = await InsightEngine.shared.overallHeadline(context: overallContext)

        return OverallProgressReport(
            daysPracticed: daysPracticed,
            activeStreak: activeStreak,
            totalHours: totalHours,
            headlineInsight: headline,
            fluencyGrowthPercent: fluencyGrowthPct,
            fluencyTrend: fluencyTrend,
            avgBlockPercent: avgBlock,
            blocksTrend: blocksTrend,
            avgAccuracy: avgAccuracy,
            accuracyTrend: accuracyTrend,
            improvementPercent: improvementPct,
            improvementTrend: improvementTrend,
            exercisesCompleted: exercisesCompleted,
            exercisesGoal: exercisesGoal,
            totalExerciseMinutesThisWeek: totalExerciseMinutesThisWeek,
            mostPracticedTechnique: mostPracticedTechnique,
            avgBlocksPerReading: avgBlock,
            readingBlockTrend: readingBlockTrend,
            avgReadingDuration: avgReadingDuration,
            longestSmoothParagraph: longestSmoothParagraph,
            avgFillerWordPercent: avgFillerWordPercent,
            fillerTrend: fillerTrend,
            avgConversationDuration: avgConversationDuration,
            longestSmoothTalk: longestSmoothTalk,
            weeklyTrend: getWeeklyTrend(userId: userId)
        )
    }

    // MARK: - Top Bar

    private func getDaysPracticed(userId: String) -> Int {
        let sql = """
            SELECT COUNT(DISTINCT CAST(date / 86400 AS INTEGER))
            FROM ReadingSessions WHERE userId = ?;
            """
        return singleIntQuery(sql: sql, userId: userId)
    }

    private func getTotalReadingHours(userId: String) -> Double {
        let sql = "SELECT SUM(duration) FROM ReadingSessions WHERE userId = ?;"
        var stmt: OpaquePointer?
        var total = 0.0
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (userId as NSString).utf8String, -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW { total = sqlite3_column_double(stmt, 0) / 3600 }
        }
        sqlite3_finalize(stmt)
        return total
    }

    // MARK: - Fluency

    private func getFirstSessionFluency(userId: String) -> Double {
        let sql = "SELECT fluencyScore FROM ReadingSessions WHERE userId = ? ORDER BY date ASC LIMIT 1;"
        var stmt: OpaquePointer?; var val = 0.0
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (userId as NSString).utf8String, -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW { val = sqlite3_column_double(stmt, 0) }
        }
        sqlite3_finalize(stmt); return val
    }

    private func getLatestSessionFluency(userId: String) -> Double {
        let sql = "SELECT fluencyScore FROM ReadingSessions WHERE userId = ? ORDER BY date DESC LIMIT 1;"
        var stmt: OpaquePointer?; var val = 0.0
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (userId as NSString).utf8String, -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW { val = sqlite3_column_double(stmt, 0) }
        }
        sqlite3_finalize(stmt); return val
    }

    private func getAvgBlockAndAccuracy(userId: String) -> (Double, Double) {
        let sql = "SELECT AVG(blockPercent), AVG(correctPercent) FROM ReadingSessions WHERE userId = ?;"
        var stmt: OpaquePointer?; var block = 0.0; var acc = 0.0
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (userId as NSString).utf8String, -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW {
                block = sqlite3_column_double(stmt, 0)
                acc   = sqlite3_column_double(stmt, 1)
            }
        }
        sqlite3_finalize(stmt); return (block, acc)
    }

    private func getWeekOverWeekFluency(userId: String) -> (Double, Double) {
        let now = Date().timeIntervalSince1970
        let sql = "SELECT AVG(fluencyScore) FROM ReadingSessions WHERE userId = ? AND date >= ? AND date < ?;"
        let thisWeek = doubleQuery(sql: sql, userId: userId, from: now - 7 * 86400, to: now)
        let lastWeek = doubleQuery(sql: sql, userId: userId, from: now - 14 * 86400, to: now - 7 * 86400)
        return (thisWeek, lastWeek)
    }

    // MARK: - Week Comparisons

    private func getAvgBlockThisWeek(userId: String) -> Double {
        let now = Date().timeIntervalSince1970
        let sql = "SELECT AVG(blockPercent) FROM ReadingSessions WHERE userId = ? AND date >= ? AND date < ?;"
        return doubleQuery(sql: sql, userId: userId, from: now - 7 * 86400, to: now)
    }

    private func getAvgBlockLastWeek(userId: String) -> Double {
        let now = Date().timeIntervalSince1970
        let sql = "SELECT AVG(blockPercent) FROM ReadingSessions WHERE userId = ? AND date >= ? AND date < ?;"
        return doubleQuery(sql: sql, userId: userId, from: now - 14 * 86400, to: now - 7 * 86400)
    }

    private func getAvgAccuracyThisWeek(userId: String) -> Double {
        let now = Date().timeIntervalSince1970
        let sql = "SELECT AVG(correctPercent) FROM ReadingSessions WHERE userId = ? AND date >= ? AND date < ?;"
        return doubleQuery(sql: sql, userId: userId, from: now - 7 * 86400, to: now)
    }

    private func getAvgAccuracyLastWeek(userId: String) -> Double {
        let now = Date().timeIntervalSince1970
        let sql = "SELECT AVG(correctPercent) FROM ReadingSessions WHERE userId = ? AND date >= ? AND date < ?;"
        return doubleQuery(sql: sql, userId: userId, from: now - 14 * 86400, to: now - 7 * 86400)
    }

    // MARK: - Reading Section

    private func getAvgReadingDuration(userId: String) -> TimeInterval {
        let sql = "SELECT AVG(duration) FROM ReadingSessions WHERE userId = ? AND duration > 0;"
        var stmt: OpaquePointer?; var val = 0.0
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (userId as NSString).utf8String, -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW { val = sqlite3_column_double(stmt, 0) }
        }
        sqlite3_finalize(stmt); return val
    }

    private func getLongestSmoothParagraph(userId: String) -> Int {
        let sql = "SELECT MAX(longestSmoothParagraph) FROM ReadingSessions WHERE userId = ?;"
        return singleIntQuery(sql: sql, userId: userId)
    }

    // MARK: - Conversation Section

    private func getAvgFillerWordPercent(userId: String) -> Double {
        let sql = "SELECT AVG(fillerWordPercent) FROM ConversationSessions WHERE userId = ?;"
        var stmt: OpaquePointer?; var val = 0.0
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (userId as NSString).utf8String, -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW { val = sqlite3_column_double(stmt, 0) }
        }
        sqlite3_finalize(stmt); return val
    }

    private func getAvgConversationDuration(userId: String) -> TimeInterval {
        let sql = "SELECT AVG(duration) FROM ConversationSessions WHERE userId = ? AND duration > 0;"
        var stmt: OpaquePointer?; var val = 0.0
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (userId as NSString).utf8String, -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW { val = sqlite3_column_double(stmt, 0) }
        }
        sqlite3_finalize(stmt); return val
    }

    private func getLongestSmoothTalk(userId: String) -> Int {
        let sql = "SELECT MAX(longestSmoothTalk) FROM ConversationSessions WHERE userId = ?;"
        return singleIntQuery(sql: sql, userId: userId)
    }

    private func getFillerThisWeek(userId: String) -> Double {
        let now = Date().timeIntervalSince1970
        let sql = "SELECT AVG(fillerWordPercent) FROM ConversationSessions WHERE userId = ? AND date >= ? AND date < ?;"
        return doubleQuery(sql: sql, userId: userId, from: now - 7 * 86400, to: now)
    }

    private func getFillerLastWeek(userId: String) -> Double {
        let now = Date().timeIntervalSince1970
        let sql = "SELECT AVG(fillerWordPercent) FROM ConversationSessions WHERE userId = ? AND date >= ? AND date < ?;"
        return doubleQuery(sql: sql, userId: userId, from: now - 14 * 86400, to: now - 7 * 86400)
    }

    // MARK: - Exercise Section

    private func getExerciseMinutesThisWeek() -> Int {
        let weekStart = Date().timeIntervalSince1970 - (7 * 86400)
        let sql = "SELECT SUM(exerciseDuration) FROM ExerciseLog WHERE completionDate >= ?;"
        var stmt: OpaquePointer?; var total = 0
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_double(stmt, 1, weekStart)
            if sqlite3_step(stmt) == SQLITE_ROW { total = Int(sqlite3_column_int(stmt, 0)) }
        }
        sqlite3_finalize(stmt)
        return total / 60   // seconds → minutes
    }

    private func getMostPracticedExercise() -> String {
        let sql = """
            SELECT exerciseName, COUNT(*) as c
            FROM ExerciseLog
            GROUP BY exerciseName
            ORDER BY c DESC
            LIMIT 1;
            """
        var stmt: OpaquePointer?; var name = "—"
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW,
               let cStr = sqlite3_column_text(stmt, 0) { name = String(cString: cStr) }
        }
        sqlite3_finalize(stmt); return name
    }

    private func getMostCommonStutterType(userId: String) -> String {
        let sql = """
            SELECT type, COUNT(*) as c
            FROM TroubledWords
            WHERE userId = ?
            GROUP BY type
            ORDER BY c DESC
            LIMIT 1;
            """
        var stmt: OpaquePointer?; var result = "repetition"
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (userId as NSString).utf8String, -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW,
               let cStr = sqlite3_column_text(stmt, 0) { result = String(cString: cStr) }
        }
        sqlite3_finalize(stmt); return result
    }

    // MARK: - Streak

    private func calculateStreak(userId: String) -> Int {
        let sql = """
            SELECT DISTINCT CAST(date / 86400 AS INTEGER) as day
            FROM ReadingSessions WHERE userId = ?
            ORDER BY day DESC;
            """
        var stmt: OpaquePointer?; var days: [Int] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (userId as NSString).utf8String, -1, nil)
            while sqlite3_step(stmt) == SQLITE_ROW {
                days.append(Int(sqlite3_column_int(stmt, 0)))
            }
        }
        sqlite3_finalize(stmt)

        guard !days.isEmpty else { return 0 }
        let todayDay = Int(Date().timeIntervalSince1970 / 86400)
        guard days[0] == todayDay || days[0] == todayDay - 1 else { return 0 }

        var streak = 1
        for i in 1 ..< days.count {
            if days[i - 1] - days[i] == 1 { streak += 1 } else { break }
        }
        return streak
    }

    // MARK: - Weekly Trend

    private func getWeeklyTrend(userId: String) -> [WeeklyPoint] {
        let sql = """
            SELECT CAST(date / 86400 AS INTEGER) as day, AVG(fluencyScore)
            FROM ReadingSessions
            WHERE userId = ? AND date >= ?
            GROUP BY day ORDER BY day ASC;
            """
        let sevenDaysAgo = Date().timeIntervalSince1970 - (7 * 86400)
        var stmt: OpaquePointer?; var points: [WeeklyPoint] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (userId as NSString).utf8String, -1, nil)
            sqlite3_bind_double(stmt, 2, sevenDaysAgo)
            while sqlite3_step(stmt) == SQLITE_ROW {
                let day  = sqlite3_column_int(stmt, 0)
                let avg  = sqlite3_column_double(stmt, 1)
                let date = Date(timeIntervalSince1970: Double(day) * 86400)
                points.append(WeeklyPoint(date: date, avgFluency: avg))
            }
        }
        sqlite3_finalize(stmt); return points
    }

    // MARK: - Generic Query Helpers

    private func singleIntQuery(sql: String, userId: String) -> Int {
        var stmt: OpaquePointer?; var val = 0
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (userId as NSString).utf8String, -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW { val = Int(sqlite3_column_int(stmt, 0)) }
        }
        sqlite3_finalize(stmt); return val
    }

    private func doubleQuery(sql: String, userId: String, from: Double, to: Double) -> Double {
        var stmt: OpaquePointer?; var val = 0.0
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (userId as NSString).utf8String, -1, nil)
            sqlite3_bind_double(stmt, 2, from)
            sqlite3_bind_double(stmt, 3, to)
            if sqlite3_step(stmt) == SQLITE_ROW { val = sqlite3_column_double(stmt, 0) }
        }
        sqlite3_finalize(stmt); return val
    }

    // MARK: - Trend Helpers

    /// Higher = better (fluency, accuracy, improvement).
    private func trend(current: Double, previous: Double) -> TrendDirection {
        let d = current - previous
        if d > 1 { return .up }
        if d < -1 { return .down }
        return .neutral
    }

    /// Lower = better (blocks, filler words). Down arrow in data → shown as up (improvement).
    private func trendInverse(current: Double, previous: Double) -> TrendDirection {
        let d = current - previous
        if d < -1 { return .up }
        if d > 1  { return .down }
        return .neutral
    }
}

// MARK: - Helpers

private extension Int {
    var asDouble: Double { Double(self) }
}
