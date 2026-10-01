import UIKit
import Supabase

class ProfileTableViewController: UITableViewController {

    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var profileImageView: UIImageView!

    /// Circular crop, matching the profile screen. The photo is only *edited*
    /// one screen along, but it would look broken shown as a stock symbol here.
    private let avatarMask = CAShapeLayer()

    override func viewDidLoad() {
        super.viewDidLoad()
        installLegalLinks()
        profileImageView?.layer.mask = avatarMask

        NotificationCenter.default.addObserver(
            self, selector: #selector(loadProfileImage),
            name: AvatarStore.didChangeNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadUserName()
        loadProfileImage()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        guard let profileImageView else { return }
        let bounds = profileImageView.bounds
        let side = min(bounds.width, bounds.height)
        guard side > 0 else { return }

        avatarMask.path = UIBezierPath(ovalIn: CGRect(x: bounds.midX - side / 2,
                                                      y: bounds.midY - side / 2,
                                                      width: side, height: side)).cgPath
    }

    @objc private func loadProfileImage() {
        guard let profileImageView else { return }

        if let photo = AvatarStore.circularImage(for: LogManager.shared.getCurrentUserId(),
                                                 diameter: AvatarStore.headerDiameter) {
            profileImageView.image = photo
            profileImageView.contentMode = .scaleAspectFit
        } else {
            profileImageView.image = UIImage(systemName: "person.circle.fill")
            profileImageView.contentMode = .scaleAspectFit
            profileImageView.tintColor = UIColor(named: "ButtonThemeMain")
        }
        view.setNeedsLayout()
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

    // MARK: - Legal links (Guideline 5.1.1(i))

    /// Adds "Privacy Policy · Terms · Support" beneath the Log Out button.
    ///
    /// Signed-in users reach these here. Guests never see this screen, so the
    /// same row is also added to the sign-up sheet — see
    /// `SignUpViewController.installLegalLinks()`.
    private func installLegalLinks() {
        guard let footer = tableView.tableFooterView else { return }

        let row = LegalLinks.makeLinkRow(
            target: self,
            privacyAction: #selector(openPrivacy),
            termsAction: #selector(openTerms),
            supportAction: #selector(openSupport)
        )
        footer.addSubview(row)

        let bottomMost = footer.subviews
            .filter { $0 !== row }
            .max { $0.frame.maxY < $1.frame.maxY }

        NSLayoutConstraint.activate([
            row.centerXAnchor.constraint(equalTo: footer.centerXAnchor),
            row.topAnchor.constraint(
                equalTo: bottomMost?.bottomAnchor ?? footer.topAnchor, constant: 4)
        ])

        var frame = footer.frame
        frame.size.height += 44
        footer.frame = frame
        tableView.tableFooterView = footer
    }

    @objc private func openPrivacy() { LegalLinks.open(LegalLinks.privacyPolicy, from: self) }
    @objc private func openTerms()   { LegalLinks.open(LegalLinks.termsOfUse, from: self) }
    @objc private func openSupport() { LegalLinks.openSupport(from: self) }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    // MARK: - AI coaching (Guideline 5.1.2(i))

    /// Where a user can withdraw — or give — permission to share with Groq.
    ///
    /// The table is static, so this section is added in code after the
    /// storyboard's own sections. Every data-source method a static table
    /// answers from the storyboard is overridden for it, because asking the
    /// storyboard about a section it doesn't have is an out-of-range crash.
    private var aiSection: Int { super.numberOfSections(in: tableView) }

    private lazy var aiSwitch: UISwitch = {
        let toggle = UISwitch()
        toggle.addTarget(self, action: #selector(aiSwitchChanged), for: .valueChanged)
        return toggle
    }()

    override func numberOfSections(in tableView: UITableView) -> Int {
        super.numberOfSections(in: tableView) + 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == aiSection ? 1 : super.tableView(tableView, numberOfRowsInSection: section)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard indexPath.section == aiSection else {
            return super.tableView(tableView, cellForRowAt: indexPath)
        }
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        var content = cell.defaultContentConfiguration()
        content.text = "AI Coaching"
        content.image = UIImage(systemName: "sparkles")
        content.imageProperties.tintColor = UIColor(named: "ButtonThemeMain") ?? .tintColor
        cell.contentConfiguration = content
        cell.selectionStyle = .none
        aiSwitch.isOn = AIConsent.isGranted
        cell.accessoryView = aiSwitch
        return cell
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        indexPath.section == aiSection
            ? UITableView.automaticDimension
            : super.tableView(tableView, heightForRowAt: indexPath)
    }

    override func tableView(_ tableView: UITableView, indentationLevelForRowAt indexPath: IndexPath) -> Int {
        indexPath.section == aiSection ? 0 : super.tableView(tableView, indentationLevelForRowAt: indexPath)
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == aiSection ? nil : super.tableView(tableView, titleForHeaderInSection: section)
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        section == aiSection ? AIConsent.settingsFooter : super.tableView(tableView, titleForFooterInSection: section)
    }

    // The static data source serves header and footer *views* from the
    // storyboard too; without these two, laying out the new section throws
    // NSRangeException the moment the Settings sheet appears.
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        section == aiSection ? nil : super.tableView(tableView, viewForHeaderInSection: section)
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        section == aiSection ? nil : super.tableView(tableView, viewForFooterInSection: section)
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        section == aiSection ? UITableView.automaticDimension : super.tableView(tableView, heightForHeaderInSection: section)
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        section == aiSection ? UITableView.automaticDimension : super.tableView(tableView, heightForFooterInSection: section)
    }

    @objc private func aiSwitchChanged() {
        guard aiSwitch.isOn else {
            AIConsent.set(.declined)
            return
        }
        // Turning it on is giving permission, so it gets the full disclosure
        // rather than flipping silently. Backing out leaves the switch off.
        aiSwitch.setOn(false, animated: false)
        AIConsent.requestPermission(from: self) { [weak self] granted in
            self?.aiSwitch.setOn(granted, animated: true)
        }
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
