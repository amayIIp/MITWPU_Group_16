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
        if let userId = LogManager.shared.getCurrentUserId(),
           let profile = LogManager.shared.getProfile(userId: userId),
           let name = profile.firstName {
            nameLabel.text = "\(name)"
        } else {
            nameLabel.text = "User"
        }
    }

    @IBAction func loginButtonTapped(_ sender: UIButton) {
        guard let navigationController else { return }
        AuthScreens.push(.signIn, onto: navigationController)
    }

    @IBAction func signUpButtonTapped(_ sender: UIButton) {
        guard let navigationController else { return }
        AuthScreens.push(.signUp, onto: navigationController)
    }
}
