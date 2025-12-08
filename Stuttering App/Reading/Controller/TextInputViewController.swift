//
//  TextInputViewController.swift
//  Stuttering App
//
//  Created by sdc - user on 27/11/25.
//

import UIKit

class TextInputViewController: UIViewController {
    var onEmptyInput: (() -> Void)?

    
    @IBOutlet weak var textViewView: UIView!
    @IBOutlet weak var textDisplayView: UIView!
    @IBOutlet weak var textDisplay: UITextView!
    
    var onDoneButtonTapped: ((String) -> Void)? // This closure will pass the text *back* to the TableViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        textDisplay.layer.cornerRadius = 16.0
        textDisplay.layer.masksToBounds = true
        view.backgroundColor = UIColor(named: "bg")
        textViewView.backgroundColor = UIColor(named: "bg")
        textDisplayView.backgroundColor = UIColor(named: "bg")
        
        
        self.navigationItem.title = "Enter Custom Text"
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "xmark"), style: .plain, target: self, action: #selector(didTapClose))
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "checkmark"), style: .prominent, target: self, action: #selector(didTapDone))
        
        textDisplay.becomeFirstResponder() // Automatically show the keyboard
    }
    
    @objc func didTapClose() {
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc func didTapDone() {
        
        self.dismiss(animated: true) {
            if let text = self.textDisplay.text?.trimmingCharacters(in: .whitespacesAndNewlines),
               !text.isEmpty {
                
                self.onDoneButtonTapped?(text)
                
            } else {
                // Show an alert for empty input
                self.onEmptyInput?()   // ← tell PARENT to show the alert
            }
        }
        
    }
}
