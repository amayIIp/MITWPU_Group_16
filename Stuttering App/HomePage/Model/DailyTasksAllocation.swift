//
//  LogicMaker.swift
//  Spasht
//
//  Created by SDC-USER on 11/12/25.
//

import Foundation

class LogicMaker {
    
    private let kLastRefreshDate = "lastDailyTaskRefreshDate"
     
    func checkForNewDay(isFromLogin: Bool = false) {
        let defaults = UserDefaults.standard
        let calendar = Calendar.current
        
        let lastDate = defaults.object(forKey: kLastRefreshDate) as? Date ?? Date.distantPast
        if !calendar.isDateInToday(lastDate) {
            print("LogicMaker: New Day Detected. Resetting tasks...")
            resetDailyTasks(isFromLogin: isFromLogin)
            defaults.set(Date(), forKey: kLastRefreshDate)
        } else {
            print("LogicMaker: Same day. No reset needed.")
        }
    }
    
    func resetDailyTasks(isFromLogin: Bool = false) {
        let db = DatabaseManager.shared
        let nextExercises = db.fetchNextFiveFromJourney()
        
        if nextExercises.isEmpty {
            print("Journey complete! No more exercises.")
            return
        }
    
        guard let url = Bundle.main.url(forResource: "exerciselogs", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let root = try? JSONDecoder().decode(LibraryData.self, from: data) else {
            print("Error: Could not load JSON data")
            return
        }
        
        let allDetails = root.sections.flatMap { $0.groups.flatMap { $0.exercises } }
        
        db.clearDailyTasks()
        
        for (index, name) in nextExercises.enumerated() {
            
            let details = allDetails.first(where: { $0.name == name })
            let description = details?.description ?? "Exercise details loading..."
            let duration = details?.short_time ?? 60
            let id = index + 1
            
            db.insertDailyTask(
                id: id,
                name: name,
                desc: description,
                duration: duration
            )
            
            SupabaseSyncManager.shared.pushDailyTaskUpdate(
                id: id, 
                name: name, 
                description: description, 
                duration: duration, 
                isCompleted: false
            )
        }
        
        print("Daily Tasks Reset Successfully.")
        NotificationCenter.default.post(name: NSNotification.Name("dailyTasksUpdated"), object: nil)
    }
}
