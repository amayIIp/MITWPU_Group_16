import UIKit
import AVKit

class VideoHistoryViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var tableView: UITableView!
    
    // Data source is now driven by JSON
    var videoLogs: [VideoLog] = []

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Reload data every time the view appears to catch new recordings
        videoLogs = MetadataManager.shared.loadLogs()
        tableView.reloadData()
        
        updateEmptyState()
    }

    // MARK: - TableView DataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return videoLogs.count
    }
    
    // MARK: - Empty State Management
    func updateEmptyState() {
        if videoLogs.isEmpty {
            // Create the "No Recordings" label
            let emptyLabel = UILabel(frame: CGRect(x: 0, y: 0, width: tableView.bounds.size.width, height: tableView.bounds.size.height))
            emptyLabel.text = "No Recordings"
            emptyLabel.textColor = .tertiaryLabel // iOS 26 style: soft, subtle text
            emptyLabel.textAlignment = .center
            emptyLabel.font = UIFont.systemFont(ofSize: 20, weight: .medium)
            
            // Apply to the table view
            tableView.backgroundView = emptyLabel
            tableView.separatorStyle = .none
        } else {
            // Remove the label and restore separators when data exists
            tableView.backgroundView = nil
            tableView.separatorStyle = .singleLine
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "HistoryCell", for: indexPath) as? HistoryCell else {
            return UITableViewCell()
        }
        
        let log = videoLogs[indexPath.row]
        
        // 1. Instantly load JSON text data
        cell.headingLabel.text = log.heading
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        cell.dateLabel.text = formatter.string(from: log.date)
        
        let minutes = Int(log.duration) / 60
        let seconds = Int(log.duration) % 60
        cell.durationLabel.text = String(format: "%02d:%02d", minutes, seconds)
        
        // 2. Clear previous thumbnail before async load
        cell.thumbnailImageView.image = nil
        
        // 3. Load thumbnail using the ID
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let videoURL = documentsURL.appendingPathComponent("\(log.id).mov")
        
        Task {
            if let thumbnail = await fetchThumbnail(for: videoURL) {
                if tableView.indexPath(for: cell) == indexPath {
                    cell.thumbnailImageView.image = thumbnail
                }
            }
        }
        
        return cell
    }
    
    // MARK: - Async Thumbnail Helper
    func fetchThumbnail(for url: URL) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        do {
            let time = CMTime(seconds: 0.0, preferredTimescale: 600)
            let (cgImage, _) = try await imageGenerator.image(at: time)
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }
    
    // MARK: - Play Video
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let log = videoLogs[indexPath.row]
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let videoURL = documentsURL.appendingPathComponent("\(log.id).mov")
        
        let player = AVPlayer(url: videoURL)
        let playerVC = AVPlayerViewController()
        playerVC.player = player
        present(playerVC, animated: true) { player.play() }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }

    // MARK: - Delete Video
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let log = videoLogs[indexPath.row]
            
            // 1. Delete JSON entry
            MetadataManager.shared.deleteLog(id: log.id)
            
            // 2. Delete actual .mov file
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let videoURL = documentsURL.appendingPathComponent("\(log.id).mov")
            try? FileManager.default.removeItem(at: videoURL)
            
            // 3. Update UI
            videoLogs.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
            
            // 4. Check if that was the last video and show empty state
            updateEmptyState()
        }
    }
}
// Helper extension for sorting by date
extension URL {
    var creationDate: Date {
        return (try? resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
    }
}
