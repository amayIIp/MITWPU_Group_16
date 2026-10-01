//
//  AppleSignInManager.swift
//  Spasht
//
//  Native Sign in with Apple, exchanged for a Supabase session.
//
//  Required by App Store Review Guideline 4.8: an app offering a third-party
//  login (Google, here) must also offer a login service that limits collection
//  to name and email, lets the user withhold their email, and does not collect
//  app interactions for advertising. Sign in with Apple qualifies.
//
//  The nonce handling mirrors the Google flow: Apple embeds SHA-256(nonce) in
//  the identity token and Supabase recomputes that digest from the raw value we
//  hand it, so the two paths stay readable side by side.
//

import AuthenticationServices
import Supabase
import UIKit

/// What a completed Apple authorization gives us.
struct AppleSignInResult {
    let supabaseUserId: String

    /// Apple returns the name only on the *first* authorization for a given
    /// Apple ID + app pair. It is nil on every later sign-in, so whatever we
    /// get here has to be persisted immediately — there is no second chance.
    let fullName: String?

    /// Exchanged server-side for a refresh token, which account deletion later
    /// revokes. Apple requires revocation as part of guideline 5.1.1(v).
    /// The code is single-use and expires in about five minutes, so it has to
    /// be handed over now rather than stored for deletion time.
    let authorizationCode: String?
}

@MainActor
final class AppleSignInManager: NSObject {

    static let shared = AppleSignInManager()
    private override init() { super.init() }

    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?
    private weak var anchorWindow: UIWindow?

    /// Guards against a second authorization starting while one is in flight.
    /// Two triggers are attached to the button (see `installButton`), and a
    /// double-tap would otherwise start two requests and strand a continuation.
    private var isAuthorizing = false

    enum AppleSignInError: LocalizedError {
        case missingIdentityToken
        case noUserAfterSignIn
        case cancelled
        case alreadyInProgress
        case notSignedIntoApple
        case appleUnavailable

        var errorDescription: String? {
            switch self {
            case .missingIdentityToken:
                return "Apple didn't return an identity token. Please try again."
            case .noUserAfterSignIn:
                return "Signed in with Apple, but no account was created. Please try again."
            case .cancelled:
                return "Sign in with Apple was cancelled."
            case .alreadyInProgress:
                return "Sign in with Apple is already under way."
            case .notSignedIntoApple:
                return "You're not signed in to an Apple Account on this device. Sign in from Settings, then try again."
            case .appleUnavailable:
                return "Apple couldn't complete the sign-in right now. Please try again, or use another sign-in option."
            }
        }
    }

    // MARK: - Sign-in

    /// Runs the native Apple flow and trades the identity token for a Supabase
    /// session. Throws `.cancelled` when the user backs out, so callers can
    /// stay silent instead of showing a failure alert.
    func signIn(presentingFrom viewController: UIViewController) async throws -> AppleSignInResult {
        guard !isAuthorizing else { throw AppleSignInError.alreadyInProgress }
        isAuthorizing = true
        defer { isAuthorizing = false }

        let rawNonce = AuthHelpers.randomNonceString()
        anchorWindow = viewController.view.window

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = AuthHelpers.sha256(rawNonce)

        let credential: ASAuthorizationAppleIDCredential = try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }

