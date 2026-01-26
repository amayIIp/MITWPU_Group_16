//
//  Awards.swift
//  Stuttering App 1
//
//  Created by Prathamesh Patil on 15/12/25.
//

import Foundation

struct AwardData: Codable {
    let groups: [AwardGroup]
}

struct AwardGroup: Codable {
    let type: String
    let awards: [AwardItem]
}

struct AwardItem: Codable {
    let id: String
    let name: String
    let description: String
    let status: String
}

struct AwardModel {
    let id: String
    let name: String
    let description: String
    let status: String
    let progress: Double
    let completionDate: Date?
    let groupType: String
    var isCompleted: Bool {
        return progress >= 1.0
    }
}
