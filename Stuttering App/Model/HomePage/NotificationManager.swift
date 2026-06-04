//
//  NotificationManager.swift
//  Stuttering App
//

import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    // MARK: - Authorization

    /// Request notification permission. Only call this AFTER the user has completed
    /// onboarding (guest or email). Schedules all recurring notifications if granted.
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error.localizedDescription)")
            } else if granted {
                print("Notification permission granted.")
                self.scheduleNotifications()
            } else {
                print("Notification permission denied.")
            }
        }
    }

    // MARK: - Schedule All

    func scheduleNotifications() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }

            // 1. Morning reminder (daily at 9:00 AM) — complete your daily tasks
            self.scheduleMorningReminder()

            // 2. Evening reminder (daily at 8:00 PM) — for incomplete daily TASKS
            self.scheduleEveningTaskReminders()

            // 3. Evening reminder (daily at 8:30 PM) — for incomplete daily GOAL (progress bars)
            self.scheduleEveningGoalReminders()
        }
    }

    // MARK: - Morning Reminder

    private func scheduleMorningReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Good Morning! 🌅"
        content.body = "Don't forget to complete your daily tasks today. Keep the streak alive!"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = 9
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "morning_reminder_daily", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling morning reminder: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Evening Daily Task Reminders (8:00 PM)

    /// Schedules reminders for the next 14 days at 8:00 PM if daily TASKS are not completed.
    private func scheduleEveningTaskReminders() {
        let content = UNMutableNotificationContent()
        content.title = "Daily Task Reminder ✅"
        content.body = "You haven't completed your daily exercises yet. Take a few minutes to do them before the day ends!"
        content.sound = .default

        let center = UNUserNotificationCenter.current()

        for dayOffset in 0..<14 {
            guard let targetDate = Calendar.current.date(byAdding: .day, value: dayOffset, to: Date()) else { continue }

            var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: targetDate)
            dateComponents.hour = 20 // 8:00 PM
            dateComponents.minute = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

            let dateString = formatDate(targetDate)
            let identifier = "night_task_reminder_\(dateString)"

            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            center.add(request) { error in
                if let error = error {
                    print("Error scheduling evening task reminder for \(dateString): \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Evening Daily Goal Reminders (8:30 PM)

    /// Schedules reminders for the next 14 days at 8:30 PM if daily GOAL (progress bars) are not completed.
    private func scheduleEveningGoalReminders() {
        let content = UNMutableNotificationContent()
        content.title = "Daily Goal Progress 🎯"
        content.body = "Your daily goal isn't complete yet! Finish your exercise, reading, or conversation session before midnight."
        content.sound = .default

        let center = UNUserNotificationCenter.current()

        for dayOffset in 0..<14 {
            guard let targetDate = Calendar.current.date(byAdding: .day, value: dayOffset, to: Date()) else { continue }

            var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: targetDate)
            dateComponents.hour = 20 // 8:30 PM
            dateComponents.minute = 30

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

            let dateString = formatDate(targetDate)
            let identifier = "night_goal_reminder_\(dateString)"

            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            center.add(request) { error in
                if let error = error {
                    print("Error scheduling evening goal reminder for \(dateString): \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Cancel Today's Reminders

    /// Call this when the user completes all daily TASKS today.
    func cancelTodayNightReminder() {
        let dateString = formatDate(Date())
        let taskIdentifier = "night_task_reminder_\(dateString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [taskIdentifier])
        print("Cancelled evening task reminder for today: \(taskIdentifier)")
    }

    /// Call this when the user completes their daily GOAL (all 3 progress bars hit) today.
    func cancelTodayGoalReminder() {
        let dateString = formatDate(Date())
        let goalIdentifier = "night_goal_reminder_\(dateString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [goalIdentifier])
        print("Cancelled evening goal reminder for today: \(goalIdentifier)")
    }

    // MARK: - Award Proximity Notification

    /// Fires an immediate local notification when an award is >= 95% complete but not yet earned.
    /// - Parameters:
    ///   - awardName: The display name of the award.
    ///   - progress: A value between 0.0 and 1.0 representing completion.
    func scheduleAwardProximityNotification(for awardName: String, progress: Double) {
        guard progress >= 0.95 && progress < 1.0 else { return }

        let percentInt = Int(progress * 100)

        let content = UNMutableNotificationContent()
        content.title = "You're SO close! 🏆"
        content.body = "You're \(percentInt)% of the way to earning the \"\(awardName)\" award. Just a little more!"
        content.sound = .default

        // Deliver immediately (1-second delay so it fires after the app goes to background)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        // Use a stable identifier so we don't spam — one per award
        let safeId = awardName.lowercased().replacingOccurrences(of: " ", with: "_")
        let identifier = "award_proximity_\(safeId)"

        // Check if this notification was already sent for this award; avoid duplicate spam
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let alreadyPending = requests.contains { $0.identifier == identifier }
            guard !alreadyPending else {
                print("Award proximity notification already pending for: \(awardName)")
                return
            }

            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error scheduling award proximity notification: \(error.localizedDescription)")
                } else {
                    print("🏆 Award proximity notification scheduled for: \(awardName) at \(percentInt)%")
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy_MM_dd"
        return formatter.string(from: date)
    }
}
