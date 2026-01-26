//
//  RadialProgressView.swift
//  Stutterr
//
//  Created by Prathamesh Patil on 04/10/25.
//

import Foundation
import UIKit

class RadialProgressView: UIView {
    
    var chartData: [RadialData] = [] {
        didSet {
            // Tells the system the view needs to be redrawn (calls draw(_:))
            setNeedsDisplay()
        }
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        let center = CGPoint(x: rect.midX, y: rect.midY)
        // Start angle at the top (12 o'clock position)
        let startAngle: CGFloat = 3 * .pi / 2

        // Draw the static background rings (faint gray)
        drawBackgroundRings(center: center, startAngle: startAngle)

        // Draw the progress rings (color arcs)
        drawProgressRings(center: center, startAngle: startAngle)
    }

    private func drawBackgroundRings(center: CGPoint, startAngle: CGFloat) {
        let backgroundColor = UIColor(red: 0.923, green: 0.948, blue: 0.977, alpha: 1.0)
        
        for ring in chartData {
            let fullCircle: CGFloat = 2 * .pi // Full circle
            
            let path = UIBezierPath(
                arcCenter: center,
                radius: ring.radius,
                startAngle: startAngle,
                endAngle: startAngle + fullCircle,
                clockwise: true
            )
            
            path.lineWidth = ring.lineWidth
            path.lineCapStyle = .butt // Flat ends for background
            backgroundColor.setStroke()
            path.stroke()
        }
    }
    
    private func drawProgressRings(center: CGPoint, startAngle: CGFloat) {
        // Draw the innermost ring first so outer rings are not obscured
        let sortedData = chartData.sorted { $0.order > $1.order }

        for ring in sortedData {
            // Calculate the end angle based on the progress percentage
            let endAngle = startAngle + (ring.progress * 2 * .pi)

            let path = UIBezierPath(
                arcCenter: center,
                radius: ring.radius,
                startAngle: startAngle,
                endAngle: endAngle,
                clockwise: true
            )
            
            // Apply styling
            path.lineWidth = ring.lineWidth
            path.lineCapStyle = .round // Gives the rounded ends
            ring.color.setStroke()
            
            // Draw the arc
            path.stroke()
        }
    }
    
    // MARK: - Percentage Update Function
    
    /**
     Updates the progress of a specific radial arc and redraws the chart.
     - Parameters:
        - title: The name of the task to update (e.g., "Exercises").
        - percentage: The new progress value (0.0 to 1.0).
     */
    func updateProgress(for title: String, to percentage: CGFloat) {
        guard let index = chartData.firstIndex(where: { $0.title == title }) else {
            print("Error: Task '\(title)' not found.")
            return
        }
        
        // Update the progress value
        chartData[index].progress = min(max(percentage, 0.0), 1.0) // Clamp between 0 and 1
        
        // The didSet on chartData will automatically call setNeedsDisplay()
    }
}
