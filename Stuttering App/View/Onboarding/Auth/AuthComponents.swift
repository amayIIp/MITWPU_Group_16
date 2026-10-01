//
//  AuthComponents.swift
//  Spasht
//
//  The shared furniture of the two auth screens: the field card, the provider
//  buttons, the progress overlay and the legal row.
//
//  Everything here is built from stock SwiftUI controls and system colours, so
//  Dynamic Type, Dark Mode, VoiceOver and the system tint all come for free
//  rather than being re-implemented per screen.
//

import SwiftUI
import AuthenticationServices

// MARK: - Palette

enum AuthStyle {
    /// The app's own accent, so the new screens match every other screen.
    static let accent = Color("ButtonThemeMain")
    static let background = Color("bg")

    static let controlHeight: CGFloat = 54
    static let cardRadius: CGFloat = 18
}

// MARK: - Text fields

/// One labelled row of the field card.
///
/// The icon and the floating caption give each row an anchor at a glance,
/// which a bare placeholder does not once the field has been filled in.
struct AuthField<Content: View>: View {
    let icon: String
    let caption: String
    var isFocused: Bool
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isFocused ? AuthStyle.accent : Color.secondary)
                .frame(width: 22)
                .animation(.easeOut(duration: 0.15), value: isFocused)

            VStack(alignment: .leading, spacing: 2) {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                content
                    .font(.body)
                    .textFieldStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

/// The rounded container the fields sit in, with a tint ring while editing.
struct AuthFieldCard<Content: View>: View {
    var isFocused: Bool
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: AuthStyle.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AuthStyle.cardRadius, style: .continuous)
                    .strokeBorder(isFocused ? AuthStyle.accent.opacity(0.55) : Color.clear,
                                  lineWidth: 1.5)
            )
            .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}

// MARK: - Buttons

/// The full-width capsule that carries the screen's primary action.
struct AuthPrimaryButton: View {
    let title: String
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .tint(AuthStyle.accent)
        .frame(height: AuthStyle.controlHeight)
        .disabled(!isEnabled)
    }
}

/// A provider button that matches the Apple button's height and capsule shape,
/// which is what Guideline 4.8 means by presenting the options as equivalents.
struct AuthProviderButton: View {
    let title: String
    let imageName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                Text(title)
                    .font(.headline)
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: AuthStyle.controlHeight)
            // A light capsule rather than a second heavy slab: it reads as a
            // peer of the black Apple button instead of competing with it.
            .background(Color(.secondarySystemGroupedBackground), in: Capsule())
            .overlay(Capsule().strokeBorder(Color(.separator), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Apple's own button, so its size, label and localisation rules are satisfied
/// without hand-drawing anything.
///
/// Two triggers on purpose, matching `AppleSignInManager.installButton`:
/// `addTarget` is the documented route but does not fire on recent iOS, and the
/// tap recogniser is what actually works. Whichever lands, `signIn` refuses to
/// start a second authorization while one is in flight, so both firing is
/// harmless.
struct AppleAuthButton: UIViewRepresentable {
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(
            type: .continue,
            style: colorScheme == .dark ? .white : .black
        )
        button.cornerRadius = AuthStyle.controlHeight / 2
        button.addTarget(context.coordinator,
                         action: #selector(Coordinator.fire),
                         for: .touchUpInside)
        button.addGestureRecognizer(
            UITapGestureRecognizer(target: context.coordinator,
                                   action: #selector(Coordinator.fire)))
        return button
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {
        context.coordinator.action = action
    }

    final class Coordinator: NSObject {
        var action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func fire() { action() }
    }
}

// MARK: - Decoration

/// "or" with a rule either side.
struct AuthSeparator: View {
    var label: String = "or"

    var body: some View {
        HStack(spacing: 12) {
            line
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
            line
        }
    }

    private var line: some View {
        Rectangle()
            .fill(Color(.separator))
            .frame(height: 1)
    }
}

/// "Privacy Policy · Terms · Support", the SwiftUI twin of `LegalLinks.makeLinkRow`.
///
/// Guideline 5.1.1(i) expects anyone handing over personal data to be able to
/// reach the policy from the screen they hand it over on, which is this one.
struct AuthLegalLinks: View {
    let onPrivacy: () -> Void
    let onTerms: () -> Void
    let onSupport: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            link("Privacy Policy", action: onPrivacy)
            dot
            link("Terms", action: onTerms)
            dot
            link("Support", action: onSupport)
        }
        .font(.caption)
    }

    private var dot: some View {
        Text("·").foregroundStyle(.tertiary)
    }

    private func link(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
    }
}

/// The title block at the top of both screens.
struct AuthHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.largeTitle.bold())
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Covers the screen while an authentication is in flight, so nothing can be
/// tapped twice and the wait is accounted for.
struct AuthProgressOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.12).ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                Text(message)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(28)
            .background(.regularMaterial,
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
        }
        .transition(.opacity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}
