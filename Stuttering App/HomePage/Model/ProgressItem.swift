//
//  ProgressItem.swift
//  Spasht
//
//  Created by Prathamesh Patil on 16/11/25.
//

import Foundation
import UIKit

struct ProgressItem {
    let progress: CGFloat
    let color: UIColor
    
    init(progress: CGFloat, color: UIColor) {
        self.progress = max(0.0, min(1.0, progress))
        self.color = color
    }
}

extension ProgressItem {
    static func sampleData() -> [ProgressItem] {
        return [
            ProgressItem(progress: 0.75, color: UIColor(red: 0.4, green: 0.71, blue: 0.84, alpha: 1.0)),
            ProgressItem(progress: 0.35, color: UIColor(red: 0.95, green: 0.77, blue: 0.24, alpha: 1.0)),
            ProgressItem(progress: 0.90, color: UIColor(red: 0.95, green: 0.55, blue: 0.15, alpha: 1.0))
        ]
    }
}