        guard let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            throw AppleSignInError.missingIdentityToken
        }

        _ = try await SupabaseManager.shared.client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: rawNonce)
        )

        guard let userId = SupabaseManager.shared.currentUser?.id.uuidString else {
            throw AppleSignInError.noUserAfterSignIn
        }

        let name = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)

        return AppleSignInResult(
            supabaseUserId: userId,
            fullName: name.isEmpty ? nil : name,
            authorizationCode: credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
        )
    }

    /// Persists the name Apple gave us on first authorization, locally and in
    /// Supabase user metadata. Does not overwrite a name the user already has.
    func persistFirstAuthorizationName(_ name: String, userId: String) async {
        var profile = LogManager.shared.getProfile(userId: userId)
            ?? UserProfile(id: userId, isOnboardingCompleted: false)

        if profile.firstName?.trimmingCharacters(in: .whitespaces).isEmpty ?? true {
            profile.firstName = name
            LogManager.shared.saveProfile(profile)
        }

        _ = try? await SupabaseManager.shared.client.auth.update(
            user: UserAttributes(data: ["first_name": .string(name)])
        )
    }

    // MARK: - Button placement

    /// Builds the system Apple button and drops it into the same stack view as
    /// `sibling`, one position above it.
    ///
    /// Guideline 4.8 wants the Apple option presented as an *equivalent* to the
    /// third-party one, so the button matches the Google button's height and
    /// corner radius and sits directly above it. Using the system button (rather
    /// than a hand-drawn one) also keeps Apple's own size, label and
    /// localization rules satisfied for free.
    ///
    /// Returns nil if `sibling` isn't in a stack view, which would mean the
    /// storyboard changed shape underneath this code.
    @discardableResult
    static func installButton(above sibling: UIButton,
                              target: Any,
                              action: Selector) -> ASAuthorizationAppleIDButton? {
        guard let stack = sibling.superview as? UIStackView,
              let index = stack.arrangedSubviews.firstIndex(of: sibling) else {
            assertionFailure("Apple sign-in button has nowhere to go — the sign-in storyboard changed shape.")
            return nil
        }

        let height = sibling.constraints
            .first { $0.firstAttribute == .height && $0.relation == .equal }?
            .constant ?? 50

        let button = ASAuthorizationAppleIDButton(type: .continue, style: .black)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.cornerRadius = height / 2      // the Google button is capsule-styled

        // Two triggers on purpose. `addTarget` is the documented way to handle
        // this button, but on iOS 26 it does not fire — verified on an iPhone 17
        // Pro simulator, where target-action produced nothing and the tap
        // recognizer produced the expected authorization error. The recognizer
        // is what actually works; addTarget stays as a fallback in case a future
        // OS restores the documented behaviour and the recognizer is superseded.
        //
        // Whichever fires, `signIn` refuses to start a second authorization
        // while one is in flight, so a double trigger is harmless.
        button.addTarget(target, action: action, for: .touchUpInside)
        button.addGestureRecognizer(UITapGestureRecognizer(target: target, action: action))

        stack.insertArrangedSubview(button, at: index)
        button.heightAnchor.constraint(equalToConstant: height).isActive = true

        return button
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleSignInManager: ASAuthorizationControllerDelegate {

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation?.resume(throwing: AppleSignInError.missingIdentityToken)
            continuation = nil
            return
        }
        continuation?.resume(returning: credential)
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        continuation?.resume(throwing: Self.friendlyError(from: error))
        continuation = nil
    }

    /// Turns Apple's error codes into something worth showing a user.
    ///
    /// Raw `ASAuthorizationError`s surface as "The operation couldn't be
    /// completed. (com.apple.AuthenticationServices.AuthorizationError error
    /// 1000.)", which tells a user nothing and looks broken. Cancellation is
    /// mapped to `.cancelled` so callers can stay silent entirely.
    private static func friendlyError(from error: Error) -> Error {
        guard let authError = error as? ASAuthorizationError else { return error }

        switch authError.code {
        case .canceled:
            return AppleSignInError.cancelled
        case .unknown:
            // What a simulator with no Apple Account signed in reports, and what
            // a device reports when the Apple Account is signed out.
            return AppleSignInError.notSignedIntoApple
        case .notHandled, .failed, .invalidResponse:
            return AppleSignInError.appleUnavailable
        default:
            return AppleSignInError.appleUnavailable
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AppleSignInManager: ASAuthorizationControllerPresentationContextProviding {

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if let anchorWindow { return anchorWindow }
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let key = scenes.compactMap(\.keyWindow).first { return key }
        // No key window only happens mid-transition; any window on the active
        // scene is a valid anchor for Apple's sheet.
        if let scene = scenes.first { return UIWindow(windowScene: scene) }
        return ASPresentationAnchor()
    }
}
