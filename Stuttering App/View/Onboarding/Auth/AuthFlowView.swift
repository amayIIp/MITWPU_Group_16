//
//  AuthFlowView.swift
//  Spasht
//
//  The frame both auth screens live in: background, scrolling, close button,
//  progress overlay and alerts.
//
//  Sign-in and sign-up are one screen that changes rather than two sheets that
//  dismiss and re-present each other, so switching between them keeps whatever
//  the user has already typed and never flashes the screen underneath.
//

import SwiftUI

struct AuthFlowView: View {

    @ObservedObject var model: AuthModel

    var body: some View {
        ZStack {
            AuthStyle.background.ignoresSafeArea()

            ScrollView {
                Group {
                    switch model.mode {
                    case .signIn:
                        SignInView(model: model)
                            .transition(.asymmetric(insertion: .move(edge: .leading),
                                                    removal: .move(edge: .trailing))
                                .combined(with: .opacity))
                    case .signUp:
                        SignUpView(model: model)
                            .transition(.asymmetric(insertion: .move(edge: .trailing),
                                                    removal: .move(edge: .leading))
                                .combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 24)
                // The title used to sit below an app mark, which kept it clear
                // of the close button; without it, it needs the room itself.
                .padding(.top, model.canDismiss ? 44 : 12)
                .padding(.bottom, 12)

                AuthLegalLinks(onPrivacy: model.openPrivacy,
                               onTerms: model.openTerms,
                               onSupport: model.openSupport)
                    .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            // Stops a half-finished tap landing on a control behind the overlay.
            .disabled(model.isBusy)

            if let message = model.busyMessage {
                AuthProgressOverlay(message: message)
            }
        }
        .animation(.easeOut(duration: 0.2), value: model.isBusy)
        .overlay(alignment: .topTrailing) {
            if model.canDismiss {
                closeButton
            }
        }
        .alert("Reset Password", isPresented: $model.isRequestingReset) {
            TextField("Email", text: $model.resetEmail)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Cancel", role: .cancel) { }
            Button("Send Reset Link") { model.sendPasswordReset() }
        } message: {
            Text("Enter your email and we'll send a reset link.")
        }
        .alert(model.alert?.title ?? "",
               isPresented: Binding(get: { model.alert != nil },
                                    set: { if !$0 { model.alert = nil } }),
               presenting: model.alert) { alert in
            ForEach(alert.actions) { action in
                Button(action.title) { action.handler() }
            }
            Button("OK", role: .cancel) { }
        } message: { alert in
            Text(alert.message)
        }
    }

    private var closeButton: some View {
        Button {
            model.dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .background(.regularMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .padding(.trailing, 20)
        .padding(.top, 8)
        .accessibilityLabel("Close")
    }
}
