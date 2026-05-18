import UIKit
import Supabase

class ProfileTableViewController: UITableViewController {

    @IBOutlet weak var nameLabel: UILabel!

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadUserName()
    }

    private func loadUserName() {
        if let userId = LogManager.shared.getCurrentUserId(),
           let profile = LogManager.shared.getProfile(userId: userId),
           let name = profile.firstName {
            nameLabel.text = "\(name)"
        } else {
            nameLabel.text = "User"
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    @IBAction func logoutButtonTapped(_ sender: UIButton) {
        let alert = UIAlertController(title: "Log Out", message: "Are you sure?", preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Log Out", style: .destructive) { _ in
            self.performLogout()
        })

        self.present(alert, animated: true, completion: nil)
    }

    func performLogout() {
        Task {
            // endSession handles the Supabase signOut internally
            await SessionManager.shared.endSession()

            await MainActor.run {
                let storyboard = UIStoryboard(name: "Onboarding", bundle: nil)

                guard let landingNav = storyboard.instantiateViewController(withIdentifier: "LandingNav") as? UINavigationController else {
                    print("Error: Could not find LandingNav")
                    return
                }

                if let sceneDelegate = self.view.window?.windowScene?.delegate as? SceneDelegate,
                   let window = sceneDelegate.window {
                    UIView.transition(with: window, duration: 0.5, options: .transitionCrossDissolve, animations: {
                        window.rootViewController = landingNav
                    }, completion: nil)
                }

                self.clearAllAppData()
            }
        }
    }

    private func clearAllAppData() {
        print("--- Initiating Complete Session Teardown ---")

        // Reset module onboarding flags so next session starts fresh
        AppState.resetModuleOnboarding()

        // Wipe and reboot all SQLite databases
        LogManager.shared.resetDatabaseForNewUser()
        DatabaseManager.shared.resetDatabaseForNewUser()
        AwardsManager.shared.resetDatabaseForNewUser()

        print("--- Teardown Complete. Ready for next session. ---")
    }
}
