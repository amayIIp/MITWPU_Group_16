import UIKit

class GuestGateViewController: UIViewController {

    @IBOutlet weak var nameLabel: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadUserName()
    }
    
    func setupUI() {
        let closeItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(dismissModal))
        navigationItem.leftBarButtonItem = closeItem
        navigationItem.title = "Account Required"
    }
    
    @objc func dismissModal() {
        dismiss(animated: true, completion: nil)
    }
    
    private func loadUserName() {
        if let name = StorageManager.shared.getName() {
            nameLabel.text = "\(name)"
        } else {
            nameLabel.text = "User"
        }
    }

    @IBAction func loginButtonTapped(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Onboarding", bundle: nil)
        let loginVC = storyboard.instantiateViewController(withIdentifier: "LoginVC")
        
        navigationController?.pushViewController(loginVC, animated: true)
    }

    @IBAction func signUpButtonTapped(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Onboarding", bundle: nil)
        let signUpVC = storyboard.instantiateViewController(withIdentifier: "SignUpVC")
        
        navigationController?.pushViewController(signUpVC, animated: true)
    }
}
