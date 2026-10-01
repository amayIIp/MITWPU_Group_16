//
//  SignUpView.swift
//  Spasht
//
//  The sign-up screen. Same shape as sign-in with a name field added and the
//  password rule stated up front rather than after a rejected attempt.
//

import SwiftUI

struct SignUpView: View {

    @ObservedObject var model: AuthModel

    private enum Field: Hashable { case name, email, password }
    @FocusState private var focus: Field?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            AuthHeader(title: AuthModel.Mode.signUp.title,
                       subtitle: AuthModel.Mode.signUp.subtitle)

            VStack(alignment: .leading, spacing: 8) {
                detailsCard

                Label("At least 8 characters.", systemImage: passwordIsLongEnough
                      ? "checkmark.circle.fill" : "info.circle")
                    .font(.caption)
                    .foregroundStyle(passwordIsLongEnough ? Color.green : Color.secondary)
                    .animation(.easeOut(duration: 0.15), value: passwordIsLongEnough)
                    .padding(.leading, 4)
            }

            AuthPrimaryButton(title: AuthModel.Mode.signUp.callToAction,
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
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
            }

            AuthSwitchFooter(model: model)
        }
    }

    private var passwordIsLongEnough: Bool { model.password.count >= 8 }

    // MARK: - Pieces

    private var detailsCard: some View {
        AuthFieldCard(isFocused: focus != nil) {
            AuthField(icon: "person", caption: "Name", isFocused: focus == .name) {
                TextField("First name", text: $model.name)
                    .focused($focus, equals: .name)
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .onSubmit { focus = .email }
            }
            .onTapGesture { focus = .name }

            Divider().padding(.leading, 50)

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
            TextField("Create a password", text: $model.password)
                .focused($focus, equals: .password)
                .textContentType(.newPassword)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .onSubmit { model.submit() }
        } else {
            SecureField("Create a password", text: $model.password)
                .focused($focus, equals: .password)
                .textContentType(.newPassword)
                .submitLabel(.go)
                .onSubmit { model.submit() }
        }
    }

    private var providers: some View {
        VStack(spacing: 12) {
            AppleAuthButton { model.signInWithApple() }
                .frame(height: AuthStyle.controlHeight)

            AuthProviderButton(title: "\(AuthModel.Mode.signUp.providerVerb) Google",
                               imageName: "google-5") {
                model.signInWithGoogle()
            }
        }
    }
}
