//
//  ProlongationViewController.swift
//  Stuttering App 1
//
//  Created by Prathamesh Patil on 15/12/25.
//

import UIKit

class GentleOnsetsViewController: UIViewController {
    
    var exerciseID: String = "ex_2_1"
    var exerciseName: String = "Gentle Onset"
    let sessionTotalTime: TimeInterval = 120.0
    var startingSource: ExerciseSource?

    @IBOutlet weak var sentenceLabel: UILabel!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var instructionLabel: UILabel!
    @IBOutlet weak var finishButton: UIButton!
    
    var sentenceList: [SentenceData] = []
    var currentIndex: Int = 0
    var practiceTimer: Timer?
    var secondsRemaining = 10
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadJSONData()
        updateContent()
        startMandatorySessionTimer()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        practiceTimer?.invalidate()
    }
    
    func setupUI() {
        sentenceLabel.font = .preferredFont(forTextStyle: .title2)
        sentenceLabel.numberOfLines = 0
        sentenceLabel.textAlignment = .center
        
        var nextConfig = UIButton.Configuration.glass()
        nextConfig.title = "Next"
        nextButton.configuration = nextConfig
        var finishConfig = UIButton.Configuration.prominentGlass()
        finishConfig.cornerStyle = .capsule
        finishButton.configuration = finishConfig
        finishButton.isEnabled = false
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "xmark"), style: .plain, target: self, action: #selector(closeButtonTapped))
    }
    
    func loadJSONData() {
        guard let fileURL = Bundle.main.url(forResource: "Prolongations", withExtension: "json") else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            sentenceList = try JSONDecoder().decode([SentenceData].self, from: data)
        } catch {
            print("Error: \(error)")
        }
    }
    
    func updateContent() {
        guard !sentenceList.isEmpty else { return }
        
        let item = sentenceList[currentIndex]
        let fullText = item.sentence
        let targetWord = item.word
        
        // 1. Initialize Mutable String
        let attributedString = NSMutableAttributedString(string: fullText)
        
        // 2. Find range of the word
        let wordRange = (fullText as NSString).range(of: targetWord)
        
        if wordRange.location != NSNotFound {
            // 3. Isolate the FIRST letter range
            let firstLetterRange = NSRange(location: wordRange.location, length: 1)
            
            // 4. Extract and Capitalize the letter
            let firstLetterChar = (fullText as NSString).substring(with: firstLetterRange)
            let capitalizedLetter = firstLetterChar.uppercased()
            
            // 5. Replace in the string (visual capitalization)
            attributedString.replaceCharacters(in: firstLetterRange, with: capitalizedLetter)
            
            // 6. Apply Styles (Bigger, Bold, Color)
            // iOS 26 Design: Using 'heavy' weight and scaling font size up by 1.5x
            
            let highlightFont = UIFont.systemFont(ofSize: 24, weight: .heavy)
            
            attributedString.addAttribute(.font, value: highlightFont, range: firstLetterRange)
            attributedString.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: firstLetterRange)
        }
        
        sentenceLabel.attributedText = attributedString
        instructionLabel.text = "Use Gentle Onsets for \"\(targetWord)\""
    }
    
    func startMandatorySessionTimer() {
        updateFinishButtonText()
        practiceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.secondsRemaining > 0 {
                self.secondsRemaining -= 1
                self.updateFinishButtonText()
            } else {
                self.enableFinishButton()
            }
        }
    }
    
    func updateFinishButtonText() {
        let minutes = secondsRemaining / 60
        let seconds = secondsRemaining % 60
        let timeString = String(format: "%02d:%02d", minutes, seconds)
        
        var config = finishButton.configuration
        var container = AttributeContainer()
        container.font = UIFont.monospacedDigitSystemFont(ofSize: 16, weight: .medium)
        config?.attributedTitle = AttributedString("Wait \(timeString)", attributes: container)
        finishButton.configuration = config
    }
    
    func enableFinishButton() {
        practiceTimer?.invalidate()
        practiceTimer = nil
        
        finishButton.configuration = .prominentGlass()
        finishButton.setTitle("Finsh", for: .normal)
        finishButton.isEnabled = true
    }

    @IBAction func nextButtonTapped(_ sender: UIButton) {
        guard !sentenceList.isEmpty else { return }
        currentIndex = (currentIndex + 1) % sentenceList.count
        updateContent()
    }
    
    @IBAction func finishButtonTapped(_ sender: UIButton) {
        
        guard let source = startingSource else {
            print("Error: Source is nil. Dismissing.")
            self.dismiss(animated: true)
            return
        }
        
        LogManager.shared.addLog(
            exerciseName: self.exerciseName,
            source: source,
            exerciseDuration: Int(self.sessionTotalTime)
        )
        
        let storyboard = UIStoryboard(name: "Exercise", bundle: nil)
        guard let ResultVC = storyboard.instantiateViewController(withIdentifier: "ExerciseResult") as? ExerciseResultViewController else {
            return
        }
        
        ResultVC.exerciseName = self.exerciseName
        ResultVC.durationLabelForExercise = Int(self.sessionTotalTime)
        
        let ResultNav = UINavigationController(rootViewController: ResultVC)
        ResultNav.modalPresentationStyle = .fullScreen
        self.present(ResultNav, animated: true, completion: nil)
    }
    
    @IBAction func closeButtonTapped(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
}
