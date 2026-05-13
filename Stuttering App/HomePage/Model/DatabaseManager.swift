//
//  DatabaseManager.swift
//  Spasht
//
//  Created by Prathamesh Patil on 14/11/25.
//

import Foundation
import SQLite3

class DatabaseManager {
    static let shared = DatabaseManager()
    private(set) var isDailyGoalCompleted: Bool = false
    var db: OpaquePointer?
    
    // 🔥 Ensures Swift doesn't destroy strings from memory before SQLite saves them
    internal let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private init() {
        openDatabase()
        createTables()
        populateInitialJourney()
        initializeStreakIfNeeded()
        
        // This forces the DB to check your Journey table and update "Go-To" on startup
        syncLegacyJourneyCompletions()
    }

    func openDatabase() {
        let fileUrl = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent("Spasht.sqlite")
        print("Spasht Database Created")
        if sqlite3_open(fileUrl.path, &db) != SQLITE_OK {
            print("Error opening database")
        }
    }

    func createTables() {
        let createJourney = "CREATE TABLE IF NOT EXISTS Journey (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, isCompleted INTEGER DEFAULT 0)"
        let createDaily = "CREATE TABLE IF NOT EXISTS DailyTasks (id INTEGER PRIMARY KEY, name TEXT, description TEXT, duration INTEGER, isCompleted INTEGER DEFAULT 0)"
        let createStreak = "CREATE TABLE IF NOT EXISTS Streak (id INTEGER PRIMARY KEY CHECK (id = 1), currentStreak INTEGER,lastCompletedDate TEXT)"
        
        // --- NEW TABLES FOR LIBRARY ---
        let createExercises = """
        CREATE TABLE IF NOT EXISTS Exercises (
            id INTEGER PRIMARY KEY AUTOINCREMENT, 
            name TEXT, 
            targetPhoneme TEXT, 
            completionCount INTEGER DEFAULT 0,
            lastCompleted DATETIME
        )
        """
        let createUserPhonemes = "CREATE TABLE IF NOT EXISTS UserPhonemes (id INTEGER PRIMARY KEY AUTOINCREMENT, phoneme TEXT)"
        
        sqlite3_exec(db, createStreak, nil, nil, nil)
        sqlite3_exec(db, createJourney, nil, nil, nil)
        sqlite3_exec(db, createDaily, nil, nil, nil)
        
        // Execute new tables
        sqlite3_exec(db, createExercises, nil, nil, nil)
        sqlite3_exec(db, createUserPhonemes, nil, nil, nil)
    }

    private func populateInitialJourney() {
        var count: Int32 = 0
        let countQuery = "SELECT COUNT(*) FROM Journey"
        var countStmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, countQuery, -1, &countStmt, nil) == SQLITE_OK {
            if sqlite3_step(countStmt) == SQLITE_ROW {
                count = sqlite3_column_int(countStmt, 0)
            }
        }
        sqlite3_finalize(countStmt)
        
