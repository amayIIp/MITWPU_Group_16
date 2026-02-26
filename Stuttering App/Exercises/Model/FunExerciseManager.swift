//
//  FunExerciseManager.swift
//  camtest
//
//  Created by SDC-USER on 13/02/26.
//

import Foundation

// 1. The Data Model
struct VideoLog: Codable {
    let id: String          // The UUID of the .mov file
    let heading: String
    let date: Date
    let duration: Double    // Kept as double for precise math, formatted later
}

// 2. The Storage Manager
class MetadataManager {
    static let shared = MetadataManager()
    
    private var fileURL: URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsURL.appendingPathComponent("video_logs_metadata.json")
    }
    
    // Fetch all saved logs
    func loadLogs() -> [VideoLog] {
        guard let data = try? Data(contentsOf: fileURL),
              let logs = try? JSONDecoder().decode([VideoLog].self, from: data) else {
            return []
        }
        // Sort newest first
        return logs.sorted { $0.date > $1.date }
    }
    
    // Save a new log
    func saveLog(_ log: VideoLog) {
        var currentLogs = loadLogs()
        currentLogs.append(log)
        saveContext(logs: currentLogs)
    }
    
    // Delete a log
    func deleteLog(id: String) {
        var currentLogs = loadLogs()
        currentLogs.removeAll { $0.id == id }
        saveContext(logs: currentLogs)
    }
    
    private func saveContext(logs: [VideoLog]) {
        if let data = try? JSONEncoder().encode(logs) {
            try? data.write(to: fileURL)
        }
    }
}

struct AudioLog: Codable {
    let id: String
    let heading: String
    let date: Date
    let duration: Double
}

class AudioMetadataManager {
    static let shared = AudioMetadataManager()
    
    private var fileURL: URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        // Save to a distinct JSON file
        return documentsURL.appendingPathComponent("audio_logs_metadata.json")
    }
    
    func loadLogs() -> [AudioLog] {
        guard let data = try? Data(contentsOf: fileURL),
              let logs = try? JSONDecoder().decode([AudioLog].self, from: data) else {
            return []
        }
        return logs.sorted { $0.date > $1.date }
    }
    
    func saveLog(_ log: AudioLog) {
        var currentLogs = loadLogs()
        currentLogs.append(log)
        saveContext(logs: currentLogs)
    }
    
    func deleteLog(id: String) {
        var currentLogs = loadLogs()
        currentLogs.removeAll { $0.id == id }
        saveContext(logs: currentLogs)
    }
    
    private func saveContext(logs: [AudioLog]) {
        if let data = try? JSONEncoder().encode(logs) {
            try? data.write(to: fileURL)
        }
    }
}
