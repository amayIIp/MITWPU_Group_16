import UIKit

class FirstPageAnimationViewController: UIViewController {

    @IBOutlet weak var headerLabel: UIImageView!
    @IBOutlet weak var infoLabel: UIStackView!
    @IBOutlet weak var buttonView: UIView! // This is your card
    
    @IBOutlet weak var SignUpButton: UIButton!
    @IBOutlet weak var SigninButton: UIButton!
    
    var hasSetInitialState = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Hide everything initially
        headerLabel.alpha = 0
        infoLabel.alpha = 0
        buttonView.alpha = 0
    }
        
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if !hasSetInitialState {
            setupInitialState()
            hasSetInitialState = true
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startSequenceAnimation()
    }
    
    private func setupInitialState() {
        headerLabel.alpha = 1

        let screenCenterY = view.bounds.midY
        let labelCenterY = headerLabel.center.y

        let distanceToCenter = screenCenterY - labelCenterY
        let moveDown = CGAffineTransform(translationX: 0, y: distanceToCenter)
        let scaleUp = CGAffineTransform(scaleX: 2.0, y: 2.0)

        // Header starts large and centered
        headerLabel.transform = scaleUp.concatenating(moveDown)
        
        // Card starts invisible and slightly offset if you still want a subtle slide,
        // otherwise, just let alpha handle the dissolve.
        buttonView.transform = CGAffineTransform(translationX: 0, y: 20)
    }

    private func startSequenceAnimation() {
        // 1. Animate Header to top
        UIView.animate(withDuration: 1.8,
                       delay: 0.2,
                       usingSpringWithDamping: 0.85,
                       initialSpringVelocity: 0.5,
                       options: .curveEaseInOut) {
            
            self.headerLabel.transform = .identity
            
        } completion: { _ in

            // 2. Dissolve in the Info Text and the Card together
            UIView.animate(withDuration: 1.5,
                           delay: 0.1,
                           options: .curveEaseInOut) {
                
                self.infoLabel.alpha = 1.0
                
                // Card dissolve animation
                self.buttonView.alpha = 1.0
                self.buttonView.transform = .identity // Clears the small 20pt offset
            }
        }
    }

    // MARK: - Button Actions
    
    @IBAction func signUpTapped(_ sender: UIButton) {
        presentModal(identifier: "SignUpViewController")
    }
    
    @IBAction func signInTapped(_ sender: UIButton) {
        presentModal(identifier: "LoginViewController")
    }
    
    private func presentModal(identifier: String) {
        let storyboard = UIStoryboard(name: "Onboarding", bundle: nil)
        let nextModalVC = storyboard.instantiateViewController(withIdentifier: identifier)
        
        // 1. Wrap your destination in a Navigation Controller
        let navController = UINavigationController(rootViewController: nextModalVC)
        
        // 2. Enable Large Titles on the Navigation Bar
        navController.navigationBar.prefersLargeTitles = true
        
        // 3. Configure the Sheet (Modal) behavior
        navController.modalPresentationStyle = .pageSheet // Explicitly use pageSheet for the "card" look
        if let sheet = navController.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        
        present(navController, animated: true)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.destination is OnboardingNameViewController {
            // Nuke any stale data from previous accounts before starting fresh
            LogManager.shared.resetDatabaseForNewUser()
            DatabaseManager.shared.resetDatabaseForNewUser()
            AwardsManager.shared.resetDatabaseForNewUser()
            
            SessionManager.shared.startGuestSession()
            LogManager.shared.initializeGuestUser()
        }
    }
}
