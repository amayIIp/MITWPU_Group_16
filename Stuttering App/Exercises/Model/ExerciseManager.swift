//
//  ExerciseManager.swift
//  Stuttering App 1
//
//  Created by SDC-USER on 16/12/25.
//

import Foundation

class ExerciseManager {
    
    private static let fileName = "ExerciseData"
    
    static func fetchExercise(title: String) -> LibraryExercises? {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            print("Manager Error: Could not find \(fileName).json in bundle.")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let library = try decoder.decode(LibraryResponse.self, from: data)
            let allExercises = library.modules.flatMap { $0.exercises }
            
            guard let match = allExercises.first(where: { $0.title == title }) else {
                print("Manager Error: Exercise '\(title)' not found in data.")
                return nil
            }
            return match
            
        } catch {
            print("Manager Error: Failed to parse JSON - \(error)")
            return nil
        }
    }
}
