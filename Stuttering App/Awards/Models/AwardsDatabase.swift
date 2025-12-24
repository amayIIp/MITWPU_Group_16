//
//  AwardsDatabase.swift
//  Stuttering App 1
//
//  Created by Prathamesh Patil on 15/12/25.
//

import Foundation
import SQLite3

class AwardsManager {
    static let shared = AwardsManager()
    var db: OpaquePointer?
    
    func openDatabase() {
        let fileUrl = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent("AwardsDB.sqlite")
        
        print("Database Path: \(fileUrl.path)")
        if sqlite3_open(fileUrl.path, &db) != SQLITE_OK {
            print("Error opening database")
            return
        }
        
        let createTableQuery = "CREATE TABLE IF NOT EXISTS Awards (id TEXT PRIMARY KEY, name TEXT, progress DOUBLE, completionDate DOUBLE, groupType TEXT, description TEXT, status TEXT)"
        
        if sqlite3_exec(db, createTableQuery, nil, nil, nil) != SQLITE_OK {
            print("Error creating table")
        }
    }
    
    func fetchAwards(query: String) -> [AwardModel] {
        var result: [AwardModel] = []
        var stmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(stmt, 0))
                let name = String(cString: sqlite3_column_text(stmt, 1))
                let progress = sqlite3_column_double(stmt, 2)
                let dateDouble = sqlite3_column_double(stmt, 3)
                let group = String(cString: sqlite3_column_text(stmt, 4))
                let descText = sqlite3_column_text(stmt, 5)
                let description = descText != nil ? String(cString: descText!) : ""
                let statusText = sqlite3_column_text(stmt, 6)
                let status = statusText != nil ? String(cString: statusText!) : ""
                let date = dateDouble > 0 ? Date(timeIntervalSince1970: dateDouble) : nil
                
                result.append(AwardModel(id: id, name: name, description: description, status: status, progress: progress, completionDate: date, groupType: group))
            }
        }
        sqlite3_finalize(stmt)
        return result
    }
}

extension AwardsManager {
    
    func seedDatabaseIfNeeded() {
        if getAwardsCount() > 0 {
            print("Database already seeded. Skipping.")
            return
        }
        
        print("Database empty. Starting seed process...")
        
        guard let url = Bundle.main.url(forResource: "Awards", withExtension: "json") else {
            print("Error: Awards.json file not found in bundle.")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decodedData = try JSONDecoder().decode(AwardData.self, from: data)
            
            for group in decodedData.groups {
                for award in group.awards {
                    insertInitialAward(award, groupType: group.type)
                }
            }
            print("Database successfully seeded.")
            
        } catch {
            print("Error parsing JSON: \(error)")
        }
    }
    
    private func getAwardsCount() -> Int {
        var count = 0
        let query = "SELECT COUNT(*) FROM Awards"
        var stmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                count = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        return count
    }
    
    private func insertInitialAward(_ item: AwardItem, groupType: String) {
        let insertQuery = "INSERT INTO Awards (id, name, progress, completionDate, groupType, description, status) VALUES (?, ?, ?, ?, ?, ?, ?)"
        var stmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertQuery, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (item.id as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (item.name as NSString).utf8String, -1, nil)
            sqlite3_bind_double(stmt, 3, 0.0) // Progress
            sqlite3_bind_double(stmt, 4, 0.0) // Date
            sqlite3_bind_text(stmt, 5, (groupType as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 6, (item.description as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 7, (item.status as NSString).utf8String, -1, nil)
            
            if sqlite3_step(stmt) != SQLITE_DONE {
                print("Error inserting award: \(item.name)")
            }
        }
        sqlite3_finalize(stmt)
    }

    func updateAwardProgress(id: String, progress: Double, newStatus: String) {
        
        let query = "UPDATE Awards SET progress = ?, completionDate = ?, status = ? WHERE id = ?"
        var stmt: OpaquePointer?
        
        let clampedProgress = min(max(progress, 0.0), 1.0)
        let completionDate = (clampedProgress >= 1.0) ? Date().timeIntervalSince1970 : 0.0
        
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_double(stmt, 1, clampedProgress)
            sqlite3_bind_double(stmt, 2, completionDate)
            sqlite3_bind_text(stmt, 3, (newStatus as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 4, (id as NSString).utf8String, -1, nil)
            
            if sqlite3_step(stmt) == SQLITE_DONE {
                print("Updated award \(id): \(newStatus)")
            } else {
                print("Failed to update award: \(id)")
            }
        }
        sqlite3_finalize(stmt)
    }
    
    func completeAward(id: String) {
        updateAwardProgress(id: id, progress: 1.0, newStatus: "Completed")
    }
}


extension AwardsManager {
    
