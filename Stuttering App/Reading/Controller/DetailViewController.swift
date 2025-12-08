//
//  DetailViewController.swift
//
//
//

import UIKit

class DetailViewController: UIViewController {
    
    @IBOutlet weak var textView: UITextView!
    
    var textToDisplay: String = ""
    var titleToDisplay: String = ""
    var exerciseDuration1: String = "N/A"
    private let wordsPerHighlight = 3
    private var highlightDuration: TimeInterval = 1.7
    private let minDuration: TimeInterval = 0.3
    private let maxDuration: TimeInterval = 4.0
    
    // State
    private(set) var isPlaying = false // set makes such that only this file type can make changes
    private var currentWordBlockIndex = 0
    private var highlightTimer: Timer?
    
    // Processed Data
    private var wordRanges: [NSRange] = [] // NSRange describes a slice of text
    private var defaultAttributes: [NSAttributedString.Key: Any] = [:] //text with formatting applied to specific ranges
    private var highlightAttributes: [NSAttributedString.Key: Any] = [:]
    
    // Reference to sheet (for callbacks)
    private weak var sheetVC: ReadingControlsViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "bg")
        textView.backgroundColor = UIColor(named: "bg")
        setupTextView()
        //view.insetsLayoutMarginsFromSafeArea = false
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presentWorkoutSheet()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    private func setupTextView() {
        let baseFont = UIFont.systemFont(ofSize: 18, weight: .semibold)
        
        defaultAttributes = [
            .font: baseFont,
            .foregroundColor: UIColor.gray,
        ]
        
        highlightAttributes = [
            .font: baseFont,
            .foregroundColor: UIColor.black,
            
        ]
        
        let attributedString = NSMutableAttributedString(string: textToDisplay, attributes: defaultAttributes)
        self.wordRanges = calculateWordRanges(for: textToDisplay)
        
        textView.attributedText = attributedString
        textView.isEditable = false
        textView.textAlignment = .left
        textView.layoutManager.allowsNonContiguousLayout = true //render only the visible parts.
    }
    
    private func calculateWordRanges(for text: String) -> [NSRange] {
        var ranges: [NSRange] = []
        let nsText = text as NSString
        let regex = try? NSRegularExpression(pattern: "\\S+")
        
        regex?.enumerateMatches(in: text, options: [], range: NSRange(location: 0, length: nsText.length)) { (match, _, _) in
            if let range = match?.range {
                ranges.append(range)
            }
        }
        return ranges
    }
    
    private func presentWorkoutSheet() {
        guard let sheetVC = storyboard?.instantiateViewController(withIdentifier: "ReadingControlsViewController") as? ReadingControlsViewController else { return }
        
        sheetVC.delegate = self// Set the delegate so the sheet can call back to us
        self.sheetVC = sheetVC
        
        sheetVC.isModalInPresentation = true
        
        if let sheet = sheetVC.sheetPresentationController {
            sheet.detents = [
                .custom(identifier: .init("quarter")) { context in
                    0.25 * context.maximumDetentValue
                },
                .custom(identifier: .init("half")) { context in
                    0.38 * context.maximumDetentValue
                }
            ]
            sheet.selectedDetentIdentifier = .init("quarter")
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            sheet.largestUndimmedDetentIdentifier = .init("quarter")
            
            sheet.preferredCornerRadius = 20 // default value is 10
        }
        
        // setting view ka corner radius
        sheetVC.view.layer.cornerRadius = 20
        sheetVC.view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        sheetVC.view.clipsToBounds = true
        
        present(sheetVC, animated: true)
    }
    
    // MARK: - Timer Management
    
    private func startTimer() {
        highlightTimer?.invalidate() //kill if any timer is running
        
        highlightTimer = Timer.scheduledTimer(withTimeInterval: highlightDuration, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            self.highlightBlock(at: self.currentWordBlockIndex)
            self.currentWordBlockIndex += 1
            
            if self.currentWordBlockIndex * self.wordsPerHighlight >= self.wordRanges.count {
                self.pausePlayback()
                self.highlightBlock(at: self.currentWordBlockIndex - 1, isFinalReset: true)
                self.notifySheetOfStateChange()
            }
        }
    }
    
    private func restartTimer() {
        if isPlaying {
            startTimer()
        }
    }
    
    // MARK: - Public Control Methods (Called by Sheet)
    
    func togglePlayPause() {
        if isPlaying {
            pausePlayback()
        } else {
            startPlayback()
        }
    }
    
    func startPlayback() {
        if currentWordBlockIndex * wordsPerHighlight >= wordRanges.count {
            currentWordBlockIndex = 0
            highlightBlock(at: -1, isFinalReset: true)
        }
        
        isPlaying = true
        startTimer()
        highlightBlock(at: currentWordBlockIndex)
        currentWordBlockIndex += 1
        
        notifySheetOfStateChange()
    }
    
    func pausePlayback() {
        isPlaying = false
        highlightTimer?.invalidate()
        highlightTimer = nil
        
        notifySheetOfStateChange()
    }
    
    func decreaseSpeed() {
        highlightDuration = max(minDuration, highlightDuration - 0.1)
        restartTimer()
    }
    
    func increaseSpeed() {
        highlightDuration = min(maxDuration, highlightDuration + 0.1)
        restartTimer()
    }
    
    func resetReading() {
        pausePlayback()
        currentWordBlockIndex = 0
        highlightBlock(at: -1, isFinalReset: true)
        textView.setContentOffset(.zero, animated: true)
        notifySheetOfStateChange()
    }
    
    private func notifySheetOfStateChange() {
        let hasFinished = currentWordBlockIndex * wordsPerHighlight >= wordRanges.count
        sheetVC?.updatePlaybackState(isPlaying: isPlaying, hasFinished: hasFinished)
    }
    
    // MARK: - Highlighting Logic
    
    private func highlightBlock(at blockIndex: Int, isFinalReset: Bool = false) {
        guard !wordRanges.isEmpty else { return }
        
        let mutableAttributedText = NSMutableAttributedString(attributedString: textView.attributedText)
        let fullRange = NSRange(location: 0, length: mutableAttributedText.length)
        
        mutableAttributedText.setAttributes(defaultAttributes, range: fullRange)
        
        if isFinalReset {
            textView.attributedText = mutableAttributedText
            return
        }
        
        let startIndex = blockIndex * wordsPerHighlight
        let endIndex = min(startIndex + wordsPerHighlight, wordRanges.count)
        
        if startIndex < wordRanges.count {
            let startRange = wordRanges[startIndex]
            let endRangeIndex = min(endIndex - 1, wordRanges.count - 1)
            let endRange = wordRanges[endRangeIndex]
            
            let highlightLocation = startRange.location
            let highlightLength = endRange.location + endRange.length - startRange.location
            let highlightRange = NSRange(location: highlightLocation, length: highlightLength)
            
            mutableAttributedText.addAttributes(highlightAttributes, range: highlightRange)
            textView.attributedText = mutableAttributedText
            textView.layoutIfNeeded()
            
            let scrollRange = endRange
            let layoutManager = textView.layoutManager
            let rect = layoutManager.boundingRect(forGlyphRange: scrollRange, in: textView.textContainer)
            
            let targetY = rect.minY - (textView.bounds.height / 2.0) + (rect.height / 2.0)
            let maxScrollY = max(0, textView.contentSize.height - textView.bounds.height)
            let finalY = min(maxScrollY, max(0, targetY))
            
            let targetOffset = CGPoint(x: 0, y: finalY)
            textView.setContentOffset(targetOffset, animated: true)
        }
    }
    
    
    func didTapOpenButton() {
        guard let ResultVC = storyboard?.instantiateViewController(withIdentifier: "ResultViewController") as? ResultViewController else {
            return
        }
        let ResultNav = UINavigationController(rootViewController: ResultVC)
        ResultNav.modalPresentationStyle = .fullScreen
        self.present(ResultNav, animated: true, completion: nil)
        logReadingActivity()
    }
    
    
    func logReadingActivity() {
        //        // This assumes you've added ".reading" to your ExerciseSource enum
        //        if let duration = ExerciseDataManager.shared.getDurationString(for: titleToDisplay) {
        //            exerciseDuration1 = duration
        //        } else {
        //            exerciseDuration1 = "N/A"
        //        }
        //
        //        // 2. Use the LogManager to save the new log
        //        LogManager.shared.addLog(
        //            exerciseName: titleToDisplay, // Use the name that was passed
        //            source: .reading,
        //            exerciseDuration: exerciseDuration1
        //        )
        //
        //        print("Reading activity logged.") // For debugging
    }
}

extension DetailViewController: WorkoutSheetDelegate {
    func didTapPlayPause() {
        togglePlayPause()
    }
    
    func didTapDecreaseSpeed() {
        decreaseSpeed()
    }
    
    func didTapIncreaseSpeed() {
        increaseSpeed()
    }
    
    func didTapReset() {
        resetReading()
    }
    
    func didTapShowResult() {
        self.dismiss(animated: true, completion: nil)
        didTapOpenButton()
    }
}
