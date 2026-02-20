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
        
        // Initial styling for all buttons
        for button in phonemeButtons {
            stylePhonemeButton(button)
        }
        stylePhonemeButton(noneButton)
        stylePhonemeButton(notSureButton)
    }
    
    func stylePhonemeButton(_ button: UIButton) {
        button.layer.cornerRadius = 12
        button.titleLabel?.font = UIFont.systemFont(ofSize: 20)
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.layer.shadowOpacity = 0.1
        button.layer.shadowRadius = 3
        updateButtonStyle(button) // Set initial colors
    }

    // Common logic to update colors based on selected state
    func updateButtonStyle(_ button: UIButton) {
        if button.isSelected {
            button.backgroundColor = .systemBlue
            button.setTitleColor(.white, for: .normal)
        } else {
            button.backgroundColor = .white
            button.setTitleColor(.black, for: .normal)
        }
    }

    // Action for the 12 specific phoneme buttons
    @IBAction func phonemeButtonTapped(_ sender: UIButton) {
        // If a specific phoneme is picked, "None" and "Not Sure" must be deselected
        deselectSpecialButtons()
        
        sender.isSelected.toggle()
        updateButtonStyle(sender)
        
        if let title = sender.currentTitle {
            if sender.isSelected {
                if !selectedPhonemes.contains(title) { selectedPhonemes.append(title) }
            } else {
                selectedPhonemes.removeAll { $0 == title }
            }
        }
    }
    
    @IBAction func noneButtonTapped(_ sender: UIButton) {
        clearAllPhonemeButtons()
        
        // Turn off Not Sure specifically
        notSureButton.isSelected = false
        updateButtonStyle(notSureButton)
        
        sender.isSelected = true
        updateButtonStyle(sender)
        selectedPhonemes = ["None of these"]
    }
    
    @IBAction func notSureButtonTapped(_ sender: UIButton) {
        clearAllPhonemeButtons()
        
        // Turn off None specifically
        noneButton.isSelected = false
        updateButtonStyle(noneButton)
        
        sender.isSelected = true
        updateButtonStyle(sender)
        selectedPhonemes = ["I'm not sure"]
    }

    func deselectSpecialButtons() {
        noneButton.isSelected = false
        updateButtonStyle(noneButton)
        
        notSureButton.isSelected = false
        updateButtonStyle(notSureButton)
    }

    func clearAllPhonemeButtons() {
        for button in phonemeButtons {
            button.isSelected = false
            updateButtonStyle(button)
        }
        selectedPhonemes.removeAll()
    }
    
    @IBAction func continueButtonTapped(_ sender: UIButton) {
        // StorageManager.shared.savePhonemes(selectedPhonemes)
        print("Saved phonemes: \(selectedPhonemes)")
    }
}
