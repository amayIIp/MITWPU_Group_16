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

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
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
    
    @IBAction func unwindToMainMenu(_ segue: UIStoryboardSegue) {
    }

    /*
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "reuseIdentifier", for: indexPath)

        // Configure the cell...

        return cell
    }
    */

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