    func getTopWeeklyChallenge() -> AwardModel? {
        var stmt: OpaquePointer?
        var result: AwardModel?
        
        let completedQuery = "SELECT * FROM Awards WHERE groupType = 'weekly' AND progress >= 1.0 ORDER BY completionDate DESC LIMIT 1"
        if sqlite3_prepare_v2(db, completedQuery, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                result = parseAwardFromStatement(stmt)
            }
        }
        sqlite3_finalize(stmt)
        
        if result != nil { return result }
        let fallbackQuery = "SELECT * FROM Awards WHERE groupType = 'weekly' AND progress < 1.0 ORDER BY progress DESC LIMIT 1"
        if sqlite3_prepare_v2(db, fallbackQuery, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                result = parseAwardFromStatement(stmt)
            }
        }
        sqlite3_finalize(stmt)
        
        return result
    }
    
    // Helper to avoid repeating column parsing logic
    private func parseAwardFromStatement(_ stmt: OpaquePointer?) -> AwardModel {
        let id = String(cString: sqlite3_column_text(stmt, 0))
        let name = String(cString: sqlite3_column_text(stmt, 1))
        let progress = sqlite3_column_double(stmt, 2)
        let dateDouble = sqlite3_column_double(stmt, 3)
        let group = String(cString: sqlite3_column_text(stmt, 4))
        
        let descText = sqlite3_column_text(stmt, 5)
        let description = descText != nil ? String(cString: descText!) : ""
        
        let statusText = sqlite3_column_text(stmt, 6)
        let status = statusText != nil ? String(cString: statusText!) : ""
        
        let date = dateDouble > 0 ? Date(timeIntervalSince1970: dateDouble) : nil
        
        return AwardModel(
            id: id,
            name: name,
            description: description,
            status: status,
            progress: progress,
            completionDate: date,
            groupType: group
        )
    }
    
    func getTopAchievedAward() -> AwardModel? {
        var stmt: OpaquePointer?
        var result: AwardModel?
        
        let query = "SELECT * FROM Awards WHERE progress >= 1.0 ORDER BY completionDate DESC LIMIT 1"
        
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                result = parseAwardFromStatement(stmt)
            }
        }
        sqlite3_finalize(stmt)
        return result
    }
    
    func getTopLockedAward() -> AwardModel? {
        var stmt: OpaquePointer?
        var result: AwardModel?
        
        let query = "SELECT * FROM Awards WHERE groupType = 'normal' AND progress < 1.0 ORDER BY progress DESC LIMIT 1"
        
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                result = parseAwardFromStatement(stmt)
            }
        }
        sqlite3_finalize(stmt)
        
        if result == nil {
            let fallbackQuery = "SELECT * FROM Awards WHERE groupType = 'normal' AND progress < 1.0 ORDER BY id ASC LIMIT 1"
            if sqlite3_prepare_v2(db, fallbackQuery, -1, &stmt, nil) == SQLITE_OK {
                if sqlite3_step(stmt) == SQLITE_ROW {
                    result = parseAwardFromStatement(stmt)
                }
            }
            sqlite3_finalize(stmt)
        }
        
        return result
    }
}
