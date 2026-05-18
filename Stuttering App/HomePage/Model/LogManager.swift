import Foundation
import SQLite3
import Supabase

enum TrendDirection {
    case up, down, neutral
}

struct DayReport {
    let date: Date
    let sessionCount: Int
    let avgFluencyScore: Double
    let avgBlockPercent: Double
    let avgAccuracy: Double
    let fluencyGrowth: Double
    let improvementPercent: Double
    let insight: String
}

struct UserProfile {
    let id: String
    var firstName: String?
    var lastName: String?
    var dob: String?
    var mobile: String?
    var isOnboardingCompleted: Bool
}

struct OverallProgressReport {

    let daysPracticed: Int
    let daysGoalsCompleted: Int
    let activeStreak: Int
    let totalHours: Double

    let headlineInsight: String

    let fluencyGrowthPercent: Double
    let fluencyTrend: TrendDirection
    let avgBlockPercent: Double
    let blocksTrend: TrendDirection
    let avgAccuracy: Double
    let accuracyTrend: TrendDirection
    let improvementPercent: Double
    let improvementTrend: TrendDirection

    let exercisesCompleted: Int
    let totalExercisesPracticed: Int
    let exercisesGoal: Int
    let totalExerciseMinutesThisWeek: Int
    let mostPracticedTechnique: String

    let totalReadingSessions: Int
    let avgBlocksPerReading: Double
    let readingBlockTrend: TrendDirection
    let avgReadingDuration: TimeInterval
    let longestSmoothParagraph: Int

    let totalConversationSessions: Int
    let avgFillerWordPercent: Double
    let fillerTrend: TrendDirection
    let avgConversationDuration: TimeInterval
    let longestSmoothTalk: Int

    let weeklyTrend: [WeeklyPoint]
}

struct WeeklyPoint {
    let date: Date
    let avgFluency: Double
}

struct TroubledWordSyncRecord {
    let id: String
    let sessionId: String
    let userId: String
    let word: String
    let type: String
    let firstLetter: String
}

struct SessionLetterStatSyncRecord {
    let sessionId: String
    let userId: String
    let letter: String
    let stutterCount: Int
}

struct ReadingSessionSyncRecord {
    let id: String
    let userId: String
    let date: Double
    let duration: Double
    let fluencyScore: Int
    let repetitionPercent: Double
    let prolongationPercent: Double
    let blockPercent: Double
    let correctPercent: Double
    let repetitionCount: Int
    let prolongationCount: Int
    let blockCount: Int
    let stutteredWordCount: Int
    let longestSmoothParagraph: Int
    let insight: String?
}

class LogManager {

    static let shared = LogManager()

    private(set) var db: OpaquePointer?
    private let dbName = "ExerciseDatabase.sqlite"
    private var currentUserId: String?

    /// Cached home insight — invalidated when a new session is saved
    var cachedHomeInsight: String?

    struct GoalKeys {
        static let exercise     = "Goal_Exercise"
        static let reading      = "Goal_Reading"
        static let conversation = "Goal_Conversation"
    }

    private init() {
        openDatabase()
        createTables()
        initializeDefaultGoals()
    }

    func getMostRecentReadingSessionDate() -> Date? {
        guard let userId = getCurrentUserId() else { return nil }

        let sql = """
            SELECT date FROM ReadingSessions
            WHERE userId = ?
            ORDER BY date DESC
            LIMIT 1;
            """

        var stmt: OpaquePointer?
        var result: Date?

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (userId as NSString).utf8String, -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW {
                let timestamp = sqlite3_column_double(stmt, 0)
                result = Date(timeIntervalSince1970: timestamp)
            }
        }

