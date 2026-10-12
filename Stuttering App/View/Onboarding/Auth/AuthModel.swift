//
//  AuthModel.swift
//  Spasht
//
//  Everything the SwiftUI sign-in and sign-up screens do once the user taps a
//  button: validation, the four providers (email, Apple, Google, guest), and
//  the local-database work that has to happen either side of them.
//
//  The screens themselves stay declarative — they own no logic beyond reading
//  the published state here — which is what lets one model back both of them.
//

import SwiftUI
import Combine
import Supabase
import GoogleSignIn
import AuthenticationServices

@MainActor
final class AuthModel: ObservableObject {

    // MARK: - Mode

    enum Mode: Hashable {
        case signIn
        case signUp

        var title: String {
            switch self {
            case .signIn: return "Welcome back"
            case .signUp: return "Create your account"
            }
        }

        var subtitle: String {
            switch self {
            case .signIn: return ""
            case .signUp: return ""
            }
        }

        var callToAction: String {
            switch self {
            case .signIn: return "Sign In"
            case .signUp: return "Create Account"
            }
        }

        var providerVerb: String {
            switch self {
            case .signIn: return "Sign in with"
            case .signUp: return "Sign up with"
            }
        }

        var switchPrompt: String {
            switch self {
            case .signIn: return "New to Spasht?"
            case .signUp: return "Already have an account?"
            }
        }

        var switchAction: String {
            switch self {
            case .signIn: return "Create one"
            case .signUp: return "Sign in"
            }
        }

        var other: Mode { self == .signIn ? .signUp : .signIn }
    }

    // MARK: - Published state

    @Published var mode: Mode
    @Published var name = ""
    @Published var email = ""
    @Published var password = ""
    @Published var showsPassword = false

    /// Non-nil while an authentication is in flight; the string is what the
    /// progress overlay says.
    @Published private(set) var busyMessage: String?

    @Published var alert: AuthAlert?
    @Published var isRequestingReset = false
    @Published var resetEmail = ""

    /// SwiftUI has no view controller of its own, and Google, Apple, Safari and
    /// the guest hand-off all need one to present from. Set by
    /// `AuthHostingController` as soon as it exists.
    weak var host: UIViewController?

    private let client = SupabaseManager.shared.client

    init(mode: Mode) {
        self.mode = mode
    }

    // MARK: - Derived state

    var isBusy: Bool { busyMessage != nil }

    /// Someone already in guest mode is here to upgrade that guest into a real
    /// account, so offering them guest mode again would be a loop.
    var offersGuestMode: Bool { !SessionManager.shared.isGuestMode }

    var canDismiss: Bool {
        guard let host else { return false }
        return host.presentingViewController != nil
            || (host.navigationController?.viewControllers.count ?? 0) > 1
    }

    var isFormComplete: Bool {
        let hasCredentials = !email.trimmed.isEmpty && !password.isEmpty
        switch mode {
        case .signIn: return hasCredentials
        case .signUp: return hasCredentials && !name.trimmed.isEmpty
        }
    }

    // MARK: - Navigation

    func switchMode() {
        withAnimation(.snappy) {
            mode = mode.other
            password = ""
            showsPassword = false
        }
    }

    func dismiss() {
        guard let host else { return }
        if host.presentingViewController != nil {
            host.dismiss(animated: true)
        } else {
            host.navigationController?.popViewController(animated: true)
        }
    }

    func continueAsGuest() {
        guard let host else { return }
        GuestEntry.start(from: host)
    }

    // MARK: - Legal links

    func openPrivacy() { if let host { LegalLinks.open(LegalLinks.privacyPolicy, from: host) } }
    func openTerms()   { if let host { LegalLinks.open(LegalLinks.termsOfUse, from: host) } }
    func openSupport() { if let host { LegalLinks.openSupport(from: host) } }

    // MARK: - Email + password

    func submit() {
        guard !isBusy else { return }
        switch mode {
        case .signIn: signInWithEmail()
        case .signUp: signUpWithEmail()
        }
    }

