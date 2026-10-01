//
//  SignInView.swift
//  Spasht
//
//  The sign-in screen. Email and password, then Apple and Google as equals
//  beneath them, then the guest door for anyone who doesn't want an account yet.
//

import SwiftUI

struct SignInView: View {

    @ObservedObject var model: AuthModel

    private enum Field: Hashable { case email, password }
    @FocusState private var focus: Field?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {

            AuthHeader(title: AuthModel.Mode.signIn.title,
                       subtitle: AuthModel.Mode.signIn.subtitle)

            VStack(alignment: .trailing, spacing: 10) {
                credentialsCard

                Button("Forgot password?") { model.beginPasswordReset() }
                    .font(.footnote.weight(.medium))
                    .tint(AuthStyle.accent)
            }

            AuthPrimaryButton(title: AuthModel.Mode.signIn.callToAction,
                              isEnabled: model.isFormComplete) {
                focus = nil
                model.submit()
            }

            AuthSeparator()

            providers

            if model.offersGuestMode {
                Button("Continue as guest") { model.continueAsGuest() }
                    .font(.subheadline.weight(.medium))
                    .tint(AuthStyle.accent)
                    .frame(maxWidth: .infinity)
                    // A 44pt target: the old screen's version was a bare label.
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
            }

            AuthSwitchFooter(model: model)
        }
    }

    // MARK: - Pieces

    private var credentialsCard: some View {
        AuthFieldCard(isFocused: focus != nil) {
            AuthField(icon: "envelope", caption: "Email", isFocused: focus == .email) {
                TextField("Email address", text: $model.email)
                    .focused($focus, equals: .email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .onSubmit { focus = .password }
            }
            .onTapGesture { focus = .email }

            Divider().padding(.leading, 50)

            AuthField(icon: "lock", caption: "Password", isFocused: focus == .password) {
                HStack(spacing: 8) {
                    passwordField
                    PasswordVisibilityToggle(isVisible: $model.showsPassword)
                }
            }
            .onTapGesture { focus = .password }
        }
    }

    @ViewBuilder
    private var passwordField: some View {
        if model.showsPassword {
            TextField("Your password", text: $model.password)
                .focused($focus, equals: .password)
                .textContentType(.password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .onSubmit { model.submit() }
        } else {
            SecureField("Your password", text: $model.password)
                .focused($focus, equals: .password)
                .textContentType(.password)
                .submitLabel(.go)
                .onSubmit { model.submit() }
        }
    }

    private var providers: some View {
        VStack(spacing: 12) {
            AppleAuthButton { model.signInWithApple() }
                .frame(height: AuthStyle.controlHeight)

            AuthProviderButton(title: "\(AuthModel.Mode.signIn.providerVerb) Google",
                               imageName: "google-5") {
                model.signInWithGoogle()
            }
        }
    }
}

// MARK: - Shared bits of both screens

/// The eye that flips the password between dots and plain text.
struct PasswordVisibilityToggle: View {
    @Binding var isVisible: Bool

    var body: some View {
        Button {
            isVisible.toggle()
        } label: {
            Image(systemName: isVisible ? "eye" : "eye.slash")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isVisible ? "Hide password" : "Show password")
    }
}

/// "New to Spasht? Create one" — and its mirror image on the sign-up screen.
struct AuthSwitchFooter: View {
    @ObservedObject var model: AuthModel

    var body: some View {
        HStack(spacing: 4) {
            Text(model.mode.switchPrompt)
                .foregroundStyle(.secondary)
            Button(model.mode.switchAction) { model.switchMode() }
                .fontWeight(.semibold)
                .tint(AuthStyle.accent)
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}
