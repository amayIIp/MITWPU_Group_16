import UIKit
import AVFoundation

class VideoDiaryViewController: UIViewController, AVCaptureFileOutputRecordingDelegate {

    @IBOutlet weak var cameraCardView: UIView!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var targetLabel: UILabel!
    
    var captureSession: AVCaptureSession!
    var videoOutput: AVCaptureMovieFileOutput!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var currentExercise = "Video Dairy"
    var recordingTimer: Timer?
    var secondsRecorded = 0
    var targetWord: String = "How was your day?"

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        styleUI()
        updateButtonState(isRecording: false)
        
        // Force the Auto Layout engine to calculate final dimensions immediately
        view.layoutIfNeeded()
        
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Instantly snap the preview layer to the bounds without animation lag
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer?.frame = cameraCardView.bounds
        CATransaction.commit()
    }

    // Replace your existing setupCamera with this:
    func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .high
        
        // Initialize output EARLY so it is never nil, preventing the crash
        videoOutput = AVCaptureMovieFileOutput()

        // 1. Setup Input (Front Camera)
        // We use if-let instead of guard so we don't return early and leave things nil
        if let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
           let videoInput = try? AVCaptureDeviceInput(device: frontCamera) {
            
            if captureSession.canAddInput(videoInput) { captureSession.addInput(videoInput) }
        } else {
            print("⚠️ Camera not found. (Are you on Simulator?)")
        }
        
        // 2. Setup Microphone
        if let audioDevice = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: audioDevice) {
            if captureSession.canAddInput(audioInput) { captureSession.addInput(audioInput) }
        }

        // 3. Setup Output
        if captureSession.canAddOutput(videoOutput) { captureSession.addOutput(videoOutput) }

        // 4. Setup Preview
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        cameraCardView.layer.addSublayer(previewLayer)
        
        // Start Session
        DispatchQueue.global(qos: .background).async {
            self.captureSession.startRunning()
        }
    }

    // Replace your toggleRecording with this safer version:
    @IBAction func toggleRecording(_ sender: UIButton) {
        guard let connection = videoOutput.connection(with: .video), connection.isActive else { return }

        if videoOutput.isRecording {
            // STOP RECORDING
            videoOutput.stopRecording()
            updateButtonState(isRecording: false)
            stopTimer()
            
            // Trigger Haptic Feedback (Success feeling)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
        } else {
            // START RECORDING
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
            videoOutput.startRecording(to: tempURL, recordingDelegate: self)
            updateButtonState(isRecording: true)
            startTimer()
            
            // Trigger Haptic Feedback (Light tap for start)
            let generator = UIImpactFeedbackGenerator(style: .rigid)
            generator.impactOccurred()
        }
    }
    
    @IBAction func tapToMainScreen(_ sender: Any) {
        if let initialPresenter = self.navigationController?.presentingViewController {
                initialPresenter.dismiss(animated: true, completion: nil)
            }
    }
    
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

    func styleUI() {
        cameraCardView.layer.cornerRadius = 32
        cameraCardView.layer.cornerCurve = .continuous
        cameraCardView.clipsToBounds = true
        
        // Timer label styling
        durationLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 18, weight: .semibold)
        durationLabel.textColor = .white
        durationLabel.layer.shadowColor = UIColor.black.cgColor
        durationLabel.layer.shadowRadius = 2
        durationLabel.layer.shadowOpacity = 0.5
        durationLabel.layer.shadowOffset = .zero
        
        targetLabel.text = targetWord
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
    
    func saveVideoToDocuments(tempURL: URL) {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destinationURL = documentsURL.appendingPathComponent(tempURL.lastPathComponent)
        try? FileManager.default.moveItem(at: tempURL, to: destinationURL)
        print("Saved to: \(destinationURL)")
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
            guard error == nil else { return }
            
            let fileManager = FileManager.default
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            
            // Use a UUID for the filename to ensure it matches our JSON ID
            let fileID = UUID().uuidString
            let destinationURL = documentsURL.appendingPathComponent("\(fileID).mov")
            
            do {
                try fileManager.moveItem(at: outputFileURL, to: destinationURL)
                
                // Calculate final duration from our timer
                let finalDuration = Double(self.secondsRecorded)
                
                // Create and save the JSON metadata
                let newLog = VideoLog(id: fileID, heading: self.targetWord, date: Date(), duration: finalDuration)
                MetadataManager.shared.saveLog(newLog)
                
                print("Successfully saved video and metadata.")
                
            } catch {
                print("Error saving file: \(error)")
            }
        
    }
}
