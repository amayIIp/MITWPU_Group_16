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
    }

    func styleButton(_ button: UIButton) {
        button.layer.cornerRadius = 16
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.layer.shadowOpacity = 0.08
        button.layer.shadowRadius = 3
        
        // Prevent the default system blue highlight flash
        button.tintColor = .clear
        
        updateButtonAppearance(button)
    }

    func updateButtonAppearance(_ button: UIButton) {
        let isSelected = button.isSelected
        let purple = UIColor(named: "ButtonTheme") ?? UIColor(red: 151/255.0, green: 160/255.0, blue: 219/255.0, alpha: 1.0)
        let textColor: UIColor = isSelected ? .white : .black
        
        button.backgroundColor = isSelected ? purple : .white
        
        if #available(iOS 15.0, *), button.configuration != nil {
            button.configuration?.baseForegroundColor = textColor
            button.configuration?.background.backgroundColor = isSelected ? purple : .white
            
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
        
        button.tintColor = isSelected ? .white : .clear
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
    }

    @IBAction func noneButtonTapped(_ sender: UIButton) {
        clearPhonemeButtons()
        resetSpecialButtons()
        
        sender.isSelected = true
        updateButtonAppearance(sender)
    }

    @IBAction func notSureButtonTapped(_ sender: UIButton) {
        clearPhonemeButtons()
        resetSpecialButtons()
        
        sender.isSelected = true
        updateButtonAppearance(sender)
    }

    @IBAction func continueButtonTapped(_ sender: UIButton) {
        print("Raw selected phonemes from UI:", selectedPhonemes)
        
        var databaseGroupsToSave: Set<String> = []
        
        // 1. Define how our raw letters map to the Database/JSON Groups
        let plosiveLetters: Set<String> = ["b", "p", "k", "g", "t", "d"]
        let fricativeLetters: Set<String> = ["s", "sh", "f", "v"]
        let voicedLetters: Set<String> = ["r", "l"]
        
        // 2. Check if the user selected any letters that belong to these groups
        // `isDisjoint` returns false if they share at least one item
        if !selectedPhonemes.isDisjoint(with: plosiveLetters) {
            databaseGroupsToSave.insert("Plosives (P, B, T, D, K, G)")
        }
        
        if !selectedPhonemes.isDisjoint(with: fricativeLetters) {
            databaseGroupsToSave.insert("Fricatives (S, F, SH, TH)")
        }
        
        if !selectedPhonemes.isDisjoint(with: voicedLetters) {
            databaseGroupsToSave.insert("Vowels (A,E,I,O,U) & Voiced (M,N,L)")
        }
        
        // 3. Save to SQLite Database and mirror to UserDefaults via StorageManager.
        // (If they tapped "None" or "Not Sure", the array will be empty, which is perfectly safe.)
        DatabaseManager.shared.saveUserProblemPhonemes(phonemes: Array(databaseGroupsToSave))
        StorageManager.shared.savePhonemes(Array(databaseGroupsToSave))

        print("Mapped and Saved to DB and StorageManager:", databaseGroupsToSave)
        // Navigation is handled by the storyboard segue connected to this button.
    }
}
