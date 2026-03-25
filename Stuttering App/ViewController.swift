//
//  ViewController.swift
//  Stuttering App 1
//
//  Created by Prathamesh Patil on 09/12/25.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet weak var waveformView: BarWaveformView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        updateUI()
    }
    
    func updateUI() {
        // Simulated data matching the peaks and valleys of a voice recording
        let sampleData: [CGFloat] = [0.1, 0.4, 0.8, 0.3, 0.9, 0.5, 0.2]
        waveformView.amplitudes = sampleData
    }


}

