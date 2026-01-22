//
//  TextInputViewController.swift
//  Stuttering App
//
//  Created by sdc - user on 27/11/25.
//

import UIKit

class TextInputViewController: UIViewController {
    var onEmptyInput: (() -> Void)?

    @IBOutlet weak var textDisplay: UITextView!
    
    var onDoneButtonTapped: ((String) -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.title = "Custom Text"
        
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
                self.onEmptyInput?()
            }
        }
    }
}
