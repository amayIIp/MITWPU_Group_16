import UIKit

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
        firstNameField.text = StorageManager.shared.getName()
        lastNameField.text  = StorageManager.shared.getLastName()
        mobileField.text    = StorageManager.shared.getMobNo()
        emailField.text     = StorageManager.shared.getEmail()
        dobField.text       = StorageManager.shared.getDob()
    }
    
    private func loadUserName() {
        if let name = StorageManager.shared.getName() {
            nameLabel.text = "\(name)"
        } else {
            nameLabel.text = "User"
        }
    }
    
    private func saveData() {
        StorageManager.shared.saveName(firstNameField.text ?? "")
        StorageManager.shared.saveLastName(lastNameField.text ?? "")
        StorageManager.shared.saveMobNo(mobileField.text ?? "")
        StorageManager.shared.saveEmail(emailField.text ?? "")
        StorageManager.shared.saveDob(dobField.text ?? "")
        
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
