import Foundation
import SQLite3

class LogManager {
    
    static let shared = LogManager()
    
    private var db: OpaquePointer?
    private let dbName = "ExerciseDatabase.sqlite"
    
    struct GoalKeys {
        static let exercise = "Goal_Exercise"
        static let reading = "Goal_Reading"
        static let conversation = "Goal_Conversation"
    }
    
    private init() {
        openDatabase()
        createTables()
        initializeDefaultGoals()
    }
    
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
        
        let createLogTableString = """
        CREATE TABLE IF NOT EXISTS ExerciseLog(
        id TEXT PRIMARY KEY,
        exerciseName TEXT,
        completionDate REAL,
        source TEXT,
        exerciseDuration INTEGER
        );
        """
        execute(sql: createLogTableString, successMessage: "ExerciseLog table ready.")
        
        let createGoalsTableString = """
        CREATE TABLE IF NOT EXISTS Goals(
        goalName TEXT PRIMARY KEY,
        goalValue INTEGER
        );
        """
        execute(sql: createGoalsTableString, successMessage: "Goals table ready.")
    }
    
    private func execute(sql: String, successMessage: String) {
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_DONE {
                print(successMessage)
            }
        } else {
            print("SQL Execution Failed: \(sql)")
        }
        sqlite3_finalize(statement)
    }
    
    private func initializeDefaultGoals() {
        let defaults = [
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
                
                if sqlite3_step(statement) == SQLITE_DONE {
                    print("Initialized default goal: \(name)")
                }
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
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("Updated \(name) to \(value)")
            } else {
                print("Failed to update goal.")
            }
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
    
    func addLog(exerciseName: String, source: ExerciseSource, exerciseDuration: Int) {
        let insertStatementString = "INSERT INTO ExerciseLog (id, exerciseName, completionDate, source, exerciseDuration) VALUES (?, ?, ?, ?, ?);"
        var insertStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertStatementString, -1, &insertStatement, nil) == SQLITE_OK {
            let newId = UUID().uuidString
            let date = Date().timeIntervalSince1970
            let sourceRaw = source.rawValue
            
            sqlite3_bind_text(insertStatement, 1, (newId as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 2, (exerciseName as NSString).utf8String, -1, nil)
            sqlite3_bind_double(insertStatement, 3, date)
            sqlite3_bind_text(insertStatement, 4, (sourceRaw as NSString).utf8String, -1, nil)
            sqlite3_bind_int(insertStatement, 5, Int32(exerciseDuration))
            
            if sqlite3_step(insertStatement) == SQLITE_DONE {
                print("Successfully inserted log.")
            } else {
                print("Could not insert row.")
            }
        }
        sqlite3_finalize(insertStatement)
    }
    
    func getLogs(for source: ExerciseSource, on date: Date? = nil) -> [ExerciseLog] {
        let queryStatementString = "SELECT * FROM ExerciseLog WHERE source = ?;"
        var queryStatement: OpaquePointer?
        var resultLogs: [ExerciseLog] = []
        
        if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
            sqlite3_bind_text(queryStatement, 1, (source.rawValue as NSString).utf8String, -1, nil)
            
            while sqlite3_step(queryStatement) == SQLITE_ROW {
                guard let idCStr = sqlite3_column_text(queryStatement, 0),
                      let nameCStr = sqlite3_column_text(queryStatement, 1),
                      let sourceCStr = sqlite3_column_text(queryStatement, 3)
                else { continue }
                
                let idString = String(cString: idCStr)
                let nameString = String(cString: nameCStr)
                let dateDouble = sqlite3_column_double(queryStatement, 2)
                let sourceString = String(cString: sourceCStr)
                let durationInt = Int(sqlite3_column_int(queryStatement, 4))
                
                if let sourceEnum = ExerciseSource(rawValue: sourceString),
                   let uuid = UUID(uuidString: idString) {
                    let log = ExerciseLog(
                        id: uuid,
                        exerciseName: nameString,
                        completionDate: Date(timeIntervalSince1970: dateDouble),
                        source: sourceEnum,
                        exerciseDuration: durationInt
                    )
                    resultLogs.append(log)
                }
            }
        }
        sqlite3_finalize(queryStatement)
        
        if let targetDate = date {
            return resultLogs.filter { log in
                Calendar.current.isDate(log.completionDate, inSameDayAs: targetDate)
            }
        }
        
        return resultLogs
    }
}

