//
//  StoryCubesViewController.swift
//  Stuttering Final
//
//  Created by SDC-USER on 18/02/26.
//

import UIKit
import AVFoundation

class StoryCubesViewController: UIViewController, AVAudioRecorderDelegate {

    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var targetLabel: UILabel!
    
    var audioRecorder: AVAudioRecorder?
    var recordingSession: AVAudioSession!
    var currentExercise = "Voice Diary"
    var recordingTimer: Timer?
    var secondsRecorded = 0
    var targetWord: String = ""
    var currentFileID: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        setupAudioSession()
        styleUI()
        updateButtonState(isRecording: false)
        view.layoutIfNeeded()
        targetLabel.text = targetWord
    }

    // MARK: - Audio Setup
    func setupAudioSession() {
        recordingSession = AVAudioSession.sharedInstance()
        do {
            try recordingSession.setCategory(.playAndRecord, mode: .default)
            try recordingSession.setActive(true)
            
            // Modern iOS permission request
            AVAudioApplication.requestRecordPermission { allowed in
                if !allowed {
                    print("⚠️ Microphone permission denied.")
                }
            }
        } catch {
            print("⚠️ Failed to set up audio session: \(error.localizedDescription)")
        }
    }

    // MARK: - Actions
    @IBAction func toggleRecording(_ sender: UIButton) {
        if let recorder = audioRecorder, recorder.isRecording {
            // STOP RECORDING
            recorder.stop()
            updateButtonState(isRecording: false)
            stopTimer()
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
        } else {
            // START RECORDING
            startRecording()
            updateButtonState(isRecording: true)
            startTimer()
            
            let generator = UIImpactFeedbackGenerator(style: .rigid)
            generator.impactOccurred()
        }
    }
    
    @IBAction func tapToMainScreen(_ sender: Any) {
        if let initialPresenter = self.navigationController?.presentingViewController {
            initialPresenter.dismiss(animated: true, completion: nil)
        }
    }

    func startRecording() {
        currentFileID = UUID().uuidString
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(currentFileID).appendingPathExtension("m4a")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: tempURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
        } catch {
            print("⚠️ Could not start recording: \(error.localizedDescription)")
        }
    }

    // MARK: - Timer Logic
    func startTimer() {
        secondsRecorded = 0
        durationLabel.text = "00:00"
        durationLabel.isHidden = false
        
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.secondsRecorded += 1
            
            let minutes = self.secondsRecorded / 60
            let seconds = self.secondsRecorded % 60
            self.durationLabel.text = String(format: "%02d:%02d", minutes, seconds)
        }
    }

    func stopTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        durationLabel.isHidden = true
    }

    // MARK: - UI & Styling
    func styleUI() {
        // Note: You can add a static microphone icon or waveform image inside this view in Storyboard
        
        durationLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 18, weight: .semibold)
        durationLabel.textColor = .label
    }
    
   
    
    func updateButtonState(isRecording: Bool) {
        // 1. Use .filled() or .tinted() based on your preference (Images show tinted)
        var config = UIButton.Configuration.tinted()
        config.baseForegroundColor = .systemRed
        config.baseBackgroundColor = .systemRed
        config.cornerStyle = .capsule
        
        // 2. Control the Logo Size explicitly
        // Lowering the pointSize (e.g. 24) prevents it from taking over the button
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .bold)
        
        if isRecording {
            // --- STOP STATE (Circle) ---
            config.image = UIImage(systemName: "square.fill", withConfiguration: iconConfig)
            config.title = "" // No text
            
            // 3. Add ample padding to create the "Circle" shape with space around the square
            // High even values (top/bottom/leading/trailing) ensure the button is much larger than the icon
            config.contentInsets = NSDirectionalEdgeInsets(top: 24, leading: 24, bottom: 24, trailing: 24)
            
        } else {
            // --- START STATE (Capsule) ---
            config.image = UIImage(systemName: "mic.fill", withConfiguration: iconConfig)
            config.title = "Start Recording"
            config.imagePadding = 12 // Space between Mic and Text
            
            // 4. Add "Fat" padding for a touch-friendly main button
            // Extra horizontal padding (leading/trailing) makes it look like a proper pill
            config.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 32, bottom: 16, trailing: 32)
        }
        
        // Smoothly animate the size change
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut) {
            self.recordButton.configuration = config
            self.recordButton.layoutIfNeeded() // Forces the size update immediately during animation
        }
    }

    // MARK: - AVAudioRecorderDelegate (File Saving)
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        guard flag else {
            print("⚠️ Recording failed to finish successfully.")
            return
        }
        
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destinationURL = documentsURL.appendingPathComponent("\(currentFileID).m4a")
        
        do {
            try fileManager.moveItem(at: recorder.url, to: destinationURL)
            let finalDuration = Double(self.secondsRecorded)
            
            // Assuming you have an AudioLog struct mirroring VideoLog
            let newLog = AudioLog(id: currentFileID, heading: self.targetWord, date: Date(), duration: finalDuration)
            AudioMetadataManager.shared.saveLog(newLog)
            
            print("✅ Successfully saved audio and metadata to: \(destinationURL)")
            
        } catch {
            print("⚠️ Error saving file: \(error.localizedDescription)")
        }
    }
}
