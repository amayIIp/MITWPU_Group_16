import UIKit
import Supabase

class MainProfileTableViewController: UITableViewController {

    @IBOutlet weak var firstNameField: UITextField!
    @IBOutlet weak var lastNameField: UITextField!
    @IBOutlet weak var dobField: UITextField!
    @IBOutlet weak var mobileField: UITextField!
    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var editButton: UIBarButtonItem!

    let datePicker = UIDatePicker()
    var isEditingProfile = false
    
    private var allFields: [UITextField] {
        return [firstNameField, lastNameField, dobField, mobileField, emailField]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupInitialView()
        setupDatePicker()
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

    func setupDatePicker() {
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .wheels
        datePicker.maximumDate = Date()
        
        dobField.inputView = datePicker
        datePicker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)
    }

    private func loadData() {
        if let userId = LogManager.shared.getCurrentUserId(),
           let profile = LogManager.shared.getProfile(userId: userId) {
            firstNameField.text = profile.firstName
            lastNameField.text  = profile.lastName
            mobileField.text    = profile.mobile
            dobField.text       = profile.dob
        }
        emailField.text = SupabaseManager.shared.client.auth.currentUser?.email
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
            profile.lastName = lastNameField.text
            profile.mobile = mobileField.text
            profile.dob = dobField.text
            
            LogManager.shared.saveProfile(profile)
            
            SupabaseSyncManager.shared.pushProfileUpdate(key: "first_name", value: profile.firstName ?? "")
            SupabaseSyncManager.shared.pushProfileUpdate(key: "last_name", value: profile.lastName ?? "")
            SupabaseSyncManager.shared.pushProfileUpdate(key: "mobile", value: profile.mobile ?? "")
            SupabaseSyncManager.shared.pushProfileUpdate(key: "dob", value: profile.dob ?? "")
        }
        
        // Note: Updating email via Supabase Auth requires a separate API call (updateUser)
        // which sends a confirmation email. It is omitted here for simplicity unless requested.
        
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

    @objc func dateChanged() {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        dobField.text = formatter.string(from: datePicker.date)
    }
}
