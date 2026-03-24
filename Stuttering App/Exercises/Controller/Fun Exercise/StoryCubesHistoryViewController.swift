//
//  StoryCubesHistoryViewController.swift
//  Stuttering Final
//
//  Created by SDC-USER on 18/02/26.
//

import UIKit
import AVKit

class StoryCubesHistoryViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UIAdaptivePresentationControllerDelegate {

    @IBOutlet weak var tableView: UITableView!
    
    var audioLogs: [AudioLog] = []
    // MARK: - Properties (add at top of class)
    private var audioPlayer: AVPlayer?
    private var playerObserver: Any?
    private var playerTimeObserver: Any?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // ✅ FIX: Audio session activation blocks the main thread for ~1 second
        // on first call. Moving it to a background queue eliminates the freeze
        // when navigating to this screen for the first time.
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default, policy: .longFormAudio)
                try session.setActive(true)
            } catch {
                print("⚠️ Failed to set audio session: \(error.localizedDescription)")
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        audioLogs = AudioMetadataManager.shared.loadLogs()
        tableView.reloadData()
        updateEmptyState()
    }

    // MARK: - TableView DataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return audioLogs.count
    }
    
    // MARK: - Modern Empty State Management
    func updateEmptyState() {
        if audioLogs.isEmpty {
            // Use modern iOS UIContentUnavailableConfiguration
            var config = UIContentUnavailableConfiguration.empty()
            config.image = UIImage(systemName: "waveform.slash")
            config.text = "No Voice Logs"
            config.secondaryText = "Your recorded diary entries will appear here."
            
            self.contentUnavailableConfiguration = config
            tableView.isHidden = true
        } else {
            self.contentUnavailableConfiguration = nil
            tableView.isHidden = false
        }
    }

    // MARK: - Cell Configuration
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "AudioHistoryCell", for: indexPath) as? AudioHistoryCell else {
            return UITableViewCell()
        }
        
        let log = audioLogs[indexPath.row]
        
        cell.headingLabel.text = log.heading
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        cell.dateLabel.text = formatter.string(from: log.date)
        
        let minutes = Int(log.duration) / 60
        let seconds = Int(log.duration) % 60
        cell.durationLabel.text = String(format: "%02d:%02d", minutes, seconds)
        
        return cell
    }
    
    // MARK: - Play Audio (Replace the entire didSelectRowAt)
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let log = audioLogs[indexPath.row]
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let audioURL = documentsURL.appendingPathComponent("\(log.id).m4a")

        // ✅ FIX: Build AVPlayer entirely on a background thread.
        // AVPlayerItem status resolution and asset loading are blocking
        // operations — keeping them off the main thread eliminates the freeze.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let asset = AVURLAsset(url: audioURL)
            let item = AVPlayerItem(asset: asset)
            let player = AVPlayer(playerItem: item)
            player.automaticallyWaitsToMinimizeStalling = false

            DispatchQueue.main.async {
                self.audioPlayer = player
                self.presentAudioPlayerSheet(for: log, player: player)
            }
        }
    }
    
    // MARK: - Custom Audio Player Bottom Sheet
    private func presentAudioPlayerSheet(for log: AudioLog, player: AVPlayer) {

        // --- 1. Build the Sheet Container ---
        let sheet = UIViewController()
        sheet.view.backgroundColor = .systemGroupedBackground

        if let presentationController = sheet.sheetPresentationController {
            presentationController.detents = [.medium()]
            presentationController.prefersGrabberVisible = true
            presentationController.preferredCornerRadius = 24
        }

        // --- 2. Header: Title + Date ---
        let titleLabel = UILabel()
        titleLabel.text = log.heading.isEmpty ? "Voice Recording" : log.heading
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.textColor = .label

        let dateLabel = UILabel()
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        dateLabel.text = formatter.string(from: log.date)
        dateLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        dateLabel.textColor = .secondaryLabel
        dateLabel.textAlignment = .center

        // --- 3. Waveform Icon (audio identity) ---
        let waveformConfig = UIImage.SymbolConfiguration(pointSize: 48, weight: .thin)
        let waveformImage = UIImageView(image: UIImage(systemName: "waveform", withConfiguration: waveformConfig))
        waveformImage.tintColor = .systemBlue
        waveformImage.contentMode = .scaleAspectFit

        // --- 4. Duration / Scrubber Labels ---
        let currentTimeLabel = UILabel()
        currentTimeLabel.text = "00:00"
        currentTimeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        currentTimeLabel.textColor = .secondaryLabel

        let totalTimeLabel = UILabel()
        let totalMins = Int(log.duration) / 60
        let totalSecs = Int(log.duration) % 60
        totalTimeLabel.text = String(format: "%02d:%02d", totalMins, totalSecs)
        totalTimeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        totalTimeLabel.textColor = .secondaryLabel

        let scrubber = UISlider()
        scrubber.minimumValue = 0
        scrubber.maximumValue = Float(log.duration)
        scrubber.value = 0
        scrubber.tintColor = .systemBlue

        // --- 5. Play / Pause Button ---
        var playConfig = UIButton.Configuration.filled()
        playConfig.baseBackgroundColor = .systemBlue
        playConfig.baseForegroundColor = .white
        playConfig.cornerStyle = .capsule
        let playIconConfig = UIImage.SymbolConfiguration(pointSize: 28, weight: .bold)
        playConfig.image = UIImage(systemName: "play.fill", withConfiguration: playIconConfig)
        playConfig.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)

        let playPauseButton = UIButton(configuration: playConfig)

        // --- 6. Time Observer (updates scrubber + currentTimeLabel) ---
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        playerTimeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak scrubber, weak currentTimeLabel] time in
            let secs = Int(CMTimeGetSeconds(time))
            let mins = secs / 60
            currentTimeLabel?.text = String(format: "%02d:%02d", mins, secs % 60)
            scrubber?.value = Float(CMTimeGetSeconds(time))
        }

        // End-of-playback: reset to beginning
        playerObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak player, weak playPauseButton] _ in
            player?.seek(to: .zero)
            var resetConfig = playPauseButton?.configuration
            resetConfig?.image = UIImage(systemName: "play.fill", withConfiguration: playIconConfig)
            playPauseButton?.configuration = resetConfig
        }

        // --- 7. Scrubber Action ---
        scrubber.addAction(UIAction { _ in
            let seekTime = CMTime(seconds: Double(scrubber.value), preferredTimescale: 600)
            player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }, for: .valueChanged)

        // --- 8. Play/Pause Action ---
        playPauseButton.addAction(UIAction { [weak playPauseButton] _ in
            if player.timeControlStatus == .playing {
                player.pause()
                var cfg = playPauseButton?.configuration
                cfg?.image = UIImage(systemName: "play.fill", withConfiguration: playIconConfig)
                playPauseButton?.configuration = cfg
            } else {
                player.play()
                var cfg = playPauseButton?.configuration
                cfg?.image = UIImage(systemName: "pause.fill", withConfiguration: playIconConfig)
                playPauseButton?.configuration = cfg
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }, for: .touchUpInside)

        // --- 9. Layout ---
        let timeRow = UIStackView(arrangedSubviews: [currentTimeLabel, UIView(), totalTimeLabel])
        timeRow.axis = .horizontal
        timeRow.distribution = .fill

        let stack = UIStackView(arrangedSubviews: [
            waveformImage,
            titleLabel,
            dateLabel,
            scrubber,
            timeRow,
            playPauseButton
        ])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 14
        stack.setCustomSpacing(6, after: titleLabel)
        stack.setCustomSpacing(24, after: waveformImage)
        stack.setCustomSpacing(4, after: scrubber)
        stack.setCustomSpacing(20, after: timeRow)
        stack.translatesAutoresizingMaskIntoConstraints = false

        // scrubber and timeRow must stretch full width
        scrubber.translatesAutoresizingMaskIntoConstraints = false
        timeRow.translatesAutoresizingMaskIntoConstraints = false

        sheet.view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: sheet.view.topAnchor, constant: 32),
            stack.leadingAnchor.constraint(equalTo: sheet.view.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: sheet.view.trailingAnchor, constant: -28),

            scrubber.widthAnchor.constraint(equalTo: stack.widthAnchor),
            timeRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            waveformImage.heightAnchor.constraint(equalToConstant: 64)
        ])

        // --- 10. Cleanup on dismiss ---
        sheet.presentationController?.delegate = self

        present(sheet, animated: true) {
            // ✅ Play AFTER the sheet is fully presented — eliminates black frame flash
            player.play()
            var cfg = playPauseButton.configuration
            cfg?.image = UIImage(systemName: "pause.fill", withConfiguration: playIconConfig)
            playPauseButton.configuration = cfg
        }
    }
    
    // MARK: - Cleanup on Sheet Dismiss
    // Add UIAdaptivePresentationControllerDelegate conformance to the class declaration:
    // class StoryCubesHistoryViewController: UIViewController,
    //     UITableViewDataSource, UITableViewDelegate,
    //     UIAdaptivePresentationControllerDelegate

    @objc func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        audioPlayer?.pause()

        if let observer = playerTimeObserver {
            audioPlayer?.removeTimeObserver(observer)
            playerTimeObserver = nil
        }
        if let observer = playerObserver {
            NotificationCenter.default.removeObserver(observer)
            playerObserver = nil
        }
        audioPlayer = nil
    }
    
    // MARK: - Delete Audio
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let log = audioLogs[indexPath.row]
            
            // 1. Delete JSON entry
            AudioMetadataManager.shared.deleteLog(id: log.id)
            
            // 2. Delete actual .m4a file
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let audioURL = documentsURL.appendingPathComponent("\(log.id).m4a")
            try? FileManager.default.removeItem(at: audioURL)
            
            // 3. Update UI
            audioLogs.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
            
            // 4. Update state
            updateEmptyState()
        }
    }
}
