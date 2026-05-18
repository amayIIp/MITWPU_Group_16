import UIKit
import Supabase

class MainProfileTableViewController: UITableViewController {

    @IBOutlet weak var firstNameField: UITextField!
    // @IBOutlet weak var lastNameField: UITextField! // Commented Out
    // @IBOutlet weak var dobField: UITextField!      // Commented Out
    @IBOutlet weak var mobileField: UITextField!
    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var editButton: UIBarButtonItem!

    // let datePicker = UIDatePicker() // Commented Out
    var isEditingProfile = false

    private var allFields: [UITextField] {
        // Updated to only include active fields
        return [firstNameField, mobileField, emailField]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupInitialView()
        // setupDatePicker() // Commented Out
        loadData()
        loadUserName()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadData()
    }

    func setupInitialView() {
        for field in allFields {
            field.isEnabled = false
            field.textColor = .secondaryLabel
            field.borderStyle = .none
            field.backgroundColor = .clear
            field.textAlignment = .right
        }

        editButton.title = "Edit"
        editButton.image = nil
    }

    /* Commented Out Date Picker Setup
    func setupDatePicker() {
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .wheels
        datePicker.maximumDate = Date()

        dobField.inputView = datePicker
        datePicker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)
    }
    */

    private func loadData() {
        if let userId = LogManager.shared.getCurrentUserId(),
           let profile = LogManager.shared.getProfile(userId: userId) {
            firstNameField.text = profile.firstName
            // lastNameField.text  = profile.lastName // Commented Out
            mobileField.text    = profile.mobile
            // dobField.text       = profile.dob      // Commented Out
        }
        emailField.text = SessionManager.shared.isAccountMode
            ? SupabaseManager.shared.client.auth.currentUser?.email
            : "Guest Mode"
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

    private func saveData() {
        if let userId = LogManager.shared.getCurrentUserId() {
            var profile = LogManager.shared.getProfile(userId: userId) ?? UserProfile(id: userId, isOnboardingCompleted: true)

            profile.firstName = firstNameField.text
            // profile.lastName = lastNameField.text // Commented Out
            profile.mobile = mobileField.text
            // profile.dob = dobField.text           // Commented Out

            LogManager.shared.saveProfile(profile)
        }

        loadUserName()
        NotificationCenter.default.post(name: NSNotification.Name("ProfileDataUpdated"), object: nil)
    }

    @IBAction func toggleEditing(_ sender: UIBarButtonItem) {
        isEditingProfile.toggle()

        UIView.animate(withDuration: 0.3) {
            if self.isEditingProfile {

                self.editButton.title = nil
                self.editButton.image = UIImage(systemName: "checkmark")

                for field in self.allFields {
                    field.isEnabled = true
                    field.textColor = .label
                }

                self.firstNameField.becomeFirstResponder()

            } else {
                self.editButton.image = nil
                self.editButton.title = "Edit"

                for field in self.allFields {
                    field.isEnabled = false
                    field.textColor = .secondaryLabel
                    field.backgroundColor = .clear
                }

                self.view.endEditing(true)
                self.saveData()
            }
        }
    }

    /* Commented Out Date Change Logic
    @objc func dateChanged() {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        dobField.text = formatter.string(from: datePicker.date)
    }
    */
}
