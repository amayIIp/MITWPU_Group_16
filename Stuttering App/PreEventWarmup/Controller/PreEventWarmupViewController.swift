//
//  PreEventWarmupViewController.swift
//  Stuttering App
//
//  Created by SDC-USER on 29/11/25.
//

import UIKit

class PreEventWarmupViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    // MARK: - Outlets
    @IBOutlet weak var tableView: UITableView!
    
    // MARK: - Data Source
    // We use the new model we created earlier
    var warmups: [WarmupEvent] = []

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Basic TableView Setup
        tableView.delegate = self
        tableView.dataSource = self
        
        // Fetch the data
        fetchWarmupsFromJSON()
    }
    
    // MARK: - Data Fetching
    private func fetchWarmupsFromJSON() {
        // Ensure you have a file named "event_warmup.json" in your project folder
        guard let url = Bundle.main.url(forResource: "event_warmup", withExtension: "json") else {
            print("Error: event_warmup.json not found.")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            self.warmups = try JSONDecoder().decode([WarmupEvent].self, from: data)
            DispatchQueue.main.async { self.tableView.reloadData() }
        } catch {
            print("Error parsing JSON: \(error)")
        }
    }

    // MARK: - TableView Methods
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return warmups.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // IMPORTANT: Ensure Storyboard Identifier is "WarmupCell" and Class is "WarmupCell"
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "WarmupCell", for: indexPath) as? WarmupCell else {
            return UITableViewCell()
        }

        let item = warmups[indexPath.row]
        
        // 1. Map Data to UI
        // Note: Your JSON uses 'name' and 'short_time', unlike 'title' and 'duration' in the other file
        cell.titleLabel.text = item.name
        cell.descriptionLabel.text = item.description
        cell.durationLabel.text = item.short_time
        
        // 2. Button Styling (Matches your commented-out code logic)
        // This ensures the button matches your app's blue theme
        cell.playButton.tintColor = .systemBlue
        cell.playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)

        return cell
    }
}
