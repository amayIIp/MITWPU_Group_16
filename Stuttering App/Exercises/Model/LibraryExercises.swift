//
//  Exercise1.swift
//  Stuttering App 1
//
//  Created by Prathamesh Patil on 15/12/25.
//

import Foundation

struct SentenceData: Codable {
    let sentence: String
    let word: String
}

struct LibraryResponse: Codable {
    let modules: [ModuleResponse]
}

struct ModuleResponse: Codable {
    let moduleName: String
    let description: String
    let moduleId: String
    let exercises: [LibraryExercises]
    
    enum CodingKeys: String, CodingKey {
        case moduleName = "module_name"
        case description
        case moduleId = "module_id"
        case exercises
    }
}

struct LibraryExercises: Codable {
    let id: String
    let title: String
    let category: String
    let difficulty: String
    let wordStartStep: Int
    let instructionSet: InstructionSet
    let exampleDemonstration: [ExampleDemonstration]
    let dataBank: DataBank

    enum CodingKeys: String, CodingKey {
        case id, title, category, difficulty
        case wordStartStep = "word_start"
        case instructionSet = "instruction_set"
        case exampleDemonstration = "example_demonstration"
        case dataBank = "data_bank"
    }
}

struct ExampleDemonstration: Codable {
    let targetSound: String?
    let targetWord: String?
    let executionText: String?
    
    var displayText: String {
        return targetSound ?? targetWord ?? "Example"
    }

    enum CodingKeys: String, CodingKey {
        case targetSound = "target_sound"
        case targetWord = "target_word"
        case executionText = "execution_text"
    }
}

struct InstructionSet: Codable {
    let steps: [ExerciseStep]
}

struct ExerciseStep: Codable {
    let stepNumber: Int
    let label: String
    let text: String
    let image: String
    let time: Int
    
    enum CodingKeys: String, CodingKey {
        case stepNumber = "step_number"
        case label, text, image, time
    }
}

struct DataBank: Codable {
    let description: String
    let targets: [String: [String]]
}