    private func signInWithEmail() {
        let email = self.email.trimmed
        guard !email.isEmpty, !password.isEmpty else {
            present(title: "Missing Fields", message: "Please fill in both email and password.")
            return
        }

        run("Signing you in") {
            do {
                try await self.client.auth.signIn(email: email, password: self.password)

                guard let userId = SupabaseManager.shared.currentUser?.id.uuidString else {
                    throw AuthModelError.noUserAfterSignIn
                }

                try await self.completeSignIn(userId: userId)
                AuthNavigator.finish(from: self.host)

            } catch {
                // Supabase reports a wrong password and an unknown address the
                // same way, so the message has to cover both without implying
                // which of the two it was.
                let message = error.localizedDescription.contains("credentials")
                    ? "Incorrect email or password. Please try again."
                    : error.localizedDescription
                self.present(title: "Sign In Failed", message: message)
            }
        }
    }

    private func signUpWithEmail() {
        let name = self.name.trimmed
        let email = self.email.trimmed

        guard !email.isEmpty, !password.isEmpty else {
            present(title: "Missing Fields", message: "Please fill in all fields.")
            return
        }
        guard !name.isEmpty else {
            present(title: "Missing Name", message: "Please enter your name.")
            return
        }
        guard AuthModel.isValidEmail(email) else {
            present(title: "Check Your Email", message: "Please enter a valid email address.")
            return
        }
        guard password.count >= 8 else {
            present(title: "Password Too Short",
                    message: "Your password must be at least 8 characters.")
            return
        }

        run("Creating your account") {
            do {
                let response = try await self.client.auth.signUp(
                    email: email,
                    password: self.password,
                    data: ["first_name": .string(name)]
                )

                // With email confirmation switched on in Supabase, `signUp`
                // returns no session and `currentUser` is nil. Nothing can be
                // pushed or synced until the user confirms, so stop here rather
                // than failing halfway through.
                guard SupabaseManager.shared.currentUser != nil else {
                    self.presentConfirmationPending(email: email)
                    return
                }

                // Use the id from the response, not LogManager's, which may
                // still be holding the guest id at this point.
                try await self.completeSignUp(userId: response.user.id.uuidString,
                                              displayName: name)
                AuthNavigator.finish(from: self.host)

            } catch {
                self.present(title: "Sign Up Failed", message: error.localizedDescription)
            }
        }
    }

    // MARK: - Sign in with Apple

    func signInWithApple() {
        guard let host, !isBusy else { return }

        run("Connecting with Apple") {
            do {
                let result = try await AppleSignInManager.shared.signIn(presentingFrom: host)

                try await self.completeOAuth(userId: result.supabaseUserId,
                                             displayName: result.fullName)

                // Apple hands the name over exactly once, on first
                // authorization, so it has to be persisted now or never.
                if let fullName = result.fullName {
                    await AppleSignInManager.shared.persistFirstAuthorizationName(
                        fullName, userId: result.supabaseUserId)
                }

                // Lets account deletion revoke the Apple grant later.
                if let code = result.authorizationCode {
                    await AccountDeletionService.shared.registerAppleAuthorizationCode(code)
                }

                AuthNavigator.finish(from: self.host)

            } catch AppleSignInManager.AppleSignInError.cancelled,
                    AppleSignInManager.AppleSignInError.alreadyInProgress {
                // Backing out of Apple's sheet is a choice, not a failure, and
                // a double-tap that lost the race isn't one either, so neither
                // gets an alert.
                ()

            } catch {
                self.present(title: "Sign in with Apple Failed",
                             message: error.localizedDescription)
            }
        }
    }

    // MARK: - Google

    func signInWithGoogle() {
        guard let host, !isBusy else { return }

        let rawNonce = AuthHelpers.randomNonceString()
        let hashedNonce = AuthHelpers.sha256(rawNonce)

        run("Connecting with Google") {
            do {
                let result = try await GIDSignIn.sharedInstance.signIn(
                    withPresenting: host,
                    hint: nil,
                    additionalScopes: nil,
                    nonce: hashedNonce
                )

                guard let idToken = result.user.idToken?.tokenString else {
                    throw AuthModelError.missingGoogleToken
                }

                _ = try await self.client.auth.signInWithIdToken(
                    credentials: .init(
                        provider: .google,
                        idToken: idToken,
                        accessToken: result.user.accessToken.tokenString,
                        nonce: rawNonce
                    )
                )

                guard let userId = SupabaseManager.shared.currentUser?.id.uuidString else {
                    throw AuthModelError.noUserAfterSignIn
                }

                try await self.completeOAuth(userId: userId,
                                             displayName: result.user.profile?.name)

                AuthNavigator.finish(from: self.host)

            } catch {
                self.present(title: "Google Sign-In Failed",
                             message: error.localizedDescription)
            }
        }
    }

