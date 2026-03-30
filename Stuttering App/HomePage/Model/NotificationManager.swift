//
//  NotificationManager.swift
//  Stuttering App
//

import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
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
    
    func scheduleNotifications() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            
            // 1. Schedule Morning Reminder (Everyday at 9:11 AM)
            self.scheduleMorningReminder()
            
            // 2. Schedule Night Reminders (Everyday at 8:00 PM for next 14 days)
            self.scheduleEveningReminders()
        }
    }
    
    private func scheduleMorningReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Good Morning!"
        content.body = "Don't forget to complete your daily taks today."
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = 9
        dateComponents.minute = 11
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "morning_reminder_daily", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling morning reminder: \(error.localizedDescription)")
            }
        }
    }
    
    private func scheduleEveningReminders() {
        let content = UNMutableNotificationContent()
        content.title = "Daily Task Reminder"
        content.body = "You haven't completed your daily exercises yet. Take a few minutes to do them before the day ends!"
        content.sound = .default
        
        let center = UNUserNotificationCenter.current()
        
        // We ensure to not schedule for today if today's task is already complete.
        // However, a simpler approach is to schedule it and just let `DatabaseManager`
        // cancel it immediately if `isDailyGoalCompleted` is true. But to be safe,
        // we can just schedule them all and then the caller can verify.
        
        // Schedule for the next 14 days
        for dayOffset in 0..<14 {
            guard let targetDate = Calendar.current.date(byAdding: .day, value: dayOffset, to: Date()) else { continue }
            
            var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: targetDate)
            dateComponents.hour = 20 // 8:00 PM
            dateComponents.minute = 0
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            
            let dateString = formatDate(targetDate)
            let identifier = "night_reminder_\(dateString)"
            
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            center.add(request) { error in
                if let error = error {
                    print("Error scheduling night reminder for \(dateString): \(error.localizedDescription)")
                }
            }
        }
    }
    
    func cancelTodayNightReminder() {
        let dateString = formatDate(Date())
        let identifier = "night_reminder_\(dateString)"
        
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        print("Cancelled night reminder for today: \(identifier)")
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy_MM_dd"
        return formatter.string(from: date)
    }
}
