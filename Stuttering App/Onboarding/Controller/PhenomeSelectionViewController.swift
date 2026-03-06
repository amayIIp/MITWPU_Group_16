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
    
    var selectedPhonemes: Set<String> = []
    var phonemeButtons: [UIButton] = []

    let phonemeMap: [Int: String] = [
        0:"b", 1:"p", 2:"k", 3:"g",
        4:"t", 5:"d", 6:"s", 7:"sh",
        8:"f", 9:"v", 10:"r", 11:"l"
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        
        phonemeButtons = [
            phonemeB, phonemeP, phonemeK, phonemeG,
            phonemeT, phonemeD, phonemeS, phonemeSH,
            phonemeF, phonemeV, phonemeR, phonemeL
        ]
        
        for (index, button) in phonemeButtons.enumerated() {
            button.tag = index
            styleButton(button)
        }
        
        styleButton(noneButton)
        styleButton(notSureButton)
        
        continueButton.isEnabled = false
        continueButton.alpha = 0.5
    }

    func styleButton(_ button: UIButton) {
        button.layer.cornerRadius = 16
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.layer.shadowOpacity = 0.08
        button.layer.shadowRadius = 3
        
        updateButtonAppearance(button)
    }

    func updateButtonAppearance(_ button: UIButton) {
        let isSelected = button.isSelected
        let textColor: UIColor = isSelected ? .white : .black
        
        // Set background color (using a light gray for unselected to match your screenshot)
        button.backgroundColor = isSelected ? .systemBlue : UIColor(red: 0.92, green: 0.92, blue: 0.95, alpha: 1.0)
        
        // 1. Handle modern iOS 15+ Button Configurations
        if #available(iOS 15.0, *), button.configuration != nil {
            button.configuration?.baseForegroundColor = textColor
            
            if let configAttr = button.configuration?.attributedTitle {
                var newAttr = configAttr
                newAttr.foregroundColor = textColor
                button.configuration?.attributedTitle = newAttr
            }
        }
        
        // 2. Handle standard/legacy UIButtons
        if let attr = button.attributedTitle(for: .normal) {
            let mutable = NSMutableAttributedString(attributedString: attr)
            
            mutable.addAttribute(
                .foregroundColor,
                value: textColor,
                range: NSRange(location: 0, length: mutable.length)
            )
            
            // Explicitly set for ALL relevant states so UIKit doesn't try to be smart
            button.setAttributedTitle(mutable, for: .normal)
            button.setAttributedTitle(mutable, for: .selected)
            button.setAttributedTitle(mutable, for: .highlighted)
        }
        
        // 3. Force the tint color as a final fallback
        button.tintColor = textColor
    }

    func updateContinueState() {
        let enabled = !selectedPhonemes.isEmpty
        continueButton.isEnabled = enabled
        continueButton.alpha = enabled ? 1 : 0.5
    }

    func resetSpecialButtons() {
        [noneButton, notSureButton].forEach {
            $0?.isSelected = false
            if let button = $0 { updateButtonAppearance(button) }
        }
    }

    func clearPhonemeButtons() {
        phonemeButtons.forEach {
            $0.isSelected = false
            updateButtonAppearance($0)
        }
        selectedPhonemes.removeAll()
    }

    @IBAction func phonemeButtonTapped(_ sender: UIButton) {
        resetSpecialButtons()
        
        sender.isSelected.toggle()
        updateButtonAppearance(sender)
        
        if let phoneme = phonemeMap[sender.tag] {
            if sender.isSelected {
                selectedPhonemes.insert(phoneme)
            } else {
                selectedPhonemes.remove(phoneme)
            }
        }
        
        updateContinueState()
    }

    @IBAction func noneButtonTapped(_ sender: UIButton) {
        clearPhonemeButtons()
        
        sender.isSelected = true
        updateButtonAppearance(sender)
        
        selectedPhonemes = ["None"]
        updateContinueState()
    }

    @IBAction func notSureButtonTapped(_ sender: UIButton) {
        clearPhonemeButtons()
        
        sender.isSelected = true
        updateButtonAppearance(sender)
        
        selectedPhonemes = ["Not sure"]
        updateContinueState()
    }

    @IBAction func continueButtonTapped(_ sender: UIButton) {
        print("Saved phonemes:", selectedPhonemes)
    }
}
    
