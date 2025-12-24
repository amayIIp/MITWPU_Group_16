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
        
        for button in phonemeButtons {
            stylePhonemeButton(button)
        }
        stylePhonemeButton(noneButton)
        stylePhonemeButton(notSureButton)
        
        continueButton.configuration = .prominentGlass()
        continueButton.configuration?.title = "Continue"
    
    }
    
    func stylePhonemeButton(_ button: UIButton) {
        button.backgroundColor = .white
        button.layer.cornerRadius = 12
        button.setTitleColor(.black, for: .normal)
        button.setTitleColor(.white, for: .selected)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 20)
        // Add shadow for depth
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.layer.shadowOpacity = 0.1
        button.layer.shadowRadius = 3
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
        sender.backgroundColor = .systemBlue
        selectedPhonemes = ["None of these"]
    }
    
    @IBAction func notSureButtonTapped(_ sender: UIButton) {
        clearAllSelections()
        sender.isSelected = true
        sender.backgroundColor = .systemBlue
        selectedPhonemes = ["I'm not sure"]
    }
    
    @IBAction func continueButtonTapped(_ sender: UIButton) {
        StorageManager.shared.savePhonemes(selectedPhonemes)
        //print("Saved phonemes: \(selectedPhonemes)")
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
