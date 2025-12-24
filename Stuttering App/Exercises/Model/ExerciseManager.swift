//
//  ExerciseManager.swift
//  Stuttering App 1
//
//  Created by SDC-USER on 16/12/25.
//

import Foundation

class ExerciseManager {
    
    // The name of your JSON file in the project (e.g., exercises.json)
    private static let fileName = "foundation"
    
    /// Fetches a specific exercise by ID from the local JSON file
    static func fetchExercise(id: String) -> Exercise1? {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            print("Manager Error: Could not find \(fileName).json in bundle.")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let response = try decoder.decode(ModuleResponse.self, from: data)
            
            // Find the specific exercise
            return response.exercises.first(where: { $0.id == id })
            
        } catch {
            print("Manager Error: Failed to parse JSON - \(error)")
            return nil
        }
    }
}
