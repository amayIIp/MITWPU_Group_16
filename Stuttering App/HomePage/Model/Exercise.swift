//
//  Exercise.swift
//  Spasht
//
//  Created by Prathamesh Patil on 14/11/25.
//

import Foundation
import UIKit

struct LibraryData: Codable {
    let sections: [LibrarySection]
}

struct LibrarySection: Codable {
    let id: String
    let name: String
    let groups: [ExerciseGroup]
}

struct ExerciseGroup: Codable {
    let id: String
    let name: String
    let description: String
    let exercises: [Exercise]
}

struct Exercise: Codable {
    let id: String
    let name: String
    let description: String
    let short_time: Int
}

enum ExerciseSource: String, Codable {
    case dailyTasks
    case exercises
    case warmup
    case reading
    case conversation
}

struct ExerciseLog: Codable {
    var id: UUID = UUID()
    let exerciseName: String
    let completionDate: Date
    let source: ExerciseSource
    let exerciseDuration: Int
}

struct DailyTask {
    let id: Int
    let name: String
    let description: String
    let duration: Int 
    var isCompleted: Bool
}

protocol ExerciseStarting: UIViewController {
    var startingSource: ExerciseSource? { get set }
    var exerciseName: String { get set }
}
