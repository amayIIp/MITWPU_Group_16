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


// MARK: - Root Structure
struct ModuleResponse: Codable {
    let moduleName: String
    let exercises: [Exercise1]
    
    enum CodingKeys: String, CodingKey {
        case moduleName = "module_name"
        case exercises
    }
}

// MARK: - Exercise
struct Exercise1: Codable {
    let id: String
    let title: String
    let wordStartStep: Int
    let instructionSet: InstructionSet
    let exampleDemonstration: ExampleDemonstration
    let dataBank: DataBank

    enum CodingKeys: String, CodingKey {
        case id, title
        case wordStartStep = "word_start"
        case instructionSet = "instruction_set"
        case exampleDemonstration = "example_demonstration"
        case dataBank = "data_bank"
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

struct ExampleDemonstration: Codable {
    let targetWord: String
    
    enum CodingKeys: String, CodingKey {
        case targetWord = "target_word"
    }
}

struct DataBank: Codable {
    let description: String
    let targets: [String: [String]]
}

