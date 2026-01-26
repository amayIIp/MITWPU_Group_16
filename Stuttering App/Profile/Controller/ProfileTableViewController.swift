import UIKit

class ProfileTableViewController: UITableViewController {
    
    @IBOutlet weak var nameLabel: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadUserName()
    }
    
    private func loadUserName() {
        if let name = StorageManager.shared.getName() {
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
        
        AppState.isLoginCompleted = false
        AppState.isOnboardingCompleted = false
        
        let storyboard = UIStoryboard(name: "Onboarding", bundle: nil)
        
        guard let landingNav = storyboard.instantiateViewController(withIdentifier: "LandingNav") as? UINavigationController else {
            print("Error: Could not find LandingNav")
            return
        }
        
        if let sceneDelegate = view.window?.windowScene?.delegate as? SceneDelegate,
           let window = sceneDelegate.window {
            UIView.transition(with: window, duration: 0.5, options: .transitionCrossDissolve, animations: {
                window.rootViewController = landingNav
            }, completion: nil)
        }
    }
    
}
