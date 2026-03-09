//
//  AwardsEvaluator.swift
//  Stuttering App 1
//
//

import Foundation

class AwardsEvaluator {

    static let shared = AwardsEvaluator()
    private init() {}

    private let awardsManager = AwardsManager.shared
    private let logManager    = LogManager.shared

    func evaluateAllAwards() {
        
        evaluateNormalAwards()
        evaluateWeeklyAwards()
    }
    
    private func evaluateNormalAwards() {

        let exerciseLogs     = logManager.getLogs(for: .exercises)
        let readingLogs      = logManager.getLogs(for: .reading)
        let conversationLogs = logManager.getLogs(for: .conversation)
        let dailyTaskLogs    = logManager.getLogs(for: .dailyTasks)
        let allLogs          = exerciseLogs + readingLogs + conversationLogs + dailyTaskLogs

        // ── nm_001 · First Step ───────────────────────────────────────────────
        // Trigger: Complete first daily task session (any 1 log from dailyTask)
        update(
            id: "nm_001",
            current: min(dailyTaskLogs.count, 1),
            total: 1,
            unit: "completed"
        )

        // ── nm_002 · Ice Breaker ──────────────────────────────────────────────
        // Trigger: Complete first Conversation Mode session
        update(
            id: "nm_002",
            current: min(conversationLogs.count, 1),
            total: 1,
            unit: "completed"
        )

        // ── nm_003 · First Read ───────────────────────────────────────────────
        // Trigger: Complete first Read Aloud session
        update(
            id: "nm_003",
            current: min(readingLogs.count, 1),
            total: 1,
            unit: "completed"
        )

        // ── nm_004 · All Rounder ──────────────────────────────────────────────
        // Trigger: Complete at least one session of all 8 distinct exercises
        let uniqueExercises = Set(exerciseLogs.map { $0.exerciseName }).count
        update(
            id: "nm_004",
            current: min(uniqueExercises, 8),
            total: 8,
            unit: "exercises"
        )

        // ── nm_005 · Drill Specialist ─────────────────────────────────────────
        // Trigger: Complete 50 total exercise sessions
        update(
            id: "nm_005",
            current: min(exerciseLogs.count, 50),
            total: 50,
            unit: "sessions"
        )

        // ── nm_006 · Page Turner ──────────────────────────────────────────────
        // Trigger: Accumulate 60 minutes total across Read Aloud sessions
        // Note: exerciseDuration is stored in seconds in LogManager
        let readingSeconds = readingLogs.reduce(0) { $0 + $1.exerciseDuration }
        let readingMinutes = readingSeconds / 60
        update(
            id: "nm_006",
            current: min(readingMinutes, 60),
            total: 60,
            unit: "minutes"
        )

        // ── nm_007 · Chatterbox ───────────────────────────────────────────────
        // Trigger: Accumulate 100 minutes total across Conversation sessions
        let convSeconds = conversationLogs.reduce(0) { $0 + $1.exerciseDuration }
        let convMinutes = convSeconds / 60
        update(
            id: "nm_007",
            current: min(convMinutes, 100),
            total: 100,
            unit: "minutes"
        )

        // ── nm_008 · Comeback Kid ─────────────────────────────────────────────
        // Trigger: Return to app after a gap of 3 or more consecutive inactive days
        let hasComeback = detectComebackAfterGap(from: allLogs, gapDays: 3)
        awardsManager.updateAwardProgress(
            id: "nm_008",
            progress: hasComeback ? 1.0 : 0.0,
            newStatus: hasComeback ? "Completed" : "0 of 1 completed"
        )

        // ── nm_009 · Fortnight Fighter ────────────────────────────────────────
        // Trigger: Achieve a 14-day streak (5 daily tasks completed per day)
        let streak = computeCurrentStreak(from: dailyTaskLogs, requiredPerDay: 5)
        update(
            id: "nm_009",
            current: min(streak, 14),
            total: 14,
            unit: "days"
        )

        // ── nm_010 · Monthly Master ───────────────────────────────────────────
        // Trigger: Achieve a 30-day streak (5 daily tasks completed per day)
        update(
            id: "nm_010",
            current: min(streak, 30),
            total: 30,
            unit: "days"
        )
    }

