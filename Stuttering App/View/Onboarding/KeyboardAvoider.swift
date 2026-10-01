//
//  KeyboardAvoider.swift
//  Spasht
//
//  Keeps the focused text field above the keyboard.
//
//  The sign-in and sign-up sheets lay their forms out directly in the root
//  view with no scroll view, so on a 4.7" screen the keyboard covered the
//  password field and the Sign Up button with no way to reach them. Rather
//  than re-parent two storyboard hierarchies into scroll views — which would
//  invalidate every constraint in them — this slides the whole view up by
//  exactly the amount of the overlap, and puts it back afterwards.
//

import UIKit

final class KeyboardAvoider {

    private weak var view: UIView?
    private let margin: CGFloat

    /// Extra breathing room between the focused field and the keyboard.
    init(view: UIView, margin: CGFloat = 16) {
        self.view = view
        self.margin = margin

        let center = NotificationCenter.default
        center.addObserver(self,
                           selector: #selector(keyboardWillChangeFrame(_:)),
                           name: UIResponder.keyboardWillChangeFrameNotification,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(keyboardWillHide(_:)),
                           name: UIResponder.keyboardWillHideNotification,
                           object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func keyboardWillChangeFrame(_ note: Notification) {
        guard let view,
              let window = view.window,
              let end = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
        else { return }

        guard let focused = Self.firstResponder(in: view) else { return }

        // Measure against the untransformed position so repeated keyboard
        // changes (autocorrect bar, field-to-field moves) don't compound.
        let identityShift = view.transform.ty
        let focusedInWindow = focused.convert(focused.bounds, to: window)
        let focusedBottom = focusedInWindow.maxY - identityShift

        let overlap = focusedBottom + margin - end.minY
        let shift = max(0, overlap)

        animate(note) {
            view.transform = shift > 0 ? CGAffineTransform(translationX: 0, y: -shift) : .identity
        }
    }

    @objc private func keyboardWillHide(_ note: Notification) {
        guard let view else { return }
        animate(note) { view.transform = .identity }
    }

    private func animate(_ note: Notification, _ changes: @escaping () -> Void) {
        let duration = note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        let rawCurve = note.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 7
        UIView.animate(withDuration: duration,
                       delay: 0,
                       options: UIView.AnimationOptions(rawValue: rawCurve << 16),
                       animations: changes)
    }

    private static func firstResponder(in view: UIView) -> UIView? {
        if view.isFirstResponder { return view }
        for subview in view.subviews {
            if let found = firstResponder(in: subview) { return found }
        }
        return nil
    }
}
