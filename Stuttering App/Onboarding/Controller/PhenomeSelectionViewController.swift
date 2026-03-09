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
        
        button.backgroundColor = isSelected ? .systemBlue : UIColor(red: 0.92, green: 0.92, blue: 0.95, alpha: 1.0)
        
        if #available(iOS 15.0, *), button.configuration != nil {
            button.configuration?.baseForegroundColor = textColor
            
            if let configAttr = button.configuration?.attributedTitle {
                var newAttr = configAttr
                newAttr.foregroundColor = textColor
                button.configuration?.attributedTitle = newAttr
            }
        }
        
        if let attr = button.attributedTitle(for: .normal) {
            let mutable = NSMutableAttributedString(attributedString: attr)
            
            mutable.addAttribute(
                .foregroundColor,
                value: textColor,
                range: NSRange(location: 0, length: mutable.length)
            )
            
            button.setAttributedTitle(mutable, for: .normal)
            button.setAttributedTitle(mutable, for: .selected)
            button.setAttributedTitle(mutable, for: .highlighted)
        }
        
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
        resetSpecialButtons()
        
        sender.isSelected = true
        updateButtonAppearance(sender)
        
        selectedPhonemes = ["None"]
        updateContinueState()
    }

    @IBAction func notSureButtonTapped(_ sender: UIButton) {
        clearPhonemeButtons()
        resetSpecialButtons()
        
        sender.isSelected = true
        updateButtonAppearance(sender)
        
        selectedPhonemes = ["Not sure"]
        updateContinueState()
    }

    @IBAction func continueButtonTapped(_ sender: UIButton) {
        print("Saved phonemes:", selectedPhonemes)
    }
}

