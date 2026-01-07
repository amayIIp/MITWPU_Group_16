//
//  LibraryTableViewController.swift
//  Stuttering Final
//
//  Created by Prathamesh Patil on 17/12/25.
//

import UIKit

class LibraryTableViewController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Deselect the row immediately for a premium iOS feel
        tableView.deselectRow(at: indexPath, animated: true)

        // Logic for specific rows
        switch (indexPath.section, indexPath.row) {
            
        case (0, 0):
            
            let storyboard = UIStoryboard(name: "Exercise", bundle: nil)
            guard let VC = storyboard.instantiateViewController(withIdentifier: "AirFlowInstruction") as? ExerciseInstructionViewController else { return }
            
            let ResultNav = UINavigationController(rootViewController: VC)
            ResultNav.modalPresentationStyle = .fullScreen
            self.present(ResultNav, animated: true, completion: nil)
            
        case (1, 0):
            let storyboard = UIStoryboard(name: "Exercise", bundle: nil)
            guard let VC = storyboard.instantiateViewController(withIdentifier: "GentleOnset") as? GentleOnsetsViewController else { return }
                        
            VC.startingSource = .exercises
            let ResultNav = UINavigationController(rootViewController: VC)
            ResultNav.modalPresentationStyle = .fullScreen
            self.present(ResultNav, animated: true, completion: nil)
            
        case(1, 2):
            let storyboard = UIStoryboard(name: "Exercise", bundle: nil)
            guard let VC = storyboard.instantiateViewController(withIdentifier: "Prolongation") as? ProlongationViewController else { return }
                        
            VC.startingSource = .exercises
            let ResultNav = UINavigationController(rootViewController: VC)
            ResultNav.modalPresentationStyle = .fullScreen
            self.present(ResultNav, animated: true, completion: nil)
            
        default:
            break
        }
    }
    
    override func tableView(_ tableView: UITableView,
                            viewForHeaderInSection section: Int) -> UIView? {

        var config = UIListContentConfiguration.header()
        
        if section == 0 {
            config.text = "Speech Fundamentals"
        } else if section == 1 {
            config.text = "Targeted Practice"
        } else if section == 2 {
            config.text = "Correction & Refinement"
        }
        config.textProperties.font = .systemFont(ofSize: 20, weight: .semibold)
        config.textProperties.color = .black

        let header = UITableViewHeaderFooterView()
        header.contentConfiguration = config
        return header
    }
    
    @IBAction func unwindToMainMenu(_ segue: UIStoryboardSegue) {
    }

}