//    var selectedPhonemes: [String] = []
//    var phonemeButtons: [UIButton] = []
//    
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        setupButtons()
//        continueButton.isEnabled = false
//        continueButton.alpha = 0.5
//    }
//    func updateContinueButtonState() {
//        let hasSelection = !selectedPhonemes.isEmpty
//        continueButton.isEnabled = hasSelection
//        continueButton.alpha = hasSelection ? 1.0 : 0.5
//    }
//    func setupButtons() {
//        phonemeButtons = [phonemeB, phonemeP, phonemeK, phonemeG, phonemeT, phonemeD,
//                          phonemeS, phonemeSH, phonemeF, phonemeV, phonemeR, phonemeL]
//        
//        // Initial styling for all buttons
//        for button in phonemeButtons {
//            stylePhonemeButton(button)
//        }
//        stylePhonemeButton(noneButton)
//        stylePhonemeButton(notSureButton)
//    }
//    
////    func stylePhonemeButton(_ button: UIButton) {
////        button.layer.cornerRadius = 12
////        button.titleLabel?.font = UIFont.systemFont(ofSize: 20)
////        button.layer.shadowColor = UIColor.black.cgColor
////        button.layer.shadowOffset = CGSize(width: 0, height: 1)
////        button.layer.shadowOpacity = 0.1
////        button.layer.shadowRadius = 3
////        updateButtonStyle(button) // Set initial colors
////    }
//    func stylePhonemeButton(_ button: UIButton) {
//        button.layer.cornerRadius = 12
//        button.titleLabel?.font = UIFont.systemFont(ofSize: 20)
//        
//        button.setTitleColor(.black, for: .normal)
//        button.setTitleColor(.white, for: .selected)
//        
//        button.layer.shadowColor = UIColor.black.cgColor
//        button.layer.shadowOffset = CGSize(width: 0, height: 1)
//        button.layer.shadowOpacity = 0.1
//        button.layer.shadowRadius = 3
//        
//        updateButtonStyle(button)
//    }
//
//    // Common logic to update colors based on selected state
////    func updateButtonStyle(_ button: UIButton) {
////        button.backgroundColor = button.isSelected ? .systemBlue : .white
////        button.setTitleColor(button.isSelected ? .white : .black, for: .normal)
////    }
////    func updateButtonStyle(_ button: UIButton) {
////        button.backgroundColor = button.isSelected ? .systemBlue : .white
////    }
//    func updateButtonStyle(_ button: UIButton) {
//        let isSelected = button.isSelected
//        button.backgroundColor = isSelected ? .systemBlue : .white
//        
//        guard let title = button.currentTitle else { return }
//        
//        let color: UIColor = isSelected ? .white : .black
//        
//        let attributed = NSMutableAttributedString(string: title)
//        
//        attributed.addAttribute(
//            .foregroundColor,
//            value: color,
//            range: NSRange(location: 0, length: attributed.length)
//        )
//        
//        button.setAttributedTitle(attributed, for: .normal)
//    }
//
//    // Action for the 12 specific phoneme buttons
//    @IBAction func phonemeButtonTapped(_ sender: UIButton) {
//        // If a specific phoneme is picked, "None" and "Not Sure" must be deselected
//        deselectSpecialButtons()
//        
//        sender.isSelected.toggle()
//        updateButtonStyle(sender)
//        
//        if let title = sender.currentTitle {
//            if sender.isSelected {
//                if !selectedPhonemes.contains(title) { selectedPhonemes.append(title) }
//            } else {
//                selectedPhonemes.removeAll { $0 == title }
//            }
//        }
//        updateContinueButtonState()
//    }
//    
//    @IBAction func noneButtonTapped(_ sender: UIButton) {
//        clearAllPhonemeButtons()
//        
//        // Turn off Not Sure specifically
//        notSureButton.isSelected = false
//        updateButtonStyle(notSureButton)
//        
//        sender.isSelected = true
//        updateButtonStyle(sender)
//        selectedPhonemes = ["None of these"]
//        updateContinueButtonState()
//    }
//    
//    @IBAction func notSureButtonTapped(_ sender: UIButton) {
//        clearAllPhonemeButtons()
//        
//        // Turn off None specifically
//        noneButton.isSelected = false
//        updateButtonStyle(noneButton)
//        
//        sender.isSelected = true
//        updateButtonStyle(sender)
//        selectedPhonemes = ["I'm not sure"]
//        updateContinueButtonState()
//    }
//
//    func deselectSpecialButtons() {
//        noneButton.isSelected = false
//        updateButtonStyle(noneButton)
//        
//        notSureButton.isSelected = false
//        updateButtonStyle(notSureButton)
//    }
//
//    func clearAllPhonemeButtons() {
//        for button in phonemeButtons {
//            button.isSelected = false
//            updateButtonStyle(button)
//        }
//        selectedPhonemes.removeAll()
//        updateContinueButtonState()
//    }
//    
//    @IBAction func continueButtonTapped(_ sender: UIButton) {
//        // StorageManager.shared.savePhonemes(selectedPhonemes)
//        print("Saved phonemes: \(selectedPhonemes)")
//    }
//}