    // MARK: - Password reset

    func beginPasswordReset() {
        resetEmail = email.trimmed
        isRequestingReset = true
    }

    func sendPasswordReset() {
        let address = resetEmail.trimmed
        guard !address.isEmpty else { return }

        Task {
            do {
                try await PasswordRecovery.sendResetEmail(to: address)
                present(title: "Email Sent",
                        message: "Check your inbox and tap the link — it opens Spasht so you can set a new password.")
            } catch {
                present(title: "Couldn't Send Email", message: error.localizedDescription)
            }
        }
    }

    // MARK: - Shared post-authentication

    /// Finishes a provider sign-in, on whichever path the account actually needs.
    ///
    /// "Sign up with Google" and "Sign in with Google" run the identical OAuth
    /// exchange — the provider hands back a session either way and never says
    /// which of the two it was. Branching on the button the user happened to
    /// tap is what sent a returning user back through onboarding: they pressed
    /// Sign Up, so their cloud data was never pulled down and
    /// `isOnboardingCompleted` stayed false. The button is ignored here and the
    /// account is asked instead.
    private func completeOAuth(userId: String, displayName: String?) async throws {
        if await accountAlreadyExists(userId: userId) {
            try await completeSignIn(userId: userId)
            // Sign-in doesn't carry a name, and a provider may be the only place
            // this account ever had one.
            applyDisplayNameIfMissing(displayName, userId: userId)
        } else {
            try await completeSignUp(userId: userId, displayName: displayName)
        }
    }

    /// True when this user has been here before.
    ///
    /// A profile row is written for every account the moment it is created, so
    /// its presence is the record of "this is not a first run".
    private func accountAlreadyExists(userId: String) async -> Bool {
        struct Row: Decodable { let id: String }
        do {
            let rows: [Row] = try await client
                .from("profiles")
                .select("id")
                .eq("id", value: userId)
                .limit(1)
                .execute()
                .value
            return !rows.isEmpty

        } catch {
            // When it can't be determined, take the returning-user path. It is
            // the safer of the two guesses: for a genuinely new account there
            // is simply nothing in the cloud to pull down, whereas guessing
            // "new" for a returning one replays onboarding over their history.
            print("⚠️ [AUTH] Couldn't check for an existing profile: \(error.localizedDescription)")
            return true
        }
    }

    private func applyDisplayNameIfMissing(_ displayName: String?, userId: String) {
        guard let displayName, !displayName.isEmpty else { return }

        var profile = LogManager.shared.getProfile(userId: userId)
            ?? UserProfile(id: userId, isOnboardingCompleted: AppState.isOnboardingCompleted)
        guard profile.firstName?.trimmed.isEmpty ?? true else { return }

        profile.firstName = displayName
        LogManager.shared.saveProfile(profile)
    }