        if count == 0 {
            print("Journey table empty. Populating initial sequence...")
            let exercises = [
                "Airflow Practice", "Gentle Onset", "Flexible Pacing", "Light Contacts", "Prolongation", "Preparatory Set", "Block Correction", "Prolongation", "Flexible Pacing", "Light Contacts", "Preparatory Set", "Pull-Out", "Block Correction", "Airflow Practice", "Gentle Onset", "Flexible Pacing", "Light Contacts", "Prolongation", "Preparatory Set", "Block Correction", "Prolongation", "Flexible Pacing", "Light Contacts", "Preparatory Set", "Pull-Out", "Block Correction"
            ]
            
            let insertQuery = "INSERT INTO Journey (name, isCompleted) VALUES (?, 0)"
            var insertStmt: OpaquePointer?
            
            if sqlite3_prepare_v2(db, insertQuery, -1, &insertStmt, nil) == SQLITE_OK {
                for name in exercises {
                    sqlite3_bind_text(insertStmt, 1, (name as NSString).utf8String, -1, SQLITE_TRANSIENT)
                    if sqlite3_step(insertStmt) != SQLITE_DONE {
                        print("Error inserting \(name)")
                    }
                    sqlite3_reset(insertStmt)
                }
            }
            sqlite3_finalize(insertStmt)
            
            print("Journey table Initialized\n")
        }
    }
    
    func fetchNextFiveFromJourney() -> [String] {
        let query = "SELECT name FROM Journey WHERE isCompleted = 0 ORDER BY id ASC LIMIT 5"
        var statement: OpaquePointer?
        var names: [String] = []

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                if let cString = sqlite3_column_text(statement, 0) {
                    names.append(String(cString: cString))
                }
            }
        }
        sqlite3_finalize(statement)
        return names
    }

    func clearDailyTasks() {
        let delete = "DELETE FROM DailyTasks"
        sqlite3_exec(db, delete, nil, nil, nil)
    }

    func insertDailyTask(id: Int, name: String, desc: String, duration: Int) {
        let insert = "INSERT INTO DailyTasks (id, name, description, duration, isCompleted) VALUES (?, ?, ?, ?, 0)"
        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, insert, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(id))
            sqlite3_bind_text(statement, 2, (name as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 3, (desc as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(statement, 4, Int32(duration))
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
    }
    
    func fetchDailyTasks() -> [DailyTask] {
        let query = "SELECT id, name, description, duration, isCompleted FROM DailyTasks ORDER BY id ASC"
        var statement: OpaquePointer?
        var tasks: [DailyTask] = []

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))
                let name = String(cString: sqlite3_column_text(statement, 1))
                let desc = String(cString: sqlite3_column_text(statement, 2))
                let dur = Int(sqlite3_column_int(statement, 3))
                let isComp = sqlite3_column_int(statement, 4) == 1
                
                tasks.append(DailyTask(id: id, name: name, description: desc, duration: dur, isCompleted: isComp))
            }
        }
        sqlite3_finalize(statement)
        return tasks
    }
    
    func fetchGoToExercises() -> [String] {
        // Fetch top 3 most completed exercises, fallback to last completed if none
        let query = "SELECT name FROM Exercises WHERE completionCount > 0 ORDER BY completionCount DESC, lastCompleted DESC LIMIT 3"
        var statement: OpaquePointer?
        var names: [String] = []

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                if let cString = sqlite3_column_text(statement, 0) {
                    names.append(String(cString: cString).trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        }
        sqlite3_finalize(statement)
        
        if names.isEmpty {
            let fallbackQuery = "SELECT name FROM Exercises ORDER BY lastCompleted DESC LIMIT 3"
            if sqlite3_prepare_v2(db, fallbackQuery, -1, &statement, nil) == SQLITE_OK {
                while sqlite3_step(statement) == SQLITE_ROW {
                    if let cString = sqlite3_column_text(statement, 0) {
                        names.append(String(cString: cString).trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                }
            }
            sqlite3_finalize(statement)
        }
        
        print("DEBUG SQL: Found \(names.count) Go-To exercises in DB.")
        return names
    }

    // MARK: - Completion Logic
    
    func markTaskComplete(taskName: String) {
        let trimmedName = taskName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Update all state tables using LIKE and TRIM for safety
        let updateDaily = "UPDATE DailyTasks SET isCompleted = 1 WHERE TRIM(name) LIKE ?"
        let updateJourney = "UPDATE Journey SET isCompleted = 1 WHERE TRIM(name) LIKE ?"
        
        // 2. Increment the analytics count
        
        let updateExerciseStats = """
        UPDATE Exercises 
        SET completionCount = completionCount + 1, lastCompleted = CURRENT_TIMESTAMP 
        WHERE TRIM(name) LIKE ?
        """
        
        executeNameUpdate(query: updateDaily, name: trimmedName)
        executeNameUpdate(query: updateJourney, name: trimmedName)
        executeNameUpdate(query: updateExerciseStats, name: trimmedName)
        
        // 3. Force a cross-check immediately
        syncLegacyJourneyCompletions()
        
        updateDailyGoalCompletionStatus()

        if isDailyGoalCompleted {
            updateStreakIfEligible()
        }

        // 4. Notify UI to refresh 'Try New' and 'Go-To'
        NotificationCenter.default.post(name: NSNotification.Name("dailyTasksUpdated"), object: nil)
        
        if SessionManager.shared.isAccountMode {
            SupabaseSyncManager.shared.pushJourneyUpdate(name: trimmedName, isCompleted: true)
            // syncLocalDailyTasksToCloud handles a full push of all tasks including this one;
            // calling markDailyTaskCompletedInCloud separately was a redundant double-write.
            syncLocalDailyTasksToCloud()
        }
    }
    func markExComplete(taskName: String) {
        let trimmedName = taskName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Update all state tables using LIKE and TRIM for safety
        
        let updateJourney = "UPDATE Journey SET isCompleted = 1 WHERE TRIM(name) LIKE ?"
        
        // 2. Increment the analytics count
        
        let updateExerciseStats = """
        UPDATE Exercises 
        SET completionCount = completionCount + 1, lastCompleted = CURRENT_TIMESTAMP 
        WHERE TRIM(name) LIKE ?
        """
        
        
        executeNameUpdate(query: updateJourney, name: trimmedName)
        executeNameUpdate(query: updateExerciseStats, name: trimmedName)
        
        // 3. Force a cross-check immediately
        syncLegacyJourneyCompletions()
        
        updateDailyGoalCompletionStatus()

        if isDailyGoalCompleted {
            updateStreakIfEligible()
        }

        // 4. Notify UI to refresh 'Try New' and 'Go-To'
        NotificationCenter.default.post(name: NSNotification.Name("dailyTasksUpdated"), object: nil)
        
        // NOTE: Do NOT call markDailyTaskCompletedInCloud or syncLocalDailyTasksToCloud here.
        // This path (Exercise tab) must never write to the daily_tasks Supabase table.
        // Only journey progression and exercise analytics are synced to the cloud.
        if SessionManager.shared.isAccountMode {
            SupabaseSyncManager.shared.pushJourneyUpdate(name: trimmedName, isCompleted: true)
        }
    }

    func syncLegacyJourneyCompletions() {
        let syncQuery = """
        UPDATE Exercises 
        SET completionCount = 1, lastCompleted = CURRENT_TIMESTAMP 
        WHERE TRIM(name) IN (SELECT TRIM(name) FROM Journey WHERE isCompleted = 1)
        AND completionCount = 0
        """
        
        sqlite3_exec(db, syncQuery, nil, nil, nil)
        print("🔄 Try New Sync: Journey progress synced to Exercises analytics.")
    }
    
    func syncLocalDailyTasksToCloud() {
        guard SessionManager.shared.isAccountMode else {
            print("📋 [GUEST] Skipping cloud sync of daily tasks (guest mode)")
            return
        }
        let tasks = fetchDailyTasks()
        for task in tasks {
            SupabaseSyncManager.shared.pushDailyTaskUpdate(
                id: task.id,
                name: task.name,
                description: task.description,
                duration: task.duration,
                isCompleted: task.isCompleted
            )
        }
    }
    
    private func executeNameUpdate(query: String, name: String) {
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (name as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
    }
    
    private func debugExerciseState(name: String) {
        let query = "SELECT completionCount, lastCompleted FROM Exercises WHERE TRIM(name) LIKE ?"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (name as NSString).utf8String, -1, SQLITE_TRANSIENT)
            
            if sqlite3_step(statement) == SQLITE_ROW {
                let count = sqlite3_column_int(statement, 0)
                if let text = sqlite3_column_text(statement, 1) {
                    let date = String(cString: text)
                    print("   ✅ Found: completionCount=\(count), lastCompleted=\(date)")
                } else {
                    print("   ✅ Found: completionCount=\(count), lastCompleted=nil")
                }
            } else {
                print("   ❌ NOT FOUND in Exercises table!")
                print("   Checking for similar names...")
                listAllExercises()
            }
        }
        sqlite3_finalize(statement)
    }
    
    private func listAllExercises() {
        let query = "SELECT name, completionCount FROM Exercises ORDER BY name"
        var statement: OpaquePointer?
        var found = false
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                if let cString = sqlite3_column_text(statement, 0) {
                    let name = String(cString: cString)
                    let count = sqlite3_column_int(statement, 1)
                    print("      - \(name) (count: \(count))")
                    found = true
                }
            }
        }
        sqlite3_finalize(statement)
        
        if !found {
            print("      (Exercises table is empty!)")
        }
    }
    
    func updateDailyGoalCompletionStatus() {
        let query = "SELECT COUNT(*) FROM DailyTasks WHERE isCompleted = 0"
        var statement: OpaquePointer?
        var pendingCount = 0

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                pendingCount = Int(sqlite3_column_int(statement, 0))
            }
        }
        sqlite3_finalize(statement)

        isDailyGoalCompleted = (pendingCount == 0)
        
        if isDailyGoalCompleted {
            NotificationManager.shared.cancelTodayNightReminder()
        }

        NotificationCenter.default.post(
            name: NSNotification.Name("dailyGoalStatusUpdated"),
            object: isDailyGoalCompleted
        )
    }

    func initializeStreakIfNeeded() {
        let query = "SELECT COUNT(*) FROM Streak"
        var stmt: OpaquePointer?
        var count = 0

        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                count = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)

        if count == 0 {
            let insert = "INSERT INTO Streak (id, currentStreak, lastCompletedDate) VALUES (1, 0, NULL)"
            sqlite3_exec(db, insert, nil, nil, nil)
        }
    }

    private func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func yesterdayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
    }

    func updateStreakIfEligible() {
        guard isDailyGoalCompleted else { return }

        let query = "SELECT currentStreak, lastCompletedDate FROM Streak WHERE id = 1"
        var stmt: OpaquePointer?

        var currentStreak = 0
        var lastDate: String?

        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                currentStreak = Int(sqlite3_column_int(stmt, 0))
                if let text = sqlite3_column_text(stmt, 1) {
                    lastDate = String(cString: text)
                }
            }
        }
        sqlite3_finalize(stmt)

        let today = todayString()
        let yesterday = yesterdayString()

        if lastDate == today { return }

        let newStreak: Int
        if lastDate == yesterday {
            newStreak = currentStreak + 1
        } else {
            newStreak = 1
        }

        let update = """
        UPDATE Streak
        SET currentStreak = ?, lastCompletedDate = ?
        WHERE id = 1
        """
        var updateStmt: OpaquePointer?

        if sqlite3_prepare_v2(db, update, -1, &updateStmt, nil) == SQLITE_OK {
            sqlite3_bind_int(updateStmt, 1, Int32(newStreak))
            sqlite3_bind_text(updateStmt, 2, (today as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_step(updateStmt)
        }
        sqlite3_finalize(updateStmt)

        NotificationCenter.default.post(
            name: NSNotification.Name("streakUpdated"),
            object: newStreak
        )
        
        if SessionManager.shared.isAccountMode {
            SupabaseSyncManager.shared.pushStreak(currentStreak: newStreak)
        } else {
            print("📋 [GUEST] Streak updated locally only (guest mode)")
        }
    }

    func fetchCurrentStreak() -> Int {
        let query = "SELECT currentStreak FROM Streak WHERE id = 1"
        var stmt: OpaquePointer?
        var streak = 0

        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                streak = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        return streak
    }

    func getCompletedJourneyCount() -> Int {
        let query = "SELECT COUNT(*) FROM Journey WHERE isCompleted = 1"
        var stmt: OpaquePointer?
        var count = 0
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                count = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        return count
    }

    func getTotalJourneyCount() -> Int {
        let query = "SELECT COUNT(*) FROM Journey"
        var stmt: OpaquePointer?
        var count = 0
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                count = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        return count
    }
    
    func resetDatabaseForNewUser() {
        if db != nil {
            if sqlite3_close(db) != SQLITE_OK {
                print("Warning: Could not close Spasht database perfectly.")
            }
            db = nil
        }
        
        isDailyGoalCompleted = false
        
        do {
            let fileUrl = try FileManager.default
                .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
                .appendingPathComponent("Spasht.sqlite")
            
            let pathsToDelete = [
                fileUrl.path,
                fileUrl.path + "-wal",
                fileUrl.path + "-shm"
            ]
            
            for path in pathsToDelete {
                if FileManager.default.fileExists(atPath: path) {
                    try FileManager.default.removeItem(atPath: path)
                }
            }
            print("Old Spasht database and WAL files permanently deleted.")
        } catch {
            print("Error deleting Spasht database files: \(error)")
        }
        
        openDatabase()
        createTables()
        populateInitialJourney()
        initializeStreakIfNeeded()
        
        print("Spasht Database engine rebooted and ready for Guest.")
    }

    // MARK: - Library & Discovery Functions
    
    /// Returns true if the user has saved at least one problem phoneme group (i.e. went through phoneme selection).
    func hasUserPhonemes() -> Bool {
        let query = "SELECT COUNT(*) FROM UserPhonemes"
        var stmt: OpaquePointer?
        var count = 0
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                count = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        return count > 0
    }
    
    /// Fetches exactly 5 warmup exercises tailored to the user's problem phonemes.
    ///
    /// Algorithm:
    ///   1. Up to 3 exercises whose targetPhoneme matches any saved UserPhoneme group,
    ///      ordered by lastCompleted ASC (least recently done first).
    ///   2. Remaining slots (up to 5 total) filled from general exercises
    ///      (those with an empty or null targetPhoneme), again ordered by lastCompleted ASC.
    ///
    /// Returns an empty array if UserPhonemes is empty — caller should fall back to WarmUp.json.
    func fetchWarmupExercises() -> [String] {
        guard hasUserPhonemes() else {
            print("🔥 [Warmup] No user phonemes found — caller should use static WarmUp.json fallback.")
            return []
        }
        
        var results: [String] = []
        
        // STEP 1: Phoneme-matched exercises (up to 3)
        let phonemeQuery = """
        SELECT DISTINCT e.name
        FROM Exercises e
        JOIN UserPhonemes u ON e.targetPhoneme = u.phoneme
        ORDER BY e.lastCompleted ASC
        LIMIT 3
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, phonemeQuery, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let cString = sqlite3_column_text(stmt, 0) {
                    results.append(String(cString: cString).trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        }
        sqlite3_finalize(stmt)
        print("🔥 [Warmup] Phoneme-matched: \(results)")
        
        // STEP 2: Fill remaining slots with general exercises (no specific phoneme target)
        let needed = 5 - results.count
        if needed > 0 {
            // Build an exclusion placeholder list so we don't duplicate Step 1 results
            let placeholders = results.isEmpty ? "''" : results.map { _ in "?" }.joined(separator: ", ")
            let generalQuery = """
            SELECT name FROM Exercises
            WHERE (targetPhoneme IS NULL OR TRIM(targetPhoneme) = '')
            AND TRIM(name) NOT IN (\(placeholders))
            ORDER BY lastCompleted ASC
            LIMIT \(needed)
            """
            if sqlite3_prepare_v2(db, generalQuery, -1, &stmt, nil) == SQLITE_OK {
                for (i, name) in results.enumerated() {
                    sqlite3_bind_text(stmt, Int32(i + 1), (name as NSString).utf8String, -1, SQLITE_TRANSIENT)
                }
                while sqlite3_step(stmt) == SQLITE_ROW {
                    if let cString = sqlite3_column_text(stmt, 0) {
                        results.append(String(cString: cString).trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                }
            }
            sqlite3_finalize(stmt)
        }
        
        print("🔥 [Warmup] Final 5 exercises: \(results)")
        return results
    }
    
    func fetchPhonemeBasedExercises() -> [String] {
        let query = """
        SELECT DISTINCT e.name 
        FROM Exercises e 
        JOIN UserPhonemes u ON e.targetPhoneme = u.phoneme 
        ORDER BY e.lastCompleted ASC 
        LIMIT 5
        """
        
        var statement: OpaquePointer?
        var names: [String] = []

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                if let cString = sqlite3_column_text(statement, 0) {
                    names.append(String(cString: cString).trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        }
        sqlite3_finalize(statement)
        return names
    }
    
    func fetchDiscoveryExercise() -> (sectionTitle: String, exerciseName: String?) {
        let tryNewQuery = "SELECT name FROM Exercises WHERE completionCount = 0 ORDER BY id ASC LIMIT 1"
        var statement: OpaquePointer?
        
        print("🔍 [fetchDiscoveryExercise] Looking for uncompleted exercises (completionCount = 0)...")
        
        if sqlite3_prepare_v2(db, tryNewQuery, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                let name = String(cString: sqlite3_column_text(statement, 0)).trimmingCharacters(in: .whitespacesAndNewlines)
                sqlite3_finalize(statement)
                print("   ✅ Try New: '\(name)'")
                return ("Try New", name)
            } else {
                print("   ⚠️ No uncompleted exercises found!")
            }
        }
        sqlite3_finalize(statement)
        
        print("🔍 Falling back to 'Explore Again' (most recent)...")
        let exploreAgainQuery = "SELECT name FROM Exercises ORDER BY lastCompleted DESC LIMIT 1"
        if sqlite3_prepare_v2(db, exploreAgainQuery, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                let name = String(cString: sqlite3_column_text(statement, 0)).trimmingCharacters(in: .whitespacesAndNewlines)
                sqlite3_finalize(statement)
                print("   ✅ Explore Again: '\(name)'")
                return ("Explore Again", name)
            }
        }
        sqlite3_finalize(statement)
        
        print("   ❌ No exercises found at all!")
        return ("Explore Again", nil)
    }
    
    // MARK: - User Phoneme & Database Seeding Functions
    
    func saveUserProblemPhonemes(phonemes: [String]) {
        let clearQuery = "DELETE FROM UserPhonemes"
        sqlite3_exec(db, clearQuery, nil, nil, nil)
        
        let insertQuery = "INSERT INTO UserPhonemes (phoneme) VALUES (?)"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertQuery, -1, &statement, nil) == SQLITE_OK {
            for phoneme in phonemes {
                sqlite3_bind_text(statement, 1, (phoneme as NSString).utf8String, -1, SQLITE_TRANSIENT)
                if sqlite3_step(statement) != SQLITE_DONE {
                    print("Error inserting phoneme: \(phoneme)")
                }
                sqlite3_reset(statement)
            }
        }
        sqlite3_finalize(statement)
        print("User problem phonemes updated!")
    }
    
    func seedExercisesDatabase(with names: [String]) {
        // We iterate through every provided name. If it's missing from the DB, we insert it with 0 completions.
        // If it's already there, we LEAVE IT ALONE so we don't accidentally erase analytics data.
        for name in names {
            let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            
            var checkStmt: OpaquePointer?
            var exists = false
            let checkQuery = "SELECT 1 FROM Exercises WHERE TRIM(name) LIKE ?"
            
            if sqlite3_prepare_v2(db, checkQuery, -1, &checkStmt, nil) == SQLITE_OK {
                sqlite3_bind_text(checkStmt, 1, (cleanName as NSString).utf8String, -1, SQLITE_TRANSIENT)
                if sqlite3_step(checkStmt) == SQLITE_ROW {
                    exists = true
                }
            }
            sqlite3_finalize(checkStmt)
            
            if !exists {
                let insertQuery = "INSERT INTO Exercises (name, completionCount, targetPhoneme) VALUES (?, 0, ?)"
                var insertStmt: OpaquePointer?
                
                if sqlite3_prepare_v2(db, insertQuery, -1, &insertStmt, nil) == SQLITE_OK {
                    sqlite3_bind_text(insertStmt, 1, (cleanName as NSString).utf8String, -1, SQLITE_TRANSIENT)
                    
                    var target = ""
                    if cleanName == "Gentle Onset" || cleanName == "Airflow Practice" { target = "Vowels (A,E,I,O,U) & Voiced (M,N,L)" }
                    else if cleanName == "Light Contacts" { target = "Plosives (P, B, T, D, K, G)" }
                    else if cleanName == "Prolongation" { target = "Fricatives (S, F, SH, TH)" }
                    
                    sqlite3_bind_text(insertStmt, 2, (target as NSString).utf8String, -1, SQLITE_TRANSIENT)
                    
                    sqlite3_step(insertStmt)
                }
                sqlite3_finalize(insertStmt)
            }
        }
        print("✅ Seeding Complete! Safe insert logic applied.")
    }
}
