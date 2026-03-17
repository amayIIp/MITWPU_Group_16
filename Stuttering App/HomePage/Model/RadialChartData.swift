//
//  RadialChartData.swift
//  Stutterr
//
//  Created by Prathamesh Patil on 04/10/25.
//

import Foundation
import UIKit

struct RadialData {
    let title: String
    let color: UIColor
    var progress: CGFloat
    let radius: CGFloat
    let lineWidth: CGFloat
    let order: Int
}

var initialChartData: [RadialData] = [
    RadialData(title: "Daily Tasks", color: UIColor(red: 0.28, green: 0.35, blue: 0.63, alpha: 1.0), progress: 0.75, radius: 60, lineWidth: 20, order: 0)
]

var initialChartData1: [RadialData] = [
    RadialData(title: "Daily Tasks", color: UIColor(red: 0.28, green: 0.35, blue: 0.63, alpha: 1.0), progress: 0.75, radius: 90, lineWidth: 30, order: 0)
]

