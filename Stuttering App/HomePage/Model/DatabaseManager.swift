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
    var db: OpaquePointer?

    private init() {
        openDatabase()
        createTables()
        populateInitialJourney()
    }

    func openDatabase() {
        let fileUrl = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent("Spasht.sqlite")
        print("| Database URL: \(fileUrl.path)")
        if sqlite3_open(fileUrl.path, &db) != SQLITE_OK {
            print("Error opening database")
        }
    }

    func createTables() {
        let createJourney = "CREATE TABLE IF NOT EXISTS Journey (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, isCompleted INTEGER DEFAULT 0)"
        
        let createDaily = "CREATE TABLE IF NOT EXISTS DailyTasks (id INTEGER PRIMARY KEY, name TEXT, description TEXT, duration INTEGER, isCompleted INTEGER DEFAULT 0)"

        sqlite3_exec(db, createJourney, nil, nil, nil)
        sqlite3_exec(db, createDaily, nil, nil, nil)
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
            print("Database: Journey table empty. Populating initial sequence...")
            let exercises = [
                "Airflow Practice", "Gentle Onset", "Flexible Pacing", "Light Contacts", "Prolongation", "Preparatory Set", "Block Correction", "Prolongation", "Flexible Pacing", "Light Contacts", "Preparatory Set", "Pull-Out", "Block Correction", "Airflow Practice", "Gentle Onset", "Flexible Pacing", "Light Contacts", "Prolongation", "Preparatory Set", "Block Correction", "Prolongation", "Flexible Pacing", "Light Contacts", "Preparatory Set", "Pull-Out", "Block Correction"
            ]
            
            let insertQuery = "INSERT INTO Journey (name, isCompleted) VALUES (?, 0)"
            var insertStmt: OpaquePointer?
            
            if sqlite3_prepare_v2(db, insertQuery, -1, &insertStmt, nil) == SQLITE_OK {
                for name in exercises {
                    sqlite3_bind_text(insertStmt, 1, (name as NSString).utf8String, -1, nil)
                    if sqlite3_step(insertStmt) != SQLITE_DONE {
                        print("Error inserting \(name)")
                    }
                    sqlite3_reset(insertStmt)
                }
            }
            sqlite3_finalize(insertStmt)
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
            sqlite3_bind_text(statement, 2, (name as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 3, (desc as NSString).utf8String, -1, nil)
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
    
    func markTaskComplete(taskName: String) {
        let updateDaily = "UPDATE DailyTasks SET isCompleted = 1 WHERE name = ?"
        let updateJourney = "UPDATE Journey SET isCompleted = 1 WHERE name = ?"
        
        executeNameUpdate(query: updateDaily, name: taskName)
        executeNameUpdate(query: updateJourney, name: taskName)
        
        NotificationCenter.default.post(name: NSNotification.Name("dailyTasksUpdated"), object: nil)
    }
    
    private func executeNameUpdate(query: String, name: String) {
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (name as NSString).utf8String, -1, nil)
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
    }
}
