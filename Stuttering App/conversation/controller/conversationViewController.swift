//
//  conversationViewController.swift
//  Stuttering App
//
//  Created by SDC-USER on 27/11/25.
//

import UIKit

class conversationViewController: UIViewController {

    @IBOutlet weak var StartPauseButton: UIButton?
    @IBOutlet weak var captionStackView: UIStackView?
    
    private var timer: Timer?
    private var isRunning = false
    
    private var captions: [String] = [
       
            "Hey, how’s your day going so far?",
            "You’ve been doing really well.",
            "Your workouts look strong lately.",
            "Feeling good after today’s session?",
            "Small steps make big progress.",
            "Hello, What would you like to talk about ?",
            "I hope today brings you something to smile about.",
            "You’re showing real dedication lately.",
            "Every step you take matters, even the tiny ones.",
            "How are you feeling emotionally today?",
            "I’m here to chat whenever you’re ready.",
            "You’ve improved more than you realize.",
            "How do you usually relax after a long day?",
            "Your consistency is starting to show great results.",
            "Your voice matters — every word of it.",
            "Take a breath, take your time, you’re doing great.",
            "Have you been taking care of yourself today?",
            "You’re capable of much more than you think.",
            "What’s something good that happened this week?",
            "Progress isn’t always loud — sometimes it’s quiet.",
            "You should be proud of your efforts.",
            "Let’s take things one moment at a time.",
            "Your confidence is growing, step by step.",
            "What’s something you’re looking forward to today?",
            "Courage doesn’t mean being perfect — it means showing up.",
            "You handled things really well recently.",
            "How do you feel about your progress so far?",
            "It’s okay to slow down — you’re still moving forward.",
            "Your voice is becoming clearer day by day.",
            "You’re becoming a stronger communicator.",
            "You deserve credit for trying your best.",
            "Let’s take a deep breath and keep going.",
            "Every conversation is an opportunity to grow.",
            "Your determination is inspiring.",
            "What’s on your mind right now?",
            "You’re learning at your own pace — and that’s perfect.",
            "It’s completely okay to take breaks.",
            "You’re showing real growth, even if you don’t always notice it.",
            "Speaking is a journey, not a race.",
            "You’re getting better every single day.",
            "What’s something you want to get better at?",
            "Your effort today will pay off tomorrow.",
            "Let’s continue at a pace that feels comfortable to you.",
            "You’re becoming more confident with every practice.",
            "Your thoughts are valuable — let’s express them together.",
            "It’s okay to stumble — progress isn’t linear.",
            "I’m proud of the effort you’re putting in.",
            "How are you feeling at this moment?",
            "You’re doing something meaningful for yourself.",
            "Your voice has strength — let’s bring it out.",
            "Remember: clarity takes time and practice.",
            "Thank you for showing up today — that’s huge."
        

        
    ]
    
    private var captionIndex = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Safety: Check if outlets exist
        guard let startButton = StartPauseButton,
              let _ = captionStackView else {
            print("❌ ERROR: IBOutlets not connected in storyboard.")
            return
        }
        
        // Set initial play icon
        startButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        
        // Show first caption only if data exists
        if !captions.isEmpty {
            addNextCaption()
        } else {
            print("⚠️ Warning: captions array is empty.")
        }
    }
    
    
    // MARK: - BUTTON ACTIONS
    @IBAction func startPauseButtonTapped(_ sender: UIButton) {
        if isRunning {
            pauseConversation()
        } else {
            startConversation()
        }
    }
    
    @IBAction func restartButtonTapped(_ sender: Any) {
        restartConversation()
    }
    

    // MARK: - START
    func startConversation() {
        
        guard captions.count > 0 else {
            print("⚠️ Cannot start: captions array is empty.")
            return
        }
        
        guard timer == nil else {
            print("⚠️ Timer already running. Preventing duplicate timers.")
            return
        }
        
        isRunning = true
        StartPauseButton?.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        
        timer = Timer.scheduledTimer(timeInterval: 3.0,
                                     target: self,
                                     selector: #selector(addNextCaption),
                                     userInfo: nil,
                                     repeats: true)
        
        if timer == nil {
            print("❌ ERROR: Timer failed to schedule.")
        }
    }
    
    
    // MARK: - PAUSE
    func pauseConversation() {
        isRunning = false
        StartPauseButton?.setImage(UIImage(systemName: "play.fill"), for: .normal)
        
        if timer == nil {
            print("ℹ️ Timer was already nil before pausing.")
        }
        
        timer?.invalidate()
        timer = nil
    }
    
    
    // MARK: - RESTART
    func restartConversation() {
        pauseConversation()
        
        guard let stackView = captionStackView else {
            print("❌ ERROR: captionStackView is nil.")
            return
        }
        
        // Remove all labels safely
        for view in stackView.arrangedSubviews {
            view.removeFromSuperview()
        }
        
        captionIndex = 0
        
        if !captions.isEmpty {
            addNextCaption()
        }
        
        startConversation()
    }
    
    
    // MARK: - ADD NEXT CAPTION
    @objc func addNextCaption() {
        
        guard captionIndex < captions.count else {
            print("ℹ️ All captions displayed. Stopping timer.")
            pauseConversation()
            return
        }
        
        guard let stackView = captionStackView else {
            print("❌ ERROR: captionStackView is nil.")
            pauseConversation()
            return
        }
        
        let captionText = captions[captionIndex]
        captionIndex += 1
        
        let label = UILabel()
        label.text = captionText
        label.alpha = 0
        label.textColor = .black
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.numberOfLines = 0
        
        stackView.addArrangedSubview(label)
        
        UIView.animate(withDuration: 0.7) {
            label.alpha = 1
        }
        
        UIView.animate(withDuration: 1.5, delay: 1.5) {
            label.alpha = 0.2
        }
        
        scrollStackUpwards()
    }
    
    
    // MARK: - MOVE STACK UP
    func scrollStackUpwards() {
        guard captionStackView != nil else {
            print("❌ ERROR: captionStackView is missing.")
            return
        }
        
        UIView.animate(withDuration: 0.7) {
            self.captionStackView?.layoutIfNeeded()
        }
    }
    
    
    // MARK: - CLEANUP (Prevent timer leaks)
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if timer != nil {
            print("ℹ️ View disappeared: stopping timer to prevent memory leaks.")
        }
        
        timer?.invalidate()
        timer = nil
    }
}
