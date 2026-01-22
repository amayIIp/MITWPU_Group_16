//
//  ExerciseDataManager.swift
//
//  Created by Prathamesh Patil on 15/11/25.
//

import Foundation

class ExerciseDataManager {
    
    static let shared = ExerciseDataManager()
    
    private var durationLookup: [String: Int] = [:]
    
    private init() {
        loadExerciseData(from: "exerciselogs")
    }

    func getDurationString(for exerciseName: String) -> Int? {
        return durationLookup[exerciseName]
    }
    
    private func loadExerciseData(from filename: String) {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else {
            print("Error: \(filename).json file not found in bundle.")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            
            let rootData = try decoder.decode(LibraryData.self, from: data)
            
            for section in rootData.sections {
                for group in section.groups {
                    for exercise in group.exercises {
                        durationLookup[exercise.name] = exercise.short_time
                    }
                }
            }
        } catch {
            print("Error parsing \(filename).json: \(error)")
        }
    }
}


