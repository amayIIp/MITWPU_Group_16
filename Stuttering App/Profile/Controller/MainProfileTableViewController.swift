import UIKit

class MainProfileTableViewController: UITableViewController {

    // MARK: - Outlets
    // Connect these to your Text Fields in Storyboard
    @IBOutlet weak var firstNameField: UITextField!
    @IBOutlet weak var lastNameField: UITextField!
    @IBOutlet weak var dobField: UITextField!
    @IBOutlet weak var mobileField: UITextField!
    @IBOutlet weak var emailField: UITextField!
    
    // Connect this to your Bar Button Item
    @IBOutlet weak var editButton: UIBarButtonItem!

    // MARK: - Properties
        let datePicker = UIDatePicker()
        var isEditingProfile = false

        // MARK: - Lifecycle
        override func viewDidLoad() {
            super.viewDidLoad()
            setupInitialView()
            setupDatePicker()
        }

        // MARK: - Setup Methods
        func setupInitialView() {
            let allFields = [firstNameField, lastNameField, dobField, mobileField, emailField]
            
            // Initial State: Look like labels, read-only
            for field in allFields {
                field?.isEnabled = false
                field?.textColor = .secondaryLabel
                field?.borderStyle = .none
                field?.backgroundColor = .clear
                field?.textAlignment = .right
            }
            
            // Initial Button State: Text "Edit"
            editButton.title = "Edit"
            editButton.image = nil
        }

        func setupDatePicker() {
            // 1. Configure Wheel Style
            datePicker.datePickerMode = .date
            datePicker.preferredDatePickerStyle = .wheels
            datePicker.maximumDate = Date()
            
            // 2. Attach to Text Field
            // NOTE: We removed the toolbar ("Done" button) as requested.
            // The user just scrolls the wheel, and it updates automatically.
            dobField.inputView = datePicker
            
            // 3. Handle Date Change Live
            datePicker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)
        }

        // MARK: - Actions
    
    // Connect this to your Edit Bar Button Item
    @IBAction func toggleEditing(_ sender: UIBarButtonItem) {
        isEditingProfile.toggle()
                
                let allFields = [firstNameField, lastNameField, dobField, mobileField, emailField]
                
                UIView.animate(withDuration: 0.3) {
                    if self.isEditingProfile {
                        // === EDIT MODE ON ===
                        
                        // 1. Change Button to Checkmark Icon
                        self.editButton.title = nil
                        self.editButton.image = UIImage(systemName: "checkmark")
                        
                        // 2. Unlock Fields
                        for field in allFields {
                            field?.isEnabled = true
                            field?.textColor = .label         // Dark text
                            field?.borderStyle = .none        // No borders
                        }
                        
                        // 3. Focus First Field
                        self.firstNameField.becomeFirstResponder()
                        
                    } else {
                        // === SAVE CHANGES (Clicking Checkmark) ===
                        
                        // 1. Change Button back to "Edit" Text
                        self.editButton.image = nil
                        self.editButton.title = "Edit"
                        
                        // 2. Lock Fields
                        for field in allFields {
                            field?.isEnabled = false
                            field?.textColor = .secondaryLabel // Grey text
                            field?.borderStyle = .none
                        }
                        
                        // 3. Close Keyboard/Picker and Save
                        self.view.endEditing(true)
                        self.saveData()
                    }
                }
            }

            @objc func dateChanged() {
                let formatter = DateFormatter()
                formatter.dateFormat = "d MMM yyyy" // Example: "9 Sep 2004"
                dobField.text = formatter.string(from: datePicker.date)
            }
            
            func saveData() {
                // This runs when you click the Checkmark
                print("Saving Data... Name: \(firstNameField.text ?? "") DOB: \(dobField.text ?? "")")
                
                // Add your UserDefaults or Database save logic here
            }
        }
