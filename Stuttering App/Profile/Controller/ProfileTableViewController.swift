import UIKit

class ProfileTableViewController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    // MARK: - Table View Delegate (The Click Logic)
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        // 1. Deselect the row immediately for a clean effect
        tableView.deselectRow(at: indexPath, animated: true)

        // 2. Check which row was tapped (assuming Section 0)
        if indexPath.section == 0 {
            
            switch indexPath.row {
            case 0: // Row 0: "Profile"
                performSegue(withIdentifier: "goToEditProfile", sender: self)
                
            case 1: // Row 1: "Progress"
                // Placeholder for future implementation
                print("Progress tapped")
                
            case 2: // Row 2: "Set Goals"
                performSegue(withIdentifier: "goToSetGoals", sender: self)
                
            default:
                break
            }
        }
    }
    
    // MARK: - Prepare for Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        // Handling the Set Goals Screen
        if segue.identifier == "goToSetGoals" {
            // If you needed to pass current goals to the next screen, you would do it here.
            // let destVC = segue.destination as! SetGoalsViewController
            // destVC.exerciseCount = 20 (Example)
        }
        
        // Handling the Profile Screen
        if segue.identifier == "goToEditProfile" {
            // Pass profile data if needed
        }
    }
}
