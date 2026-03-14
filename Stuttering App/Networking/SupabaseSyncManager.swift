//
//  SupabaseSyncManager.swift
//  Stuttering App
//

import Foundation
import Supabase
import SQLite3



class SupabaseSyncManager {
    static let shared = SupabaseSyncManager()
    
    private let client = SupabaseManager.shared.client
    
    private var lastSyncDateString: String {
        get {
            return UserDefaults.standard.string(forKey: "LastDeltaSyncDate") ?? "1970-01-01T00:00:00Z"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "LastDeltaSyncDate")
        }
    }
    
    private init() {}
    
    // MARK: - Auth Sync triggered on Login
    
    // Called immediately after a successful login to pull down all historic user data
    func syncAllDataFromCloud(completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                guard let userId = client.auth.currentUser?.id.uuidString else {
                    throw NSError(domain: "SupabaseSync", code: 401, userInfo: [NSLocalizedDescriptionKey: "No logged in user"])
                }
                
                let syncStartTime = ISO8601DateFormatter().string(from: Date())
                print("☁️ Starting cloud sync for user: \(userId)")
                
                // Ensure AwardsDB is open and seeded before any restore
                if AwardsManager.shared.db == nil {
                    AwardsManager.shared.openDatabase()
                    AwardsManager.shared.seedDatabaseIfNeeded()
                    print("☁️ AwardsDB initialized")
                }
                
                // 1. Fetch Profile
                try await fetchAndRestoreProfile(userId: userId)
                print("☁️ ✅ Profile restored")
                
                // 2. Fetch Daily Tasks & Journey
                try await fetchAndRestoreGoals(userId: userId)
                print("☁️ ✅ Goals/Journey/Streak restored")
                
                // 3. Fetch Analytics (Exercise Logs, Reading Sessions, Conversations)
                try await fetchAndRestoreAnalytics(userId: userId)
                print("☁️ ✅ Analytics restored")
                
                // 4. Fetch Awards
                try await fetchAndRestoreAwards(userId: userId)
                print("☁️ ✅ Awards restored")
                
                // Update delta sync time
                lastSyncDateString = syncStartTime
                print("☁️ ✅ ALL DATA SYNCED SUCCESSFULLY")
                
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } catch {
                print("☁️ ❌ Sync FAILED: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // Evaluates if any rows have been updated past the local `lastSyncDateString`
    // Evaluates if any rows have been updated past the local `lastSyncDateString`
    func hasPendingCloudChanges() async throws -> Bool {
        guard let userId = client.auth.currentUser?.id.uuidString else {
            throw NSError(domain: "SupabaseSync", code: 401, userInfo: [NSLocalizedDescriptionKey: "No logged in user"])
        }
        
        let params: [String: AnyJSON] = [
            "last_sync": .string(lastSyncDateString),
            "user_uuid": .string(userId)
        ]
        
        let hasUpdates: Bool = try await client.rpc("has_pending_sync", params: params).execute().value
        return hasUpdates
        
    }
    
    // Call this AFTER checkForNewDay() to re-apply daily task completions
    // that the reset would have wiped.
    func reapplyDailyTaskCompletions(completion: @escaping () -> Void) {
        Task {
            guard let userId = client.auth.currentUser?.id.uuidString else {
                DispatchQueue.main.async { completion() }
                return
            }
            
            struct DailyTaskRow: Decodable {
                let name: String
                let is_completed: Bool
            }
            
            do {
                // Fetch from Supabase directly via client.from()
                let tasks: [DailyTaskRow] = try await client
                    .from("daily_tasks")
                    .select("name, is_completed")
                    .eq("user_id", value: userId)
                    .eq("is_completed", value: true)
                    .execute()
                    .value
                            
                print("☁️ Reapplying \(tasks.count) completed daily tasks")
                            
                for t in tasks {
                    let sql = "UPDATE DailyTasks SET isCompleted = 1 WHERE name = ?"
                    var stmt: OpaquePointer?
                    
                    if sqlite3_prepare_v2(DatabaseManager.shared.db, sql, -1, &stmt, nil) == SQLITE_OK {
                        sqlite3_bind_text(stmt, 1, (t.name as NSString).utf8String, -1, nil)
                        let result = sqlite3_step(stmt)
                        let changes = sqlite3_changes(DatabaseManager.shared.db)
                        
                        print("☁️   Task '\(t.name)': \(changes) rows updated")
                        if result != SQLITE_DONE {
                            print("☁️   ⚠️ Step failed for '\(t.name)'")
                        }
                    }
                    sqlite3_finalize(stmt)
                }
                // Also update the daily goal status
                DatabaseManager.shared.updateDailyGoalCompletionStatus()
                
            } catch {
                print("☁️ ❌ Failed to reapply daily tasks: \(error)")
            }
            
            DispatchQueue.main.async { completion() }
        }
    }
    
    // MARK: - Restore Helpers
    
    private func fetchAndRestoreProfile(userId: String) async throws {
        struct ProfileRow: Decodable {
            let first_name: String?
            let last_name: String?
            let dob: String?
            let mobile: String?
            let is_onboarding_completed: Bool?
        }
        
        let rows: [ProfileRow] = try await client
            .from("profiles")
            .select("first_name, last_name, dob, mobile, is_onboarding_completed")
            .eq("id", value: userId)
            .limit(1)
            .execute()
            .value
        
        if let row = rows.first {
            let profile = UserProfile(
                id: userId,
                firstName: row.first_name,
                lastName: row.last_name,
                dob: row.dob,
                mobile: row.mobile,
                isOnboardingCompleted: row.is_onboarding_completed ?? false
            )
            LogManager.shared.saveProfile(profile, fromSync: true)
            
            // Restore onboarding status from cloud
            if let onboardingDone = row.is_onboarding_completed {
                AppState.isOnboardingCompleted = onboardingDone
                print("☁️ Onboarding status restored: \(onboardingDone)")
            }
        }
        print("Profile restored.")
    }
    
    private func fetchAndRestoreGoals(userId: String) async throws {
        // --- Journey ---
        struct JourneyRow: Decodable {
            let name: String
            let is_completed: Bool
        }
        let journeys: [JourneyRow] = try await client
            .from("journeys")
            .select("name, is_completed")
            .eq("user_id", value: userId)
            .execute()
            .value
        
        for j in journeys where j.is_completed {
            let updateJourney = "UPDATE Journey SET isCompleted = 1 WHERE name = ?"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(DatabaseManager.shared.db, updateJourney, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (j.name as NSString).utf8String, -1, nil)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
        
        // --- Daily Tasks ---
        struct DailyTaskRow: Decodable {
            let id: Int
            let name: String
            let description: String?
            let duration: Int?
            let is_completed: Bool
        }
        let tasks: [DailyTaskRow] = try await client
            .from("daily_tasks")
            .select("id, name, description, duration, is_completed")
            .eq("user_id", value: userId)
            .gt("updated_at", value: lastSyncDateString)
            .execute()
            .value
        
        for t in tasks where t.is_completed {
            let updateTask = "UPDATE DailyTasks SET isCompleted = 1 WHERE name = ?"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(DatabaseManager.shared.db, updateTask, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (t.name as NSString).utf8String, -1, nil)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
        
        // --- Streak ---
        struct StreakRow: Decodable {
            let current_streak: Int
            let last_completed_date: String?
        }
        let streaks: [StreakRow] = try await client
            .from("streaks")
            .select("current_streak, last_completed_date")
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value
        
        if let streak = streaks.first {
            let update = "UPDATE Streak SET currentStreak = ?, lastCompletedDate = ? WHERE id = 1"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(DatabaseManager.shared.db, update, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int(stmt, 1, Int32(streak.current_streak))
                let dateStr = streak.last_completed_date ?? ""
                sqlite3_bind_text(stmt, 2, (dateStr as NSString).utf8String, -1, nil)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
        
        // --- User Goals ---
        struct UserGoalRow: Decodable {
            let goal_name: String
            let goal_value: Int
        }
        let goals: [UserGoalRow]? = try? await client
            .from("user_goals")
            .select("goal_name, goal_value")
            .eq("user_id", value: userId)
            .execute()
            .value
        
        if let goals = goals {
            for g in goals {
                LogManager.shared.updateGoal(name: g.goal_name, value: g.goal_value, fromSync: true)
            }
        }
        
        print("Goals & streak restored.")
    }
    
    private func fetchAndRestoreAnalytics(userId: String) async throws {
        let logDB = LogManager.shared.db
        
        LogManager.shared.initializeUserIfNeeded()
        let localUserId = LogManager.shared.getCurrentUserId() ?? userId
        
        // --- Exercise Logs ---
        struct ExerciseRow: Decodable {
            let id: String
            let exercise_name: String
            let completion_date: String
            let source: String
            let duration: Int
        }
        let exercises: [ExerciseRow] = try await client
            .from("exercise_logs")
            .select("id, exercise_name, completion_date, source, duration")
            .eq("user_id", value: userId)
            .gt("updated_at", value: lastSyncDateString)
            .execute()
            .value
        
        let exInsert = "INSERT OR REPLACE INTO ExerciseLog (id, exerciseName, completionDate, source, exerciseDuration) VALUES (?, ?, ?, ?, ?);"
        for ex in exercises {
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(logDB, exInsert, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (ex.id as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (ex.exercise_name as NSString).utf8String, -1, nil)
                let formatter = ISO8601DateFormatter()
                let epoch = formatter.date(from: ex.completion_date)?.timeIntervalSince1970 ?? Date().timeIntervalSince1970
                sqlite3_bind_double(stmt, 3, epoch)
                sqlite3_bind_text(stmt, 4, (ex.source as NSString).utf8String, -1, nil)
                sqlite3_bind_int(stmt, 5, Int32(ex.duration))
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
        print("Exercise logs restored: \(exercises.count) records.")
        
        // --- Reading Sessions ---
        struct ReadingRow: Decodable {
            let id: String
            let date: Double
            let duration: Double
            let fluency_score: Int
            let repetition_percent: Double?
            let prolongation_percent: Double?
            let block_percent: Double?
            let correct_percent: Double?
            let longest_smooth_paragraph: Int?
        }
        let readings: [ReadingRow] = try await client
            .from("reading_sessions")
            .select("id, date, duration, fluency_score, repetition_percent, prolongation_percent, block_percent, correct_percent, longest_smooth_paragraph")
            .eq("user_id", value: userId)
            .gt("updated_at", value: lastSyncDateString)
            .execute()
            .value
        
        let rsInsert = """
            INSERT OR REPLACE INTO ReadingSessions
            (id, userId, date, duration, fluencyScore,
            repetitionPercent, prolongationPercent,
            blockPercent, correctPercent, longestSmoothParagraph)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
        for rs in readings {
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(logDB, rsInsert, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (rs.id as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (localUserId as NSString).utf8String, -1, nil)
                sqlite3_bind_double(stmt, 3, rs.date)
                sqlite3_bind_double(stmt, 4, rs.duration)
                sqlite3_bind_int(stmt, 5, Int32(rs.fluency_score))
                sqlite3_bind_double(stmt, 6, rs.repetition_percent ?? 0.0)
                sqlite3_bind_double(stmt, 7, rs.prolongation_percent ?? 0.0)
                sqlite3_bind_double(stmt, 8, rs.block_percent ?? 0.0)
                sqlite3_bind_double(stmt, 9, rs.correct_percent ?? 0.0)
                sqlite3_bind_int(stmt, 10, Int32(rs.longest_smooth_paragraph ?? 0))
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
        print("Reading sessions restored: \(readings.count) records.")
        
        // --- Troubled Words ---
        struct TroubledWordRow: Decodable {
            let id: String
            let session_id: String
            let word: String
            let type: String
            let first_letter: String?
        }
        let troubledWords: [TroubledWordRow]? = try? await client
            .from("troubled_words")
            .select("id, session_id, word, type, first_letter")
            .eq("user_id", value: userId)
            .execute()
            .value
        
        if let tws = troubledWords {
            let twInsert = "INSERT OR IGNORE INTO TroubledWords (id, sessionId, userId, word, type, firstLetter) VALUES (?, ?, ?, ?, ?, ?)"
            for tw in tws {
                var stmt: OpaquePointer?
                if sqlite3_prepare_v2(logDB, twInsert, -1, &stmt, nil) == SQLITE_OK {
                    sqlite3_bind_text(stmt, 1, (tw.id as NSString).utf8String, -1, nil)
                    sqlite3_bind_text(stmt, 2, (tw.session_id as NSString).utf8String, -1, nil)
                    sqlite3_bind_text(stmt, 3, (localUserId as NSString).utf8String, -1, nil)
                    sqlite3_bind_text(stmt, 4, (tw.word as NSString).utf8String, -1, nil)
                    sqlite3_bind_text(stmt, 5, (tw.type as NSString).utf8String, -1, nil)
                    sqlite3_bind_text(stmt, 6, ((tw.first_letter ?? "") as NSString).utf8String, -1, nil)
                    sqlite3_step(stmt)
                }
                sqlite3_finalize(stmt)
            }
            print("Troubled words restored: \(tws.count) records.")
        }

        // --- Session Letter Stats ---
        struct SessionLetterStatRow: Decodable {
            let session_id: String
            let letter: String
            let stutter_count: Int
        }
        let sls: [SessionLetterStatRow]? = try? await client
            .from("session_letter_stats")
            .select("session_id, letter, stutter_count")
            .eq("user_id", value: userId)
            .execute()
            .value
        
        if let sls = sls {
            let slsInsert = "INSERT OR IGNORE INTO SessionLetterStats (sessionId, userId, letter, stutterCount) VALUES (?, ?, ?, ?)"
            for s in sls {
                var stmt: OpaquePointer?
                if sqlite3_prepare_v2(logDB, slsInsert, -1, &stmt, nil) == SQLITE_OK {
                    sqlite3_bind_text(stmt, 1, (s.session_id as NSString).utf8String, -1, nil)
                    sqlite3_bind_text(stmt, 2, (localUserId as NSString).utf8String, -1, nil)
                    sqlite3_bind_text(stmt, 3, (s.letter as NSString).utf8String, -1, nil)
                    sqlite3_bind_int(stmt, 4, Int32(s.stutter_count))
                    sqlite3_step(stmt)
                }
                sqlite3_finalize(stmt)
            }
            print("Session letter stats restored: \(sls.count) records.")
        }

        // --- Letter Stats ---
        struct LetterStatRow: Decodable {
            let letter: String
            let count: Int
        }
        let ls: [LetterStatRow]? = try? await client
            .from("letter_stats")
            .select("letter, count")
            .eq("user_id", value: userId)
            .execute()
            .value
        
        if let ls = ls {
            let lsInsert = "INSERT OR REPLACE INTO LetterStats (userId, letter, count) VALUES (?, ?, ?)"
            for l in ls {
                var stmt: OpaquePointer?
                if sqlite3_prepare_v2(logDB, lsInsert, -1, &stmt, nil) == SQLITE_OK {
                    sqlite3_bind_text(stmt, 1, (localUserId as NSString).utf8String, -1, nil)
                    sqlite3_bind_text(stmt, 2, (l.letter as NSString).utf8String, -1, nil)
                    sqlite3_bind_int(stmt, 3, Int32(l.count))
                    sqlite3_step(stmt)
                }
                sqlite3_finalize(stmt)
            }
            print("Letter stats restored: \(ls.count) records.")
        }
        
        // --- Conversation Sessions ---
        struct ConvoRow: Decodable {
            let id: String
            let date: Double
            let duration: Double
            let filler_word_percent: Double?
            let longest_smooth_talk: Int?
        }
        let convos: [ConvoRow] = try await client
            .from("conversation_sessions")
            .select("id, date, duration, filler_word_percent, longest_smooth_talk")
            .eq("user_id", value: userId)
            .gt("updated_at", value: lastSyncDateString)
            .execute()
            .value
        
        let csInsert = """
            INSERT OR REPLACE INTO ConversationSessions
            (id, userId, date, duration, fillerWordPercent, longestSmoothTalk)
            VALUES (?, ?, ?, ?, ?, ?);
            """
        for cs in convos {
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(logDB, csInsert, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (cs.id as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (localUserId as NSString).utf8String, -1, nil)
                sqlite3_bind_double(stmt, 3, cs.date)
                sqlite3_bind_double(stmt, 4, cs.duration)
                sqlite3_bind_double(stmt, 5, cs.filler_word_percent ?? 0.0)
                sqlite3_bind_int(stmt, 6, Int32(cs.longest_smooth_talk ?? 0))
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
        print("Conversation sessions restored: \(convos.count) records.")
    }
    
    private func fetchAndRestoreAwards(userId: String) async throws {
        struct AwardRow: Decodable {
            let award_id: String
            let progress: Double
            let status: String
        }
        let awards: [AwardRow] = try await client
            .from("user_awards")
            .select("award_id, progress, status")
            .eq("user_id", value: userId)
            .gt("updated_at", value: lastSyncDateString)
            .execute()
            .value
        
        if AwardsManager.shared.db == nil {
            AwardsManager.shared.openDatabase()
            AwardsManager.shared.seedDatabaseIfNeeded()
        }
        
        for award in awards {
            let query = "UPDATE Awards SET progress = ?, status = ?, completionDate = ? WHERE id = ?"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(AwardsManager.shared.db, query, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_double(stmt, 1, award.progress)
                sqlite3_bind_text(stmt, 2, (award.status as NSString).utf8String, -1, nil)
                let completionDate = award.progress >= 1.0 ? Date().timeIntervalSince1970 : 0.0
                sqlite3_bind_double(stmt, 3, completionDate)
                sqlite3_bind_text(stmt, 4, (award.award_id as NSString).utf8String, -1, nil)
                if sqlite3_step(stmt) == SQLITE_DONE {
                    let changes = sqlite3_changes(AwardsManager.shared.db)
                    print("☁️ Award '\(award.award_id)' progress=\(award.progress) status=\(award.status) → \(changes) rows updated")
                } else {
                    print("☁️ ❌ Failed to restore award '\(award.award_id)'")
                }
            } else {
                print("Failed to prepare award restore statement")
            }
            sqlite3_finalize(stmt)
        }
        print("Awards restored: \(awards.count) records.")
    }
    
    
    // MARK: - Push Local Changes to Cloud (Local-First Sync)
    
    func pushReadingSession(_ report: StutterJSONReport, duration: TimeInterval, sessionId: String, longestSmoothParagraph: Int = 0) {
        Task {
            guard let userId = client.auth.currentUser?.id else { return }
            do {
                let sessionData: [String: AnyJSON] = [
                    "id": .string(sessionId),
                    "user_id": .string(userId.uuidString),
                    "date": .double(Date().timeIntervalSince1970),
                    "duration": .double(duration),
                    "fluency_score": .integer(report.fluencyScore),
                    "repetition_percent": .double(report.percentages.repetition),
                    "prolongation_percent": .double(report.percentages.prolongation),
                    "block_percent": .double(report.percentages.blocks),
                    "correct_percent": .double(report.percentages.correct),
                    "longest_smooth_paragraph": .integer(longestSmoothParagraph)
                ]
                
                try await client
                    .from("reading_sessions")
                    .upsert(sessionData)
                    .execute()
                
                // Push troubled words
                for word in report.stutteredWords {
                    let type: String
                    let lowerWord = word.lowercased()
                    if report.breakdown.repetition.contains(where: { $0.lowercased() == lowerWord }) { type = "repetition" }
                    else if report.breakdown.prolongation.contains(where: { $0.lowercased() == lowerWord }) { type = "prolongation" }
                    else { type = "block" }
                    
                    let wordData: [String: AnyJSON] = [
                        "id": .string(UUID().uuidString),
                        "session_id": .string(sessionId),
                        "user_id": .string(userId.uuidString),
                        "word": .string(word),
                        "type": .string(type),
                        "first_letter": .string(String(word.prefix(1)).uppercased())
                    ]
                    try await client.from("troubled_words").upsert(wordData).execute()
                }
                
                // Push session letter stats
                for (letter, count) in report.letterAnalysis {
                    let letterData: [String: AnyJSON] = [
                        "session_id": .string(sessionId),
                        "user_id": .string(userId.uuidString),
                        "letter": .string(letter),
                        "stutter_count": .integer(count)
                    ]
                    try await client.from("session_letter_stats").upsert(letterData).execute()
                }
                print("Successfully pushed ReadingSession and its stats to Supabase")
            } catch {
                print("Failed to push ReadingSession to Supabase: \(error)")
            }
        }
    }
    
    func pushStreak(currentStreak: Int) {
        Task {
            guard let userId = client.auth.currentUser?.id else { return }
            do {
                let streakData: [String: AnyJSON] = [
                    "user_id": .string(userId.uuidString),
                    "current_streak": .integer(currentStreak),
                    "updated_at": .string(ISO8601DateFormatter().string(from: Date()))
                ]
                try await client
                    .from("streaks")
                    .upsert(streakData)
                    .execute()
            } catch {
                print("Failed to push Streak to Supabase: \(error)")
            }
        }
    }
    
    func pushProfileUpdate(key: String, value: String) {
        Task {
            guard let userId = client.auth.currentUser?.id else { return }
            do {
                let profileData: [String: AnyJSON] = [
                    "id": .string(userId.uuidString),
                    key: .string(value),
                    "updated_at": .string(ISO8601DateFormatter().string(from: Date()))
                ]
                try await client
                    .from("profiles")
                    .upsert(profileData)
                    .execute()
            } catch {
                print("Failed to push Profile update to Supabase: \(error)")
            }
        }
    }
    
    func pushOnboardingStatus(isCompleted: Bool) {
        Task {
            guard let userId = client.auth.currentUser?.id else { return }
            do {
                let data: [String: AnyJSON] = [
                    "id": .string(userId.uuidString),
                    "is_onboarding_completed": .bool(isCompleted),
                    "updated_at": .string(ISO8601DateFormatter().string(from: Date()))
                ]
                try await client
                    .from("profiles")
                    .upsert(data)
                    .execute()
                print("☁️ ✅ Onboarding status pushed: \(isCompleted)")
            } catch {
                print("☁️ ❌ Failed to push onboarding status: \(error)")
            }
        }
    }
    
    func pushAwardUpdate(awardId: String, progress: Double, status: String) {
        Task {
            guard let userId = client.auth.currentUser?.id else { return }
            do {
                let awardData: [String: AnyJSON] = [
                    "id": .string(UUID().uuidString),
                    "user_id": .string(userId.uuidString),
                    "award_id": .string(awardId),
                    "progress": .double(progress),
                    "status": .string(status),
                    "updated_at": .string(ISO8601DateFormatter().string(from: Date()))
                ]
                try await client
                    .from("user_awards")
                    .upsert(awardData, onConflict: "user_id, award_id")
                    .execute()
            } catch {
                print("Failed to push Award update to Supabase: \(error)")
            }
        }
    }
    
    // MARK: - Exercise & Journey Sync
    
    func pushExerciseLog(id: String, name: String, source: String, duration: Int) {
        Task {
            guard let userId = client.auth.currentUser?.id else { return }
            do {
                let logData: [String: AnyJSON] = [
                    "id": .string(id),
                    "user_id": .string(userId.uuidString),
                    "exercise_name": .string(name),
                    "source": .string(source),
                    "duration": .integer(duration),
                    "completion_date": .string(ISO8601DateFormatter().string(from: Date()))
                ]
                try await client
                    .from("exercise_logs")
                    .upsert(logData)
                    .execute()
            } catch {
                print("Failed to push ExerciseLog to Supabase: \(error)")
            }
        }
    }
    
    func pushJourneyUpdate(name: String, isCompleted: Bool) {
        Task {
            guard let userId = client.auth.currentUser?.id else { return }
            do {
                let journeyData: [String: AnyJSON] = [
                    "user_id": .string(userId.uuidString),
                    "name": .string(name),
                    "is_completed": .bool(isCompleted),
                    "updated_at": .string(ISO8601DateFormatter().string(from: Date()))
                ]
                try await client
                    .from("journeys")
                    .upsert(journeyData, onConflict: "user_id, name")
                    .execute()
            } catch {
                print("Failed to push Journey update to Supabase: \(error)")
            }
        }
    }
    
    func pushDailyTaskUpdate(id: Int, name: String, description: String, duration: Int, isCompleted: Bool) {
        Task {
            guard let userId = client.auth.currentUser?.id else { return }
            do {
                let taskData: [String: AnyJSON] = [
                    "id": .integer(id),
                    "user_id": .string(userId.uuidString),
                    "name": .string(name),
                    "description": .string(description),
                    "duration": .integer(duration),
                    "is_completed": .bool(isCompleted),
                    "updated_at": .string(ISO8601DateFormatter().string(from: Date()))
                ]
                try await client
                    .from("daily_tasks")
                    .upsert(taskData, onConflict: "id, user_id")
                    .execute()
            } catch {
                print("Failed to push DailyTask update to Supabase: \(error)")
            }
        }
    }
    
    func markDailyTaskCompletedInCloud(name: String) {
        Task {
            guard let userId = client.auth.currentUser?.id else { return }
            do {
                let updateData: [String: AnyJSON] = [
                    "is_completed": .bool(true),
                    "updated_at": .string(ISO8601DateFormatter().string(from: Date()))
                ]
                try await client
                    .from("daily_tasks")
                    .update(updateData)
                    .eq("user_id", value: userId.uuidString)
                    .eq("name", value: name)
                    .execute()
                print("☁️ ✅ Daily task '\(name)' marked completed in Supabase")
            } catch {
                print("☁️ ❌ Failed to mark daily task completed: \(error)")
            }
        }
    }
    
    func pushConversationSession(sessionId: String, duration: TimeInterval, fillerWordPercent: Double, longestSmoothTalk: Int) {
        Task {
            guard let userId = client.auth.currentUser?.id else { return }
            do {
                let data: [String: AnyJSON] = [
                    "id": .string(sessionId),
                    "user_id": .string(userId.uuidString),
                    "date": .double(Date().timeIntervalSince1970),
                    "duration": .double(duration),
                    "filler_word_percent": .double(fillerWordPercent),
                    "longest_smooth_talk": .integer(longestSmoothTalk)
                ]
                try await client
                    .from("conversation_sessions")
                    .upsert(data)
                    .execute()
                print("Successfully pushed ConversationSession to Supabase")
            } catch {
                print("Failed to push ConversationSession to Supabase: \(error)")
            }
        }
    }
    
    func pushLetterStats(userId: String) {
        Task {
            do {
                let stats = LogManager.shared.getAllLetterStats(for: userId)
                guard !stats.isEmpty else { return }
                for (letter, count) in stats {
                    let data: [String: AnyJSON] = [
                        "user_id": .string(userId),
                        "letter": .string(letter),
                        "count": .integer(count)
                    ]
                    try await client.from("letter_stats").upsert(data, onConflict: "user_id, letter").execute()
                }
                print("Successfully pushed LetterStats to Supabase")
            } catch {
                print("Failed to push letter stats: \(error)")
            }
        }
    }

    func pushUserGoal(goalName: String, goalValue: Int) {
        Task {
            guard let userId = client.auth.currentUser?.id else { return }
            do {
                let data: [String: AnyJSON] = [
                    "user_id": .string(userId.uuidString),
                    "goal_name": .string(goalName),
                    "goal_value": .integer(goalValue)
                ]
                try await client.from("user_goals").upsert(data, onConflict: "user_id, goal_name").execute()
            } catch {
                print("Failed to push UserGoal: \(error)")
            }
        }
    }
}