    /// Everything that has to happen after an existing account authenticates,
    /// whichever provider it came from.
    ///
    /// Transactional: the local databases are reset before the user's data is
    /// pulled down, so a sync that throws halfway would otherwise leave someone
    /// signed in with nothing. A snapshot is taken first and put back on any
    /// failure, which leaves the device exactly as it was.
    private func completeSignIn(userId: String) async throws {
        // Guest data has to go up before anything is reset, and it is genuinely
        // destructive to retry, so it stays outside the transaction.
        if SessionManager.shared.isGuestMode {
            LogManager.shared.migrateGuestData(to: userId)
            try await SupabaseSyncManager.shared.pushAllLocalDataToCloud()
        }

        let previousMode = SessionManager.shared.currentMode
        let previousOnboarding = AppState.isOnboardingCompleted
        let snapshot = LocalDataSnapshot.capture()

        do {
            SessionManager.shared.startAccountSession(userId: userId)

            LogManager.shared.resetDatabaseForNewUser()
            DatabaseManager.shared.resetDatabaseForNewUser()
            AwardsManager.shared.resetDatabaseForNewUser()
            AppState.resetModuleOnboarding()
            LogManager.shared.initializeUserIfNeeded()

            AppState.isOnboardingCompleted = false

            try await SupabaseSyncManager.shared.syncAllDataFromCloud()

            // Restore cloud completions BEFORE checkForNewDay, so that it sees a
            // non-empty, partially-done list for today and leaves it alone
            // rather than wiping it and pushing blanks back up.
            await SupabaseSyncManager.shared.reapplyDailyTaskCompletions()

            let logic = LogicMaker()
            logic.checkForNewDay(isFromLogin: true)

            snapshot?.discard()

        } catch {
            snapshot?.restore()
            AppState.isOnboardingCompleted = previousOnboarding
            if previousMode == .guest {
                SessionManager.shared.startGuestSession()
            } else {
                await SessionManager.shared.endSession()
            }
            throw error
        }
    }

    /// The registration counterpart. Unlike signing in, this *pushes* local data
    /// up rather than pulling it down — a new account starts from whatever the
    /// user built in guest mode.
    ///
    /// `displayName` is applied only when the profile has no name yet, so a
    /// provider that gives us nothing can't blank out a real one.
    private func completeSignUp(userId: String, displayName: String?) async throws {
        SessionManager.shared.startAccountSession(userId: userId)
        LogManager.shared.initializeUserIfNeeded()
        LogManager.shared.migrateGuestData(to: userId)

        var profile = LogManager.shared.getProfile(userId: userId)
            ?? UserProfile(id: userId, isOnboardingCompleted: false)
        if let displayName, !displayName.isEmpty,
           profile.firstName?.trimmed.isEmpty ?? true {
            profile.firstName = displayName
        }
        LogManager.shared.saveProfile(profile)

        // Awaited so we only navigate once the data is safely in the cloud.
        try await SupabaseSyncManager.shared.pushAllLocalDataToCloud()
    }

    // MARK: - Plumbing

    /// Runs `work` with the progress overlay up, and takes the overlay down
    /// again however it ends.
    private func run(_ message: String, _ work: @escaping () async -> Void) {
        busyMessage = message
        Task {
            await work()
            busyMessage = nil
        }
    }

    private func present(title: String, message: String, actions: [AuthAlert.Action] = []) {
        alert = AuthAlert(title: title, message: message, actions: actions)
    }

    /// Shown when Supabase has email confirmation switched on, so registration
    /// finishes without a session. A bare "check your email" would be a dead
    /// end if the first mail never arrived, so both next steps are offered.
    private func presentConfirmationPending(email: String) {
        present(
            title: "Confirm Your Email",
            message: "We've sent a confirmation link to \(email). Tap it, then sign in.",
            actions: [
                AuthAlert.Action(title: "Resend Email") { [weak self] in
                    self?.resendConfirmation(to: email)
                },
                AuthAlert.Action(title: "Go to Sign In") { [weak self] in
                    self?.switchMode()
                }
            ]
        )
    }

    private func resendConfirmation(to email: String) {
        Task {
            do {
                try await client.auth.resend(email: email, type: .signup)
                present(title: "Sent Again",
                        message: "Check your inbox, and your spam folder.")
            } catch {
                present(title: "Couldn't Resend", message: error.localizedDescription)
            }
        }
    }

    static func isValidEmail(_ email: String) -> Bool {
        let pattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        return NSPredicate(format: "SELF MATCHES %@", pattern).evaluate(with: email)
    }

    enum AuthModelError: LocalizedError {
        case noUserAfterSignIn
        case missingGoogleToken

        var errorDescription: String? {
            switch self {
            case .noUserAfterSignIn:
                return "Signed in, but no account came back. Please try again."
            case .missingGoogleToken:
                return "Google didn't return an ID token. Please try again."
            }
        }
    }
}

// MARK: - Alert payload

/// A pending alert, carrying any extra buttons it needs beyond "OK".
struct AuthAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    var actions: [Action] = []

    struct Action: Identifiable {
        let id = UUID()
        let title: String
        let handler: () -> Void
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