    private func evaluateWeeklyAwards() {

        let weekStart = currentWeekMonday()

        // Filter all logs to current week only
        let exerciseLogs     = logManager.getLogs(for: .exercises)    .filter { $0.completionDate >= weekStart }
        let readingLogs      = logManager.getLogs(for: .reading)     .filter { $0.completionDate >= weekStart }
        let conversationLogs = logManager.getLogs(for: .conversation).filter { $0.completionDate >= weekStart }
        let dailyTaskLogs    = logManager.getLogs(for: .dailyTasks)   .filter { $0.completionDate >= weekStart }
        let allWeekLogs      = exerciseLogs + readingLogs + conversationLogs + dailyTaskLogs

        // ── wk_001 · Week Warrior ─────────────────────────────────────────────
        // Trigger: 7-day streak with 5 daily tasks completed per day
        let weekStreak = computeCurrentStreak(from: dailyTaskLogs, requiredPerDay: 5)
        update(
            id: "wk_001",
            current: min(weekStreak, 7),
            total: 7,
            unit: "days"
        )

        // ── wk_002 · Perfect Week ─────────────────────────────────────────────
        // Trigger: All 5 daily tasks completed every day for 7 days this week
        let perfectDays = countDaysMeetingThreshold(from: dailyTaskLogs, requiredCount: 5)
        update(
            id: "wk_002",
            current: min(perfectDays, 7),
            total: 7,
            unit: "days"
        )

        // ── wk_003 · Goal Crusher ─────────────────────────────────────────────
        // Trigger: All 3 daily goals (exercise, reading, conversation) hit in one day
        let goalCrushed = didCrushAllGoalsInOneDay(
            exerciseLogs: exerciseLogs,
            readingLogs: readingLogs,
            conversationLogs: conversationLogs
        )
        awardsManager.updateAwardProgress(
            id: "wk_003",
            progress: goalCrushed ? 1.0 : 0.0,
            newStatus: goalCrushed ? "Completed" : "0 of 1 day"
        )

        // ── wk_004 · Consistent Achiever ─────────────────────────────────────
        // Trigger: All 3 daily goals met for 7 consecutive days this week
        let goalDays = countDaysAllGoalsMet(
            exerciseLogs: exerciseLogs,
            readingLogs: readingLogs,
            conversationLogs: conversationLogs
        )
        update(
            id: "wk_004",
            current: min(goalDays, 7),
            total: 7,
            unit: "days"
        )

        // ── wk_005 · Early Bird ───────────────────────────────────────────────
        // Trigger: All 5 daily tasks completed before 9:00 AM on any single day
        let isEarlyBird = didCompleteTasksBeforeHour(from: dailyTaskLogs, requiredCount: 5, beforeHour: 9)
        awardsManager.updateAwardProgress(
            id: "wk_005",
            progress: isEarlyBird ? 1.0 : 0.0,
            newStatus: isEarlyBird ? "Completed" : "0 of 1 completed"
        )

        // ── wk_006 · Strong Start ─────────────────────────────────────────────
        // Trigger: Completed any session on Monday of the current week
        let strongStart = allWeekLogs.contains {
            Calendar.current.isDate($0.completionDate, inSameDayAs: weekStart) // weekStart is Monday
        }
        awardsManager.updateAwardProgress(
            id: "wk_006",
            progress: strongStart ? 1.0 : 0.0,
            newStatus: strongStart ? "Completed" : "0 of 1 session"
        )

        // ── wk_007 · Calm Week ────────────────────────────────────────────────
        // Trigger: 5 breathing or airflow exercises completed this week.
        let breathingExerciseNames: Set<String> = [
            "Airflow Practice",
            "Flexible Pacing",
            "Gentle Onset",
            "Light Contacts",
            "Prolongation"
        ]
        let calmCount = exerciseLogs.filter { breathingExerciseNames.contains($0.exerciseName) }.count
        update(
            id: "wk_007",
            current: min(calmCount, 5),
            total: 5,
            unit: "sessions"
        )

        // ── wk_008 · Fluency Drive ────────────────────────────────────────────
        // Trigger: 10 exercise sessions completed in a single week
        update(
            id: "wk_008",
            current: min(exerciseLogs.count, 10),
            total: 10,
            unit: "exercises"
        )

        // ── wk_009 · Steady Reader ────────────────────────────────────────────
        // Trigger: Read Aloud session completed on 5 different days this week
        let readingDays = uniqueDayCount(from: readingLogs)
        update(
            id: "wk_009",
            current: min(readingDays, 5),
            total: 5,
            unit: "days"
        )

        // ── wk_010 · Steady Speaker ───────────────────────────────────────────
        // Trigger: Conversation session completed on 5 different days this week
        let convDays = uniqueDayCount(from: conversationLogs)
        update(
            id: "wk_010",
            current: min(convDays, 5),
            total: 5,
            unit: "days"
        )
    }

    private func update(id: String, current: Int, total: Int, unit: String) {
        let progress = Double(current) / Double(total)
        let status   = "\(current) of \(total) \(unit)"
        awardsManager.updateAwardProgress(id: id, progress: progress, newStatus: status)
    }

    private func computeCurrentStreak(from logs: [ExerciseLog], requiredPerDay: Int) -> Int {
        let calendar = Calendar.current

        let grouped = Dictionary(grouping: logs) {
            calendar.startOfDay(for: $0.completionDate)
        }

        let qualifyingDays = grouped
            .filter { $0.value.count >= requiredPerDay }
            .map { $0.key }
            .sorted(by: >)

        guard let mostRecent = qualifyingDays.first else { return 0 }

        let today     = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        guard calendar.isDate(mostRecent, inSameDayAs: today) ||
              calendar.isDate(mostRecent, inSameDayAs: yesterday) else {
            return 0
        }

        var streak      = 0
        var expectedDay = mostRecent

        for day in qualifyingDays {
            if calendar.isDate(day, inSameDayAs: expectedDay) {
                streak += 1
                expectedDay = calendar.date(byAdding: .day, value: -1, to: expectedDay)!
            } else {
                break
            }
        }

        return streak
    }

