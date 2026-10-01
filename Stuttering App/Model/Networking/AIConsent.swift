//
//  AIConsent.swift
//  Spasht
//
//  Guideline 5.1.2(i): "You must clearly disclose where personal data will be
//  shared with third parties, including with third-party AI, and obtain
//  explicit permission before doing so."
//
//  Spasht's AI features send practice stats and conversation transcripts to
//  Groq. This records whether the signed-in user has agreed to that, and
//  `GroqService.isAvailable` refuses every call until they have. Every Groq
//  call site already falls back to on-device or rule-based text, so "no" costs
//  the user nothing but conversation practice on iPhones without Apple
//  Intelligence, where the partner has no on-device model to run on.
//

import UIKit

enum AIConsent {

    enum Choice: String {
        case granted
        case declined
    }

    /// Posted when the choice changes, so open screens can react.
    static let didChangeNotification = Notification.Name("AIConsent.didChange")

    private static let keyPrefix = "ai.consent."

    /// Consent belongs to a person, not a device, so it is keyed by account.
    /// Lowercased because `UUID.uuidString` is uppercase and Postgres is not —
    /// the same id must never map to two keys.
    private static var key: String? {
        guard SessionManager.shared.isAccountMode,
              let userId = SessionManager.shared.currentUserId else { return nil }
        return keyPrefix + userId.lowercased()
    }

    /// The signed-in user's choice, or nil if they haven't been asked.
    static var choice: Choice? {
        guard let key, let raw = UserDefaults.standard.string(forKey: key) else { return nil }
        return Choice(rawValue: raw)
    }

    static var isGranted: Bool { choice == .granted }

    /// True when the user should be asked: signed in and never answered.
    static var needsPrompt: Bool { key != nil && choice == nil }

    static func set(_ choice: Choice) {
        guard let key else { return }
        UserDefaults.standard.set(choice.rawValue, forKey: key)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    /// Removes every stored choice. Called on account deletion — the keys
    /// contain the user id, and nothing identifying should survive a deletion.
    static func removeAll() {
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(keyPrefix) {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: - Disclosure

    static let title = "Use AI coaching?"

    /// Names the provider and says exactly what is sent. Kept in one place so
    /// the prompt and the Settings footer can never disagree.
    static let disclosure = """
        Spasht can use Groq, a third-party AI service, to write feedback on your \
        practice and to be your conversation partner.

        If you allow this, Spasht sends Groq your practice results (such as \
        scores and words you found difficult) and the text of what you say in \
        conversation practice. Your voice recordings are never sent.

        If you don't, Spasht uses only what runs on your iPhone, so conversation \
        practice needs an iPhone with Apple Intelligence. You can change this \
        anytime in Settings.
        """

    static let settingsFooter = """
        When on, your practice results and what you say in conversation \
        practice are sent to Groq, a third-party AI service, to write feedback \
        and reply to you. Voice recordings are never sent. When off, Spasht \
        uses only what runs on your iPhone, so conversation practice needs an \
        iPhone with Apple Intelligence.
        """

    // MARK: - Prompt

    /// Asks for permission. `completion` receives the user's answer after it
    /// has been stored.
    static func requestPermission(from presenter: UIViewController,
                                  completion: ((Bool) -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: disclosure, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Not Now", style: .cancel) { _ in
            set(.declined)
            completion?(false)
        })
        let allow = UIAlertAction(title: "Allow", style: .default) { _ in
            set(.granted)
            completion?(true)
        }
        alert.addAction(allow)
        alert.preferredAction = allow
        presenter.present(alert, animated: true)
    }
}
