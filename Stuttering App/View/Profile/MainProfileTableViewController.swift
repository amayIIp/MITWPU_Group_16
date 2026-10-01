import UIKit
import Supabase
import PhotosUI

class MainProfileTableViewController: UITableViewController {

    @IBOutlet weak var firstNameField: UITextField!
    // @IBOutlet weak var lastNameField: UITextField! // Commented Out
    // @IBOutlet weak var dobField: UITextField!      // Commented Out
    @IBOutlet weak var mobileField: UITextField!
    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var editButton: UIBarButtonItem!
    @IBOutlet weak var deleteAccount: UIButton!
    @IBOutlet weak var profileImageView: UIImageView!
    

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
        setupDeleteAccountButton()
        setupProfileImage()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        pinDeleteButtonToBottom()
        layoutProfileImage()
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
    // MARK: - Profile photo

    /// Circular crop for whatever the image view's frame happens to be. Masking
    /// a centred circle rather than setting `cornerRadius` keeps it round even
    /// though the storyboard frame isn't square.
    private let avatarMask = CAShapeLayer()

    private lazy var photoBadge: UIView = makePhotoBadge()

    private func setupProfileImage() {
        guard let profileImageView else { return }

        profileImageView.isUserInteractionEnabled = true
        profileImageView.layer.mask = avatarMask
        profileImageView.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(editPhotoTapped)))

        profileImageView.isAccessibilityElement = true
        profileImageView.accessibilityTraits = .button
        profileImageView.accessibilityLabel = "Profile photo"
        profileImageView.accessibilityHint = "Double tap to change your photo"

        tableView.tableHeaderView?.addSubview(photoBadge)

        NotificationCenter.default.addObserver(
            self, selector: #selector(profileImageChanged),
            name: AvatarStore.didChangeNotification, object: nil)

        loadProfileImage()
    }

    private func loadProfileImage() {
        guard let profileImageView else { return }

        if let photo = AvatarStore.circularImage(for: LogManager.shared.getCurrentUserId(),
                                                 diameter: AvatarStore.headerDiameter) {
            profileImageView.image = photo
            profileImageView.contentMode = .scaleAspectFit
        } else {
            // The symbol already draws its own circle, and it lands exactly
            // inside the mask, so the two placeholders agree.
            profileImageView.image = UIImage(systemName: "person.circle.fill")
            profileImageView.contentMode = .scaleAspectFit
            profileImageView.tintColor = UIColor(named: "ButtonThemeMain")
        }
        view.setNeedsLayout()
    }

    @objc private func profileImageChanged() {
        loadProfileImage()
    }

    private func layoutProfileImage() {
        guard let profileImageView else { return }

        let bounds = profileImageView.bounds
        let side = min(bounds.width, bounds.height)
        guard side > 0 else { return }

        let circle = CGRect(x: bounds.midX - side / 2,
                            y: bounds.midY - side / 2,
                            width: side, height: side)
        avatarMask.path = UIBezierPath(ovalIn: circle).cgPath

        // The badge is a sibling in the header, not a subview of the masked
        // image view, or the mask would cut it in half. Sat at 45° so it rides
        // the edge of the circle rather than the corner of the frame.
        guard let header = tableView.tableHeaderView, photoBadge.superview === header else { return }
        let inHeader = header.convert(circle, from: profileImageView)
        let offset = side / 2 * 0.707
        photoBadge.center = CGPoint(x: inHeader.midX + offset, y: inHeader.midY + offset)
    }

    private func makePhotoBadge() -> UIView {
        let badge = UIView(frame: CGRect(x: 0, y: 0, width: 34, height: 34))
        badge.backgroundColor = UIColor(named: "ButtonThemeMain") ?? .tintColor
        badge.layer.cornerRadius = 17
        badge.layer.borderWidth = 3
        badge.layer.borderColor = (UIColor(named: "bg") ?? .systemBackground).cgColor
        badge.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(editPhotoTapped)))
        badge.isAccessibilityElement = false

        let icon = UIImageView(image: UIImage(systemName: "camera.fill"))
        icon.tintColor = .white
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(icon)

        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 14)
        ])
        return badge
    }

    @objc private func editPhotoTapped() {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            sheet.addAction(UIAlertAction(title: "Take Photo", style: .default) { [weak self] _ in
                self?.presentCamera()
            })
        }
        sheet.addAction(UIAlertAction(title: "Choose Photo", style: .default) { [weak self] _ in
            self?.presentPhotoLibrary()
        })
        if AvatarStore.hasImage(for: LogManager.shared.getCurrentUserId()) {
            sheet.addAction(UIAlertAction(title: "Remove Photo", style: .destructive) { [weak self] _ in
                self?.removePhoto()
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        // An action sheet without an anchor is fatal on iPad.
        sheet.popoverPresentationController?.sourceView = profileImageView
        sheet.popoverPresentationController?.sourceRect = profileImageView?.bounds ?? .zero

        present(sheet, animated: true)
    }

    /// PHPicker runs out of process, so it needs no photo-library permission and
    /// the app never sees the rest of the library.
    private func presentPhotoLibrary() {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func presentCamera() {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraDevice = .front
        picker.allowsEditing = false
        picker.delegate = self
        present(picker, animated: true)
    }

    /// Both sources land here first: nothing is saved until the user has framed it.
    private func presentCropper(with image: UIImage) {
        let cropper = AvatarCropViewController(image: image) { [weak self] cropped in
            self?.applyPhoto(cropped)
        }

        let nav = UINavigationController(rootViewController: cropper)
        nav.modalPresentationStyle = .fullScreen

        // The picker may still be dismissing when its image arrives, and
        // presenting into that gap is a no-op with a console warning.
        if let presented = presentedViewController {
            presented.dismiss(animated: true) { [weak self] in
                self?.present(nav, animated: true)
            }
        } else {
            present(nav, animated: true)
        }
    }

    private func applyPhoto(_ image: UIImage) {
        guard let userId = LogManager.shared.getCurrentUserId() else { return }
        AvatarStore.save(image, for: userId)
        loadProfileImage()
    }

    private func removePhoto() {
        guard let userId = LogManager.shared.getCurrentUserId() else { return }
        AvatarStore.remove(for: userId)
        loadProfileImage()
    }

    // MARK: - Delete Account (Guideline 5.1.1(v))

    /// Apple expects deletion to be easy to find. From the home screen this is
    /// profile icon -> Profile -> the button at the bottom, which is two taps.
    ///
    /// Guest mode has no account and no cloud footprint - its data lives in the
    /// app container, which iOS removes with the app - so there is nothing for
    /// the button to delete and it is hidden rather than shown as a dead end.
    private func setupDeleteAccountButton() {
        guard let deleteAccount else { return }
        deleteAccount.isHidden = !SessionManager.shared.isAccountMode
        deleteAccount.accessibilityIdentifier = "deleteAccountButton"
    }

    /// Keeps Delete Account at the bottom of the screen.
    ///
    /// A table footer view is laid out immediately after the last row, so on a
    /// short table it floats mid-screen. The button is pinned to the footer's
    /// bottom edge in the storyboard, so growing the footer to absorb whatever
    /// height the rows leave over pushes the button down to the bottom of the
    /// visible table - no second view floating above the scroll view.
    private func pinDeleteButtonToBottom() {
        guard let footer = tableView.tableFooterView else { return }

        // Nothing but the button lives down there, so the footer collapses to a
        // plain bottom margin when the button is hidden (guest mode).
        let minimum: CGFloat = (deleteAccount?.isHidden ?? true)
            ? 16
            : (deleteAccount?.bounds.height ?? 51) + 56

        let insets = tableView.adjustedContentInset
        let visibleHeight = tableView.bounds.height - insets.top - insets.bottom
        let heightAboveFooter = tableView.contentSize.height - footer.frame.height

        // On a table too long to fit, the leftover is negative and the footer
        // falls back to `minimum` - the button then scrolls up with the rows.
        let target = max(minimum, visibleHeight - heightAboveFooter)

        // Re-assigning the footer triggers another layout pass, so only do it
        // when the change is worth a pass - otherwise this never settles.
        guard abs(target - footer.frame.height) > 0.5 else { return }
        footer.frame.size.height = target
        tableView.tableFooterView = footer
    }

    @IBAction func deleteAccountPressed(_ sender: Any) {
        AccountDeletionFlow.start(from: self) { [weak self] in
            guard let self else { return }
            AccountDeletionFlow.returnToLanding(from: self)
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

// MARK: - Photo pickers

extension MainProfileTableViewController: PHPickerViewControllerDelegate {

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else { return }

        provider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            guard let image = object as? UIImage else {
                print("⚠️ [AVATAR] Couldn't read the picked image: \(error?.localizedDescription ?? "unknown")")
                return
            }
            DispatchQueue.main.async { self?.presentCropper(with: image) }
        }
    }
}

extension MainProfileTableViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        if let image = info[.originalImage] as? UIImage {
            presentCropper(with: image)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}