    private func detectComebackAfterGap(from logs: [ExerciseLog], gapDays: Int) -> Bool {
        let calendar = Calendar.current

        let sortedDays = Set(logs.map { calendar.startOfDay(for: $0.completionDate) })
            .sorted()

        guard sortedDays.count >= 2 else { return false }

        for i in 1..<sortedDays.count {
            let gap = calendar.dateComponents(
                [.day],
                from: sortedDays[i - 1],
                to: sortedDays[i]
            ).day ?? 0
            if gap >= gapDays { return true }
        }
        return false
    }

    private func countDaysMeetingThreshold(from logs: [ExerciseLog], requiredCount: Int) -> Int {
        let calendar = Calendar.current
        let grouped  = Dictionary(grouping: logs) { calendar.startOfDay(for: $0.completionDate) }
        return grouped.filter { $0.value.count >= requiredCount }.count
    }

    private func uniqueDayCount(from logs: [ExerciseLog]) -> Int {
        let calendar = Calendar.current
        return Set(logs.map { calendar.startOfDay(for: $0.completionDate) }).count
    }

    private func didCrushAllGoalsInOneDay(
        exerciseLogs: [ExerciseLog],
        readingLogs: [ExerciseLog],
        conversationLogs: [ExerciseLog]
    ) -> Bool {
        let goalExSec  = logManager.getGoal(name: LogManager.GoalKeys.exercise)     * 60
        let goalRdSec  = logManager.getGoal(name: LogManager.GoalKeys.reading)      * 60
        let goalCvSec  = logManager.getGoal(name: LogManager.GoalKeys.conversation) * 60
        let calendar   = Calendar.current

        let exByDay = Dictionary(grouping: exerciseLogs)     { calendar.startOfDay(for: $0.completionDate) }
        let rdByDay = Dictionary(grouping: readingLogs)      { calendar.startOfDay(for: $0.completionDate) }
        let cvByDay = Dictionary(grouping: conversationLogs) { calendar.startOfDay(for: $0.completionDate) }

        let allDays = Set(exByDay.keys).union(rdByDay.keys).union(cvByDay.keys)

        for day in allDays {
            let exDuration = exByDay[day]?.reduce(0) { $0 + $1.exerciseDuration } ?? 0
            let rdDuration = rdByDay[day]?.reduce(0) { $0 + $1.exerciseDuration } ?? 0
            let cvDuration = cvByDay[day]?.reduce(0) { $0 + $1.exerciseDuration } ?? 0

            if exDuration >= goalExSec && rdDuration >= goalRdSec && cvDuration >= goalCvSec {
                return true
            }
        }
        return false
    }

    private func countDaysAllGoalsMet(
        exerciseLogs: [ExerciseLog],
        readingLogs: [ExerciseLog],
        conversationLogs: [ExerciseLog]
    ) -> Int {
        let goalExSec  = logManager.getGoal(name: LogManager.GoalKeys.exercise)     * 60
        let goalRdSec  = logManager.getGoal(name: LogManager.GoalKeys.reading)      * 60
        let goalCvSec  = logManager.getGoal(name: LogManager.GoalKeys.conversation) * 60
        let calendar   = Calendar.current

        let exByDay = Dictionary(grouping: exerciseLogs)     { calendar.startOfDay(for: $0.completionDate) }
        let rdByDay = Dictionary(grouping: readingLogs)      { calendar.startOfDay(for: $0.completionDate) }
        let cvByDay = Dictionary(grouping: conversationLogs) { calendar.startOfDay(for: $0.completionDate) }

        let allDays = Set(exByDay.keys).union(rdByDay.keys).union(cvByDay.keys)
        var count   = 0

        for day in allDays {
            let exDuration = exByDay[day]?.reduce(0) { $0 + $1.exerciseDuration } ?? 0
            let rdDuration = rdByDay[day]?.reduce(0) { $0 + $1.exerciseDuration } ?? 0
            let cvDuration = cvByDay[day]?.reduce(0) { $0 + $1.exerciseDuration } ?? 0

            if exDuration >= goalExSec && rdDuration >= goalRdSec && cvDuration >= goalCvSec {
                count += 1
            }
        }
        return count
    }

    private func didCompleteTasksBeforeHour(
        from logs: [ExerciseLog],
        requiredCount: Int,
        beforeHour: Int
    ) -> Bool {
        let calendar = Calendar.current
        let grouped  = Dictionary(grouping: logs) { calendar.startOfDay(for: $0.completionDate) }

        for (_, dayLogs) in grouped {
            let earlyLogs = dayLogs.filter {
                calendar.component(.hour, from: $0.completionDate) < beforeHour
            }
            if earlyLogs.count >= requiredCount { return true }
        }
        return false
    }
    
    private func currentWeekMonday() -> Date {
        var calendar        = Calendar.current
        calendar.firstWeekday = 2 // Monday
        let today           = calendar.startOfDay(for: Date())
        var components      = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        components.weekday  = 2
        return calendar.date(from: components) ?? today
    }
}
