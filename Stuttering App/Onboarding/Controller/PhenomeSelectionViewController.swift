//
//  PhenomeSelectViewController.swift
//  Spasht
//
//  Created by Prathamesh Patil on 16/11/25.
//

import UIKit

class PhonemesSelectionViewController: UIViewController {
    
    @IBOutlet weak var phonemeB: UIButton!
    @IBOutlet weak var phonemeP: UIButton!
    @IBOutlet weak var phonemeK: UIButton!
    @IBOutlet weak var phonemeG: UIButton!
    @IBOutlet weak var phonemeT: UIButton!
    @IBOutlet weak var phonemeD: UIButton!
    @IBOutlet weak var phonemeS: UIButton!
    @IBOutlet weak var phonemeSH: UIButton!
    @IBOutlet weak var phonemeF: UIButton!
    @IBOutlet weak var phonemeV: UIButton!
    @IBOutlet weak var phonemeR: UIButton!
    @IBOutlet weak var phonemeL: UIButton!
    @IBOutlet weak var noneButton: UIButton!
    @IBOutlet weak var notSureButton: UIButton!
    @IBOutlet weak var continueButton: UIButton!
    
    var selectedPhonemes: [String] = []
    var phonemeButtons: [UIButton] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupButtons()
    }
    
    func setupButtons() {
        phonemeButtons = [phonemeB, phonemeP, phonemeK, phonemeG, phonemeT, phonemeD,
                         phonemeS, phonemeSH, phonemeF, phonemeV, phonemeR, phonemeL]
    }

    @IBAction func phonemeButtonTapped(_ sender: UIButton) {
        noneButton.isSelected = false
        noneButton.backgroundColor = .white
        notSureButton.isSelected = false
        notSureButton.backgroundColor = .white
        
        sender.isSelected.toggle()
        sender.backgroundColor = sender.isSelected ? .systemBlue : .white
        
        if let title = sender.currentTitle {
            if sender.isSelected {
                sender.setTitleColor(.white, for: .normal)
                if !selectedPhonemes.contains(title) {
                    selectedPhonemes.append(title)
                }
            } else {
                selectedPhonemes.removeAll { $0 == title }
            }
        }
    }
    
    @IBAction func noneButtonTapped(_ sender: UIButton) {
        clearAllSelections()
        sender.isSelected = true
        sender.setTitleColor(.white, for: .normal)
        sender.backgroundColor = .systemBlue
        selectedPhonemes = ["None of these"]
    }
    
    @IBAction func notSureButtonTapped(_ sender: UIButton) {
        clearAllSelections()
        sender.isSelected = true
        sender.setTitleColor(.white, for: .normal)
        sender.backgroundColor = .systemBlue
        selectedPhonemes = ["I'm not sure"]
    }
    
    @IBAction func continueButtonTapped(_ sender: UIButton) {
        StorageManager.shared.savePhonemes(selectedPhonemes)
    }
    
    func clearAllSelections() {
        for button in phonemeButtons {
            button.isSelected = false
            button.backgroundColor = .white
        }
        noneButton.isSelected = false
        noneButton.backgroundColor = .white
        notSureButton.isSelected = false
        notSureButton.backgroundColor = .white
        selectedPhonemes.removeAll()
    }
}