        sqlite3_finalize(stmt)
        return result
    }

    private func openDatabase() {
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent(dbName)
        print("ExerciseLog Database Created")
        if sqlite3_open(fileURL.path, &db) != SQLITE_OK {
            print("Error: Unable to open database.")
        }
    }

    private func createTables() {

        let createExerciseLog = "CREATE TABLE IF NOT EXISTS ExerciseLog (id TEXT PRIMARY KEY, exerciseName TEXT, completionDate REAL, source TEXT, exerciseDuration INTEGER);"
        let createGoals = "CREATE TABLE IF NOT EXISTS Goals (goalName TEXT PRIMARY KEY, goalValue INTEGER);"
        let createStutterStats = "CREATE TABLE IF NOT EXISTS StutterStats (letter TEXT PRIMARY KEY, count INTEGER);"
        let createUsers = "CREATE TABLE IF NOT EXISTS Users (id TEXT PRIMARY KEY, email TEXT UNIQUE NOT NULL, createdAt REAL);"
        let createProfiles = "CREATE TABLE IF NOT EXISTS Profiles (id TEXT PRIMARY KEY, firstName TEXT, lastName TEXT, dob TEXT, mobile TEXT, isOnboardingCompleted INTEGER DEFAULT 0, FOREIGN KEY(id) REFERENCES Users(id));"
        let createReadingSessions = "CREATE TABLE IF NOT EXISTS ReadingSessions (id TEXT PRIMARY KEY, userId TEXT, date REAL, duration REAL, fluencyScore INTEGER, repetitionPercent REAL, prolongationPercent REAL, blockPercent REAL, correctPercent REAL, repetitionCount INTEGER DEFAULT 0, prolongationCount INTEGER DEFAULT 0, blockCount INTEGER DEFAULT 0, stutteredWordCount INTEGER DEFAULT 0, longestSmoothParagraph INTEGER DEFAULT 0, insight TEXT, FOREIGN KEY(userId) REFERENCES Users(id));"
        let createTroubledWords = "CREATE TABLE IF NOT EXISTS TroubledWords (id TEXT PRIMARY KEY, sessionId TEXT, userId TEXT, word TEXT, type TEXT, firstLetter TEXT, FOREIGN KEY(sessionId) REFERENCES ReadingSessions(id), FOREIGN KEY(userId) REFERENCES Users(id));"
        let createLetterStats = "CREATE TABLE IF NOT EXISTS LetterStats (userId TEXT, letter TEXT, count INTEGER, PRIMARY KEY(userId, letter), FOREIGN KEY(userId) REFERENCES Users(id));"
        let createSessionLetterStats = "CREATE TABLE IF NOT EXISTS SessionLetterStats (sessionId TEXT, userId TEXT, letter TEXT, stutterCount INTEGER, PRIMARY KEY(sessionId, letter), FOREIGN KEY(sessionId) REFERENCES ReadingSessions(id), FOREIGN KEY(userId) REFERENCES Users(id));"
        let createConversationSessions = "CREATE TABLE IF NOT EXISTS ConversationSessions (id TEXT PRIMARY KEY, userId TEXT, date REAL, duration REAL, fillerWordPercent REAL, longestSmoothTalk INTEGER DEFAULT 0, FOREIGN KEY(userId) REFERENCES Users(id));"

        sqlite3_exec(db, createExerciseLog, nil, nil, nil)
        sqlite3_exec(db, createGoals, nil, nil, nil)
        sqlite3_exec(db, createStutterStats, nil, nil, nil)
        sqlite3_exec(db, createUsers, nil, nil, nil)
        sqlite3_exec(db, createProfiles, nil, nil, nil)
        sqlite3_exec(db, createReadingSessions, nil, nil, nil)
        sqlite3_exec(db, createTroubledWords, nil, nil, nil)
        sqlite3_exec(db, createLetterStats, nil, nil, nil)
        sqlite3_exec(db, createSessionLetterStats, nil, nil, nil)
        sqlite3_exec(db, createConversationSessions, nil, nil, nil)

        print("10 Tables created in ExerciseLogs\n")

        let readingSessionMigrations: [(String, String)] = [
            ("repetitionCount", "ALTER TABLE ReadingSessions ADD COLUMN repetitionCount INTEGER DEFAULT 0;"),
            ("prolongationCount", "ALTER TABLE ReadingSessions ADD COLUMN prolongationCount INTEGER DEFAULT 0;"),
            ("blockCount", "ALTER TABLE ReadingSessions ADD COLUMN blockCount INTEGER DEFAULT 0;"),
            ("stutteredWordCount", "ALTER TABLE ReadingSessions ADD COLUMN stutteredWordCount INTEGER DEFAULT 0;"),
            ("insight", "ALTER TABLE ReadingSessions ADD COLUMN insight TEXT;")
        ]

        for (columnName, sql) in readingSessionMigrations where !columnExists(tableName: "ReadingSessions", columnName: columnName) {
            sqlite3_exec(db, sql, nil, nil, nil)
            print("Migration: Added '\(columnName)' column to ReadingSessions.")
        }
    }

    // 2. Helper function to inspect the SQLite table schema
    private func columnExists(tableName: String, columnName: String) -> Bool {
        let sql = "PRAGMA table_info(\(tableName));"
        var stmt: OpaquePointer?
        var exists = false

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            // Step through every column in the table
            while sqlite3_step(stmt) == SQLITE_ROW {
                // Index 1 in PRAGMA table_info is the column name
                if let nameCStr = sqlite3_column_text(stmt, 1) {
                    let name = String(cString: nameCStr)
                    if name == columnName {
                        exists = true
                        break
                    }
                }
            }
        }
        sqlite3_finalize(stmt)
        return exists
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

    func getCurrentUserId() -> String? {
        if currentUserId == nil {
            if SessionManager.shared.isGuestMode {
                initializeGuestUser()
            } else {
                initializeUserIfNeeded()
            }
        }
        return currentUserId ?? SessionManager.shared.deviceId
    }

    /// Initialize a guest user using the device ID — NO Supabase calls
    func initializeGuestUser() {
        let guestId = SessionManager.shared.deviceId
        print("📋 [GUEST] Initializing guest user with deviceId: \(guestId)")
        currentUserId = createOrGetUser(email: "guest@local", userId: guestId)

        // Ensure a profile exists for the guest
        let profileSQL = "INSERT OR IGNORE INTO Profiles (id, isOnboardingCompleted) VALUES (?, 0);"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, profileSQL, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (guestId as NSString).utf8String, -1, nil)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
        print("📋 [GUEST] Guest user initialized")
    }

    func migrateGuestData(to newUserId: String) {
        let guestId = SessionManager.shared.deviceId
        var stmt: OpaquePointer?

        print("🔄 [MIGRATE] Starting migration from guest (\(guestId)) to account (\(newUserId))")

        let checkSQL = "SELECT isOnboardingCompleted FROM Profiles WHERE id = ?;"
        var hasGuest = false
        if sqlite3_prepare_v2(db, checkSQL, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (guestId as NSString).utf8String, -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW {
                hasGuest = true
            }
        }
        sqlite3_finalize(stmt)

        if hasGuest {
            // Delete placeholder profile to avoid Primary Key collision
            let deleteSQL = "DELETE FROM Profiles WHERE id = ?;"
            if sqlite3_prepare_v2(db, deleteSQL, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (newUserId as NSString).utf8String, -1, nil)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)

            // Migrate Profiles (use 'id' column)
            let updateProfile = "UPDATE Profiles SET id = ? WHERE id = ?;"
            if sqlite3_prepare_v2(db, updateProfile, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (newUserId as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (guestId as NSString).utf8String, -1, nil)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)

            // Migrate tables using 'userId' column
            let tables = ["ReadingSessions", "TroubledWords", "LetterStats", "SessionLetterStats", "ConversationSessions"]
            for table in tables {
                let updateSQL = "UPDATE \(table) SET userId = ? WHERE userId = ?;"
                if sqlite3_prepare_v2(db, updateSQL, -1, &stmt, nil) == SQLITE_OK {
                    sqlite3_bind_text(stmt, 1, (newUserId as NSString).utf8String, -1, nil)
                    sqlite3_bind_text(stmt, 2, (guestId as NSString).utf8String, -1, nil)
                    sqlite3_step(stmt)
                }
                sqlite3_finalize(stmt)
            }
            print("🔄 [MIGRATE] All guest data tables migrated to userId: \(newUserId)")
            
            let deleteOldLogs = "DELETE FROM ExerciseLog;"
            sqlite3_exec(db, deleteOldLogs, nil, nil, nil)
            
            let deleteGuestUser = "DELETE FROM Users WHERE id = ?;"
            if sqlite3_prepare_v2(db, deleteGuestUser, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (guestId as NSString).utf8String, -1, nil)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        } else {
            print("🔄 [MIGRATE] No guest data found to migrate")
        }

        // Update currentUserId
        currentUserId = newUserId

        // Clear any cached insight that was generated under the guest identity
        cachedHomeInsight = nil
    }

    func initializeUserIfNeeded() {
        // For guest mode, use the guest initializer
        if SessionManager.shared.isGuestMode {
            initializeGuestUser()
            return
        }

        guard let user = SupabaseManager.shared.client.auth.currentUser,
              let email = user.email else {
            print("No logged in user found in Supabase.")
            return
        }
        currentUserId = createOrGetUser(email: email, userId: user.id.uuidString)
    }

    func createOrGetUser(email: String, userId: String) -> String {
        let checkSQL = "SELECT id FROM Users WHERE id = ?;"
        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, checkSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (userId as NSString).utf8String, -1, nil)
            if sqlite3_step(statement) == SQLITE_ROW,
               let idCStr = sqlite3_column_text(statement, 0) {
                let existingUserId = String(cString: idCStr)
                sqlite3_finalize(statement)
                return existingUserId
            }
        }
        sqlite3_finalize(statement)

        let insertSQL = "INSERT INTO Users (id, email, createdAt) VALUES (?, ?, ?);"
        let now   = Date().timeIntervalSince1970

        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (userId as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (email as NSString).utf8String, -1, nil)
            sqlite3_bind_double(statement, 3, now)
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)

        // Initialize an empty profile for the new user
        let profileSQL = "INSERT OR IGNORE INTO Profiles (id, isOnboardingCompleted) VALUES (?, 0);"
        if sqlite3_prepare_v2(db, profileSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (userId as NSString).utf8String, -1, nil)
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)

        return userId
    }

    func saveProfile(_ profile: UserProfile, fromSync: Bool = false) {
        let sql = """
            INSERT OR REPLACE INTO Profiles (id, firstName, lastName, dob, mobile, isOnboardingCompleted)
            VALUES (?, ?, ?, ?, ?, ?);
            """
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (profile.id as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, ((profile.firstName ?? "") as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 3, ((profile.lastName ?? "") as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 4, ((profile.dob ?? "") as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 5, ((profile.mobile ?? "") as NSString).utf8String, -1, nil)
            sqlite3_bind_int(statement, 6, profile.isOnboardingCompleted ? 1 : 0)

            if sqlite3_step(statement) == SQLITE_DONE {
                print("Local Profile saved for \(profile.id)")
            }
        }
        sqlite3_finalize(statement)

        if !fromSync && SessionManager.shared.isAccountMode {
            SupabaseSyncManager.shared.pushProfile(profile)
        } else if !fromSync && SessionManager.shared.isGuestMode {
            print("📋 [GUEST] Profile saved locally only (guest mode)")
        }
    }

    func getProfile(userId: String) -> UserProfile? {
        let sql = "SELECT firstName, lastName, dob, mobile, isOnboardingCompleted FROM Profiles WHERE id = ?;"
        var statement: OpaquePointer?
        var profile: UserProfile?

        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (userId as NSString).utf8String, -1, nil)
            if sqlite3_step(statement) == SQLITE_ROW {
                let first = sqlite3_column_text(statement, 0).map { String(cString: $0) }
                let last = sqlite3_column_text(statement, 1).map { String(cString: $0) }
                let dob = sqlite3_column_text(statement, 2).map { String(cString: $0) }
                let mob = sqlite3_column_text(statement, 3).map { String(cString: $0) }
                let isComplete = sqlite3_column_int(statement, 4) == 1

                profile = UserProfile(id: userId, firstName: first?.isEmpty == false ? first : nil,
                                      lastName: last?.isEmpty == false ? last : nil,
                                      dob: dob?.isEmpty == false ? dob : nil,
                                      mobile: mob?.isEmpty == false ? mob : nil,
                                      isOnboardingCompleted: isComplete)
            }
        }
        sqlite3_finalize(statement)
        return profile
    }

    private func initializeDefaultGoals() {
        let defaults: [(String, Int)] = [
            (GoalKeys.exercise, 10),
            (GoalKeys.reading, 20),
            (GoalKeys.conversation, 20)
        ]
        let insertSQL = "INSERT OR IGNORE INTO Goals (goalName, goalValue) VALUES (?, ?);"
        for (name, value) in defaults {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (name as NSString).utf8String, -1, nil)
                sqlite3_bind_int(statement, 2, Int32(value))
                if sqlite3_step(statement) == SQLITE_DONE {}
            }
            sqlite3_finalize(statement)
        }

        print("Initialized default goals.")
    }

    func updateGoal(name: String, value: Int, fromSync: Bool = false) {
        let sql = "INSERT OR REPLACE INTO Goals (goalName, goalValue) VALUES (?, ?);"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (name as NSString).utf8String, -1, nil)
            sqlite3_bind_int(statement, 2, Int32(value))
            if sqlite3_step(statement) == SQLITE_DONE { print("Updated \(name) to \(value)") } else { print("Failed to update goal.") }
        }
        sqlite3_finalize(statement)

        if !fromSync && SessionManager.shared.isAccountMode {
            SupabaseSyncManager.shared.pushUserGoal(goalName: name, goalValue: value)
        } else if !fromSync && SessionManager.shared.isGuestMode {
            print("📋 [GUEST] Goal updated locally only (guest mode)")
        }
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

    func addLog(exerciseName: String, source: ExerciseSource, exerciseDuration: Int) {
        // 1. Generate a single, unified ID for this specific log
        let logId = UUID().uuidString

        let sql = "INSERT INTO ExerciseLog (id, exerciseName, completionDate, source, exerciseDuration) VALUES (?, ?, ?, ?, ?);"
        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            // 2. Use the unified ID for local storage
            sqlite3_bind_text(statement, 1, (logId as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (exerciseName as NSString).utf8String, -1, nil)
            sqlite3_bind_double(statement, 3, Date().timeIntervalSince1970)
            sqlite3_bind_text(statement, 4, (source.rawValue as NSString).utf8String, -1, nil)
            sqlite3_bind_int(statement, 5, Int32(exerciseDuration))

            if sqlite3_step(statement) == SQLITE_DONE {
                print("✅ Log inserted locally with ID: \(logId)")
            } else {
                print("❌ Could not insert row locally.")
            }
        }
        sqlite3_finalize(statement)

        // 3. Push the EXACT SAME ID to Supabase (account mode only)
        if SessionManager.shared.isAccountMode {
            SupabaseSyncManager.shared.pushExerciseLog(
                id: logId,
                name: exerciseName,
                source: source.rawValue,
                duration: exerciseDuration
            )
        } else {
            print("📋 [GUEST] Exercise log saved locally only (guest mode)")
        }
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

    /// Saves a reading session with an optional pre-generated insight.
    /// Returns the sessionId so callers can update the insight later.
    @discardableResult
    func saveReadingSession(report: StutterJSONReport,
                            duration: TimeInterval = 0,
                            longestSmoothParagraph: Int = 0,
                            insight: String? = nil) -> String? {
        guard let userId = getCurrentUserId() else {
            print("User not initialized.")
            return nil
        }

        let sessionId = UUID().uuidString
        let now = Date().timeIntervalSince1970
        let resolvedDuration = duration > 0 ? duration : Self.parseDurationString(report.duration)
        let repetitionCount = report.breakdown.repetition.count
        let prolongationCount = report.breakdown.prolongation.count
        let blockCount = report.breakdown.blocks
        let stutteredWordCount = report.stutteredWords.count

        let sql = """
            INSERT INTO ReadingSessions
            (id, userId, date, duration, fluencyScore,
             repetitionPercent, prolongationPercent,
             blockPercent, correctPercent, repetitionCount,
             prolongationCount, blockCount, stutteredWordCount,
             longestSmoothParagraph, insight)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (sessionId as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (userId as NSString).utf8String, -1, nil)
            sqlite3_bind_double(statement, 3, now)
            sqlite3_bind_double(statement, 4, resolvedDuration)
            sqlite3_bind_int(statement, 5, Int32(report.fluencyScore))
            sqlite3_bind_double(statement, 6, report.percentages.repetition)
            sqlite3_bind_double(statement, 7, report.percentages.prolongation)
            sqlite3_bind_double(statement, 8, report.percentages.blocks)
            sqlite3_bind_double(statement, 9, report.percentages.correct)
            sqlite3_bind_int(statement, 10, Int32(repetitionCount))
            sqlite3_bind_int(statement, 11, Int32(prolongationCount))
            sqlite3_bind_int(statement, 12, Int32(blockCount))
            sqlite3_bind_int(statement, 13, Int32(stutteredWordCount))
            sqlite3_bind_int(statement, 14, Int32(longestSmoothParagraph))
            if let insight = insight {
                sqlite3_bind_text(statement, 15, (insight as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(statement, 15)
            }

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

        if SessionManager.shared.isAccountMode {
            SupabaseSyncManager.shared.pushReadingSession(
                report,
                sessionId: sessionId,
                date: now,
                duration: resolvedDuration,
                longestSmoothParagraph: longestSmoothParagraph,
                insight: insight
            )
            SupabaseSyncManager.shared.pushLetterStats(userId: userId)
        } else {
            print("📋 [GUEST] Reading session saved locally only (guest mode)")
        }

        // Invalidate cached home insight so it regenerates with new data
        cachedHomeInsight = nil

        return sessionId
    }

    /// Updates the insight for an existing session (used when insight is generated async after save).
    func updateSessionInsight(sessionId: String, insight: String) {
        let sql = "UPDATE ReadingSessions SET insight = ? WHERE id = ?;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (insight as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (sessionId as NSString).utf8String, -1, nil)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)

        if SessionManager.shared.isAccountMode {
            SupabaseSyncManager.shared.pushReadingSessionInsight(sessionId: sessionId, insight: insight)
        }
    }

    /// Retrieves the stored insight for a specific session.
    func getSessionInsight(sessionId: String) -> String? {
        let sql = "SELECT insight FROM ReadingSessions WHERE id = ?;"
        var stmt: OpaquePointer?
        var result: String?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (sessionId as NSString).utf8String, -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW,
               let cStr = sqlite3_column_text(stmt, 0) {
                result = String(cString: cStr)
            }
        }
        sqlite3_finalize(stmt)
        return result
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

                if report.breakdown.repetition.contains(word) { type = "repetition" } else if report.breakdown.prolongation.contains(word) { type = "prolongation" } else { type = "block" }

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

    func getAllLetterStats(for userId: String) -> [String: Int] {
        let sql = "SELECT letter, count FROM LetterStats WHERE userId = ?;"
        var statement: OpaquePointer?
        var stats: [String: Int] = [:]
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (userId as NSString).utf8String, -1, nil)
            while sqlite3_step(statement) == SQLITE_ROW {
                if let letterCStr = sqlite3_column_text(statement, 0) {
                    let letter = String(cString: letterCStr)
                    let count = Int(sqlite3_column_int(statement, 1))
                    stats[letter] = count
                }
            }
        }
        sqlite3_finalize(statement)
        return stats
    }

    func getAllReadingSessionSyncRecords(for userId: String) -> [ReadingSessionSyncRecord] {
        let sql = """
            SELECT id, userId, date, duration, fluencyScore,
                   repetitionPercent, prolongationPercent, blockPercent, correctPercent,
                   repetitionCount, prolongationCount, blockCount, stutteredWordCount,
                   longestSmoothParagraph, insight
            FROM ReadingSessions
            WHERE userId = ?
            ORDER BY date ASC;
            """
        var statement: OpaquePointer?
        var sessions: [ReadingSessionSyncRecord] = []

        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (userId as NSString).utf8String, -1, nil)
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let idCStr = sqlite3_column_text(statement, 0),
                      let userIdCStr = sqlite3_column_text(statement, 1) else { continue }

                sessions.append(
                    ReadingSessionSyncRecord(
                        id: String(cString: idCStr),
                        userId: String(cString: userIdCStr),
                        date: sqlite3_column_double(statement, 2),
                        duration: sqlite3_column_double(statement, 3),
                        fluencyScore: Int(sqlite3_column_int(statement, 4)),
                        repetitionPercent: sqlite3_column_double(statement, 5),
                        prolongationPercent: sqlite3_column_double(statement, 6),
                        blockPercent: sqlite3_column_double(statement, 7),
                        correctPercent: sqlite3_column_double(statement, 8),
                        repetitionCount: Int(sqlite3_column_int(statement, 9)),
                        prolongationCount: Int(sqlite3_column_int(statement, 10)),
                        blockCount: Int(sqlite3_column_int(statement, 11)),
                        stutteredWordCount: Int(sqlite3_column_int(statement, 12)),
                        longestSmoothParagraph: Int(sqlite3_column_int(statement, 13)),
                        insight: sqlite3_column_text(statement, 14).map { String(cString: $0) }
                    )
                )
            }
        }
        sqlite3_finalize(statement)
        return sessions
    }

    func getTroubledWordSyncRecords(sessionId: String) -> [TroubledWordSyncRecord] {
        let sql = """
            SELECT id, sessionId, userId, word, type, firstLetter
            FROM TroubledWords
            WHERE sessionId = ?;
            """
        var statement: OpaquePointer?
        var words: [TroubledWordSyncRecord] = []

        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (sessionId as NSString).utf8String, -1, nil)
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let idCStr = sqlite3_column_text(statement, 0),
                      let sessionIdCStr = sqlite3_column_text(statement, 1),
                      let userIdCStr = sqlite3_column_text(statement, 2),
                      let wordCStr = sqlite3_column_text(statement, 3),
                      let typeCStr = sqlite3_column_text(statement, 4),
                      let firstLetterCStr = sqlite3_column_text(statement, 5) else { continue }

                words.append(
                    TroubledWordSyncRecord(
                        id: String(cString: idCStr),
                        sessionId: String(cString: sessionIdCStr),
                        userId: String(cString: userIdCStr),
                        word: String(cString: wordCStr),
                        type: String(cString: typeCStr),
                        firstLetter: String(cString: firstLetterCStr)
                    )
                )
            }
        }
        sqlite3_finalize(statement)
        return words
    }

    func getSessionLetterStatSyncRecords(sessionId: String) -> [SessionLetterStatSyncRecord] {
        let sql = """
            SELECT sessionId, userId, letter, stutterCount
            FROM SessionLetterStats
            WHERE sessionId = ?;
            """
        var statement: OpaquePointer?
        var stats: [SessionLetterStatSyncRecord] = []

        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (sessionId as NSString).utf8String, -1, nil)
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let sessionIdCStr = sqlite3_column_text(statement, 0),
                      let userIdCStr = sqlite3_column_text(statement, 1),
                      let letterCStr = sqlite3_column_text(statement, 2) else { continue }

                stats.append(
                    SessionLetterStatSyncRecord(
                        sessionId: String(cString: sessionIdCStr),
                        userId: String(cString: userIdCStr),
                        letter: String(cString: letterCStr),
                        stutterCount: Int(sqlite3_column_int(statement, 3))
                    )
                )
            }
        }
        sqlite3_finalize(statement)
        return stats
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
            let sessionId = UUID().uuidString
            sqlite3_bind_text(statement, 1, (sessionId as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (userId as NSString).utf8String, -1, nil)
            sqlite3_bind_double(statement, 3, Date().timeIntervalSince1970)
            sqlite3_bind_double(statement, 4, duration)
            sqlite3_bind_double(statement, 5, fillerWordPercent)
            sqlite3_bind_int(statement, 6, Int32(longestSmoothTalk))
            if sqlite3_step(statement) == SQLITE_DONE { print("ConversationSession inserted.") }

            if SessionManager.shared.isAccountMode {
                SupabaseSyncManager.shared.pushConversationSession(
                    sessionId: sessionId,
                    duration: duration,
                    fillerWordPercent: fillerWordPercent,
                    longestSmoothTalk: longestSmoothTalk
                )
            } else {
                print("📋 [GUEST] Conversation session saved locally only (guest mode)")
            }
        }
        sqlite3_finalize(statement)
    }

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

    func getAverageFluency(userId: String) -> Double {
        let sql = "SELECT AVG(fluencyScore) FROM ReadingSessions WHERE userId = ?;"
        var stmt: OpaquePointer?
        var val = 0.0
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (userId as NSString).utf8String, -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW {
                val = sqlite3_column_double(stmt, 0)
            }
        }
        sqlite3_finalize(stmt)
        return val
    }

    func getBestFluency(userId: String) -> Double {
        let sql = "SELECT MAX(fluencyScore) FROM ReadingSessions WHERE userId = ?;"
        var stmt: OpaquePointer?
        var val = 0.0
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (userId as NSString).utf8String, -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW {
                val = sqlite3_column_double(stmt, 0)
            }
        }
        sqlite3_finalize(stmt)
        return val
    }

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

extension LogManager {

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
                    "fluencyScore": Int(sqlite3_column_int(statement, 0)),
                    "repetitionPercent": sqlite3_column_double(statement, 1),
                    "prolongationPercent": sqlite3_column_double(statement, 2),
                    "blockPercent": sqlite3_column_double(statement, 3),
                    "correctPercent": sqlite3_column_double(statement, 4),
                    "date": sqlite3_column_double(statement, 5),
                    "duration": sqlite3_column_double(statement, 6),
                    "longestSmoothParagraph": Int(sqlite3_column_int(statement, 7))
                ])
            }
        }
        sqlite3_finalize(statement)
        return rows
    }

    func getDayReport(for date: Date) async -> DayReport? {
        let sessions = getSessionsForDay(date)
        guard !sessions.isEmpty else { return nil }

        let count       = Double(sessions.count)
        let avgFluency  = sessions.map { $0["fluencyScore"] as! Int }.reduce(0, +).asDouble / count
        let avgBlock    = sessions.map { $0["blockPercent"] as! Double }.reduce(0, +) / count
        let avgAccuracy = sessions.map { $0["correctPercent"] as! Double }.reduce(0, +) / count

        let yesterday    = Calendar.current.date(byAdding: .day, value: -1, to: date)!
        let prevSessions = getSessionsForDay(yesterday)
        let hasPreviousDay = !prevSessions.isEmpty

        var fluencyGrowth      = 0.0
        var improvementPercent = 0.0

        if hasPreviousDay {
            let prevAvg        = prevSessions.map { $0["fluencyScore"] as! Int }.reduce(0, +).asDouble / Double(prevSessions.count)
            fluencyGrowth      = avgFluency - prevAvg
            improvementPercent = prevAvg > 0 ? (fluencyGrowth / prevAvg) * 100 : 0
        }

        // Detect first-ever session: total all-time sessions == today's sessions
        let totalSessions = getTotalReadingSessions(userId: getCurrentUserId() ?? "")
        let isFirstEverSession = totalSessions == sessions.count

        let context = DayInsightContext(
            avgFluency: avgFluency,
            avgBlock: avgBlock,
            avgAccuracy: avgAccuracy,
            fluencyGrowth: fluencyGrowth,
            improvementPercent: improvementPercent,
            sessionCount: sessions.count,
            topImprovedLetters: buildTopImprovedLetters(for: date),
            isFirstEverSession: isFirstEverSession,
            hasPreviousDay: hasPreviousDay
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

        let fluencyTrend      = trend(current: thisWeekFluency, previous: lastWeekFluency)
        let blocksTrend       = trendInverse(current: blockThisWeek, previous: blockLastWeek)
        let accuracyTrend     = trend(current: accThisWeek, previous: accLastWeek)
        let improvementTrend  = trend(current: improvementPct, previous: 0)
        let fillerTrend       = trendInverse(current: fillerThis, previous: fillerLast)
        let readingBlockTrend = trendInverse(current: blockThisWeek, previous: blockLastWeek)

        // ── Goals Completed ──────────────────────────────────────────────────
        let daysGoalsCompleted = getDaysGoalsCompleted()

        // ── Exercise ─────────────────────────────────────────────────────────
        let allExerciseLogs             = getLogs(for: .exercises)
        let exercisesCompleted          = allExerciseLogs.count
        let totalExercisesPracticed     = getLogs(for: .dailyTasks).count + allExerciseLogs.count
        let exercisesGoal               = getGoal(name: GoalKeys.exercise)
        let totalExerciseMinutesThisWeek = getExerciseMinutesThisWeek()
        let mostPracticedTechnique      = getMostPracticedExercise()

        // ── Reading ──────────────────────────────────────────────────────────
        let totalReadingSessions   = getTotalReadingSessions(userId: userId)
        let avgReadingDuration     = getAvgReadingDuration(userId: userId)
        let longestSmoothParagraph = getLongestSmoothParagraph(userId: userId)

        // ── Conversation ─────────────────────────────────────────────────────
        let totalConversationSessions = getTotalConversationSessions(userId: userId)
        let avgFillerWordPercent      = getAvgFillerWordPercent(userId: userId)
        let avgConversationDuration   = getAvgConversationDuration(userId: userId)
        let longestSmoothTalk         = getLongestSmoothTalk(userId: userId)

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
            daysGoalsCompleted: daysGoalsCompleted,
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
            totalExercisesPracticed: totalExercisesPracticed,
            exercisesGoal: exercisesGoal,
            totalExerciseMinutesThisWeek: totalExerciseMinutesThisWeek,
            mostPracticedTechnique: mostPracticedTechnique,
            totalReadingSessions: totalReadingSessions,
            avgBlocksPerReading: avgBlock,
            readingBlockTrend: readingBlockTrend,
            avgReadingDuration: avgReadingDuration,
            longestSmoothParagraph: longestSmoothParagraph,
            totalConversationSessions: totalConversationSessions,
            avgFillerWordPercent: avgFillerWordPercent,
            fillerTrend: fillerTrend,
            avgConversationDuration: avgConversationDuration,
            longestSmoothTalk: longestSmoothTalk,
            weeklyTrend: getWeeklyTrend(userId: userId)
        )
    }

    private func getDaysPracticed(userId: String) -> Int {
        let sql = """
            SELECT COUNT(DISTINCT CAST(date / 86400 AS INTEGER))
            FROM ReadingSessions WHERE userId = ?;
            """
        return singleIntQuery(sql: sql, userId: userId)
    }

    private func getDaysGoalsCompleted() -> Int {
        let sql = """
            SELECT COUNT(DISTINCT CAST(completionDate / 86400 AS INTEGER))
            FROM ExerciseLog WHERE source = 'dailyTasks';
            """
        var stmt: OpaquePointer?
        var count = 0
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                count = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        return count
    }

    private func getTotalReadingSessions(userId: String) -> Int {
        let sql = "SELECT COUNT(*) FROM ReadingSessions WHERE userId = ?;"
        return singleIntQuery(sql: sql, userId: userId)
    }

    private static func parseDurationString(_ duration: String) -> TimeInterval {
        let minuteMatch = duration.range(of: #"(\d+)\s*min"#, options: .regularExpression)
        let secondMatch = duration.range(of: #"(\d+)\s*sec"#, options: .regularExpression)

        let minutes = minuteMatch
            .flatMap { Int(duration[$0].components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) } ?? 0
        let seconds = secondMatch
            .flatMap { Int(duration[$0].components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) } ?? 0

        return TimeInterval((minutes * 60) + seconds)
    }

    private func getTotalConversationSessions(userId: String) -> Int {
        let sql = "SELECT COUNT(*) FROM ConversationSessions WHERE userId = ?;"
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
        return total / 60
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

//        guard !days.isEmpty else { return 0 }
//        let todayDay = Int(Date().timeIntervalSince1970 / 86400)
//        guard days[0] == todayDay || days[0] == todayDay - 1 else { return 0 }
//
//        var streak = 1
//        for i in 1 ..< days.count {
//            if days[i - 1] - days[i] == 1 { streak += 1 } else { break }
//        }
//        return streak

        guard !days.isEmpty else { return 0 }

        let todayDay = Int(Date().timeIntervalSince1970 / 86400)

        guard days[0] == todayDay || days[0] == todayDay - 1 else { return 0 }

        var streak = 1

        if days.count > 1 {
            for i in 1..<days.count {
                if days[i - 1] - days[i] == 1 {
                    streak += 1
                } else {
                    break
                }
            }
        }

        return streak
    }

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

    private func trend(current: Double, previous: Double) -> TrendDirection {
        let d = current - previous
        if d > 1 { return .up }
        if d < -1 { return .down }
        return .neutral
    }

    private func trendInverse(current: Double, previous: Double) -> TrendDirection {
        let d = current - previous
        if d < -1 { return .up }
        if d > 1 { return .down }
        return .neutral
    }

    func resetDatabaseForNewUser() {
        // 1. Safely close the existing SQLite connection in memory
        if db != nil {
            if sqlite3_close(db) != SQLITE_OK {
                print("Warning: Could not close database perfectly.")
            }
            db = nil
        }

        currentUserId = nil

        do {
            let fileURL = try FileManager.default
                .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
                .appendingPathComponent(dbName)

            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
                print("Old database file permanently deleted.")
            }
        } catch {
            print("Error deleting database file: \(error)")
        }

        // 4. Re-initialize for the next user/guest session
        openDatabase()
        createTables()
        initializeDefaultGoals()
        print("Database engine rebooted and ready for Guest.")
    }
}

private extension Int {
    var asDouble: Double { Double(self) }
}
