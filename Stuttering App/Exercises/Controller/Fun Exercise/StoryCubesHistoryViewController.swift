//
//  StoryCubesHistoryViewController.swift
//  Stuttering Final
//
//  Created by SDC-USER on 18/02/26.
//

import UIKit
import AVKit

class StoryCubesHistoryViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var tableView: UITableView!
    
    var audioLogs: [AudioLog] = []

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
    
    // MARK: - Play Audio
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let log = audioLogs[indexPath.row]
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let audioURL = documentsURL.appendingPathComponent("\(log.id).m4a")
        
        // 1. Force the audio session to Playback mode (Main Speaker)
        do {
            let session = AVAudioSession.sharedInstance()
            // .playback ensures audio goes to the main speaker and continues if the silent switch is on
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("⚠️ Failed to set audio to speaker: \(error.localizedDescription)")
        }

        // 2. Setup Player
        let player = AVPlayer(url: audioURL)
        let playerVC = AVPlayerViewController()
        playerVC.player = player
        
        // 3. Present and Play
        present(playerVC, animated: true) {
            player.play()
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
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
