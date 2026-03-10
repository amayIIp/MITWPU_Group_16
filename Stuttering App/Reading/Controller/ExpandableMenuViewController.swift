//
//  ExpandableMenuViewController.swift
//  Stuttering Final
//
//  Created by SDC-USER on 10/02/26.
//

import UIKit

class ExpandableMenuViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    weak var delegate: WorkoutSheetDelegate?

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var DafButton: UIButton!
    
    let categories = ["Science", "Space", "Astronomy", "Mindset", "Sports"]
    
    let categoryContent = [
        "Science is the systematic study of the structure and behavior of the physical and natural world.",
        "Space is the boundless three-dimensional extent in which objects and events have relative position and direction.",
        "Astronomy is the study of everything in the universe beyond Earth's atmosphere.",
        "Mindset is a set of assumptions, methods, or notions held by one or more people.",
        "Sports are physical activities that involve skill and competition."
    ]
    
    var currentDAFDelay: Double = 0.0
    
    enum AppSelection {
        case randomHeader
        case specificCategory(Int)
        case custom
    }
    
    var activeSection: Int = 0
    var currentSelection: AppSelection = .randomHeader
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        setupMainHeader()
        setupButtons()
        configureMenu()
        
        activeSection = 0
        currentSelection = .randomHeader
    }
    
    private func setupButtons() {
        DafButton.configuration = .glass()
        DafButton.setImage(UIImage(systemName: "ear.badge.checkmark"), for: .normal)
        
    }

    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.sectionHeaderTopPadding = 0
        tableView.separatorStyle = .none
    }
    
    private func setupMainHeader() {
        let headerHeight: CGFloat = 40
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: headerHeight))
        
        let titleLabel = UILabel()
        titleLabel.text = "What would you like to read?"
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 36),
            titleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -0)
        ])
        tableView.tableHeaderView = headerView
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if indexPath.row == 0 {
            let newActiveSection = (activeSection == 0) ? 1 : 0
            
            toggleSection(to: newActiveSection)
            
            if newActiveSection == 0 {
                currentSelection = .randomHeader
            } else {
                currentSelection = .custom
            }
            
            tableView.reloadData()
        }
        
        else if indexPath.section == 0 {
            let categoryIndex = indexPath.row - 1
            currentSelection = .specificCategory(categoryIndex)
            tableView.reloadData()
        }
    }
    
    @IBAction func didTapContinueButton(_ sender: UIButton) {
        view.endEditing(true)
        
        var topicToGenerate = ""
        
        switch currentSelection {
            
        case .randomHeader:
             let validPresets = presetTitles.filter { $0 != "Custom" }
             topicToGenerate = validPresets.randomElement() ?? "General"
            
        case .specificCategory(let index):
             if index < categories.count {
                 topicToGenerate = categories[index]
             } else {
                 topicToGenerate = "General"
             }
            
        case .custom:
            
            let customIndexPath = IndexPath(row: 1, section: 1)
            
            if let cell = tableView.cellForRow(at: customIndexPath) as? CustomWorkspaceCell,
               let text = cell.inputTextView.text {
                
                let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
    
                if trimmedText.isEmpty || trimmedText.count < 50 {
                    showEmptyInputAlert()
                    return
                }
                
                showDetailScreen(title: "Custom Story", text: trimmedText)
                return
            } else {
                showEmptyInputAlert()
                return
            }

       }
        generateAIStory(topic: topicToGenerate)
    }
    
    func generateAIStory(topic: String) {
        print("DEBUG: Generating AI Story for topic: \(topic)")
        let troubledLetters = LogManager.shared.getTopStruggledLetters(limit: 5)
        
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.center = self.view.center
        activityIndicator.color = .gray
        activityIndicator.hidesWhenStopped = true
        self.view.addSubview(activityIndicator)
        activityIndicator.startAnimating()
        self.view.isUserInteractionEnabled = false
        
        Task {
            do {
                let story = try await withThrowingTaskGroup(of: String.self) { group in
                    group.addTask {
                        let result = try await AIParagraphGenerator.shared.generate(for: troubledLetters, topic: topic)
                         print("DEBUG: Generated Story Length: \(result.count)")
                         return result
                    }
                    
                    group.addTask {
                        try await Task.sleep(nanoseconds: 30 * 1_000_000_000)
                        throw NSError(domain: "Timeout", code: -1, userInfo: [NSLocalizedDescriptionKey: "AI Generation Timed Out"])
                    }
                    
                    guard let result = try await group.next() else {
                        throw NSError(domain: "Error", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown Error"])
                    }
                    group.cancelAll()
                    return result
                }
                
                await MainActor.run {
                    print("DEBUG: AI Generation Success.")
                    activityIndicator.stopAnimating()
                    activityIndicator.removeFromSuperview()
                    self.view.isUserInteractionEnabled = true
                    
                    self.showDetailScreen(title: topic, text: story)
                }

            } catch {
                print("Note: Switching to Dynamic Mode (Fallback) due to: \(error.localizedDescription)")
                await MainActor.run {
                    activityIndicator.stopAnimating()
                    activityIndicator.removeFromSuperview()
                    self.view.isUserInteractionEnabled = true
                    
                    let fallbackContent = self.getFallbackContent(for: topic)
                    
                    let phonemeFallback = PhonemeContent.generateLongFormContent(for: troubledLetters)
                    self.showDetailScreen(title: topic, text: phonemeFallback)
                }
            }
        }
    }
    
    func getFallbackContent(for topic: String) -> String {
        let normalized = topic.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        if let index = presetTitles.firstIndex(where: { $0.lowercased() == normalized }) {
            if index < presetContent.count { return presetContent[index] }
        }
        
        if normalized.contains("space") || normalized.contains("moon") || normalized.contains("star") || normalized.contains("planet") {
             if let index = presetTitles.firstIndex(of: "Science"), index < presetContent.count { return presetContent[index] }
        }
        
        if normalized.contains("fest") || normalized.contains("party") || normalized.contains("celebrat") {
             if let index = presetTitles.firstIndex(of: "Festival"), index < presetContent.count { return presetContent[index] }
        }
        
        if normalized.contains("happy") || normalized.contains("sad") || normalized.contains("mind") || normalized.contains("think") {
             if let index = presetTitles.firstIndex(of: "Mindset"), index < presetContent.count { return presetContent[index] }
        }

        if let randomContent = presetContent.filter({ !$0.isEmpty }).randomElement() {
            return randomContent
        }
        
        return "Science is a systematic enterprise that builds and organizes knowledge in the form of testable explanations and predictions about the universe."
    }

    func showDetailScreen(title: String, text: String) {
        guard let detailVC = storyboard?.instantiateViewController(withIdentifier: "DetailVC") as? DetailViewController else { return }
        
        detailVC.textToDisplay = text
        detailVC.titleToDisplay = title
        detailVC.initialDAFDelay = currentDAFDelay

        let detailNav = UINavigationController(rootViewController: detailVC)
        detailNav.modalPresentationStyle = .fullScreen
        self.present(detailNav, animated: true, completion: nil)
    }
    
    
    func showEmptyInputAlert() {
        let alert = UIAlertController(title: "Invalid Input", message: "Please enter at least 50 characters.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func animateChevron(at indexPath: IndexPath, isExpanding: Bool) {
        guard let cell = tableView.cellForRow(at: indexPath),
              let chevronView = cell.accessoryView?.viewWithTag(999) as? UIImageView else { return }
        
        UIView.animate(withDuration: 0.35, delay: 0, options: .curveEaseInOut) {
            chevronView.transform = isExpanding ? CGAffineTransform(rotationAngle: .pi / 2) : .identity
        }
    }
    
    private func toggleSection(to newSection: Int) {
        let randomPaths = (1...categories.count).map { IndexPath(row: $0, section: 0) }
        let customPath = [IndexPath(row: 1, section: 1)]
        
        activeSection = newSection
        
        tableView.performBatchUpdates({
            if newSection == 0 {
                self.tableView.insertRows(at: randomPaths, with: .fade)
                self.tableView.deleteRows(at: customPath, with: .fade)
            } else {
                self.tableView.insertRows(at: customPath, with: .fade)
                self.tableView.deleteRows(at: randomPaths, with: .fade)
            }
        }, completion: nil)
        
        tableView.reloadRows(at: [IndexPath(row: 0, section: 0), IndexPath(row: 0, section: 1)], with: .none)
    }

    func numberOfSections(in tableView: UITableView) -> Int { return 2 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 { return (activeSection == 0) ? (1 + categories.count) : 1 }
        else { return (activeSection == 1) ? 2 : 1 }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if indexPath.section == 0 {
            if indexPath.row == 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "HeaderCell", for: indexPath)
                configureHeaderCell(cell, title: "Random", section: 0)
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "OptionCell", for: indexPath)
                let categoryIndex = indexPath.row - 1
                var content = cell.defaultContentConfiguration()
                content.text = categories[categoryIndex]
                
                let isSelected: Bool
                if case .specificCategory(let index) = currentSelection, index == categoryIndex { isSelected = true } else { isSelected = false }
                
                let imageName = isSelected ? "circle.fill" : "circle"
                let image = UIImage(systemName: imageName)

                content.image = image
                content.imageProperties.tintColor = isSelected ? .buttonTheme : .systemGray3

                cell.contentView.backgroundColor = .secondarySystemGroupedBackground
                cell.contentConfiguration = content
                return cell
            }
        } else {
            if indexPath.row == 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "HeaderCell", for: indexPath)
                configureHeaderCell(cell, title: "Custom", section: 1)
                return cell
            } else {
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "CustomWorkspaceCell", for: indexPath) as? CustomWorkspaceCell else {
                    return UITableViewCell()
                }
                
                return cell
            }
        }
    }
    
    private func configureHeaderCell(_ cell: UITableViewCell, title: String, section: Int) {
        var content = cell.defaultContentConfiguration()
        content.text = title
        
        let isSelected: Bool
        if section == 0 { if case .randomHeader = currentSelection { isSelected = true } else { isSelected = false } }
        else { if case .custom = currentSelection { isSelected = true } else { isSelected = false } }
        
        let imageName = isSelected ? "circle.fill" : "circle"
        let image = UIImage(systemName: imageName)

        content.image = image
        content.imageProperties.tintColor = isSelected ? .buttonTheme : .systemGray3

        cell.contentView.backgroundColor = .secondarySystemGroupedBackground
        cell.contentConfiguration = content
        
        let isExpanded = (activeSection == section)
        let chevronImageView = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevronImageView.tintColor = .systemGray
        chevronImageView.contentMode = .scaleAspectFit
        chevronImageView.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
        chevronImageView.tag = 999
        chevronImageView.transform = isExpanded ? CGAffineTransform(rotationAngle: .pi / 2) : .identity
        cell.accessoryView = chevronImageView
    }
    
    func configureMenu() {
        let offAction = UIAction(title: "Off", state: currentDAFDelay == 0 ? .on : .off) { [weak self] _ in
            self?.currentDAFDelay = 0
            self?.delegate?.didUpdateDAFDelay(0)
            self?.configureMenu()
        }
        
        let delayOptions = [0.05, 0.1, 0.25, 0.5, 0.75, 1.0, 1.5]
        
        let menuActions = delayOptions.map { delay in
            UIAction(title: "\(delay)s", state: delay == currentDAFDelay ? .on : .off) { [weak self] action in
                self?.currentDAFDelay = delay
                self?.delegate?.didUpdateDAFDelay(delay)
                self?.configureMenu()
            }
        }
        
        let delaysMenu = UIMenu(options: .displayInline, children: menuActions)
        
        let menu = UIMenu(
            title: "DAF plays your voice back to you with a slight delay to help improve speech fluency.",
            image: UIImage(systemName: "speedometer"),
            children: [offAction, delaysMenu]
        )
        
        DafButton.menu = menu
        DafButton.showsMenuAsPrimaryAction = true
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { return 8 }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? { let v = UIView(); v.backgroundColor = .clear; return v }
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { return .leastNonzeroMagnitude }
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? { return nil }
}
