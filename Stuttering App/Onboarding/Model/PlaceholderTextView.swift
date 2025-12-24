//
//  PlaceholderTextView.swift
//  Stutterr
//
//  Created by Prathamesh Patil on 03/10/25.
//

import Foundation
import UIKit


class PlaceholderTextView: UITextView {

    @IBInspectable var placeholderText: String = "" {
        didSet {
            placeholderLabel.text = placeholderText
            updatePlaceholderVisibility()
        }
    }

    @IBInspectable var placeholderColor: UIColor = UIColor.lightGray {
        didSet {
            placeholderLabel.textColor = placeholderColor
        }
    }

    private let placeholderLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.lightGray
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Initialization

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    deinit {
        // Remove the observer when the object is deallocated
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup

    private func setup() {
        // Add the placeholder label to the text view
        self.addSubview(placeholderLabel)
        
        // Use the text view's own font for the placeholder
        placeholderLabel.font = self.font
        placeholderLabel.text = placeholderText
        placeholderLabel.textColor = placeholderColor

        // Constraints to position the placeholder label
        NSLayoutConstraint.activate([
            // Match the top edge of the text view's text container (including padding)
            placeholderLabel.topAnchor.constraint(equalTo: self.topAnchor, constant: self.textContainerInset.top + self.contentInset.top),
            // Match the leading edge, adding the same padding the text view uses for its text
            placeholderLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: self.textContainerInset.left + self.contentInset.left + self.textContainer.lineFragmentPadding),
            // Ensure the label can grow wide but not wider than the content area
            placeholderLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -(self.textContainerInset.right + self.contentInset.right + self.textContainer.lineFragmentPadding)),
        ])

        // Listen for text changes to toggle the placeholder visibility
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(textDidChange),
                                               name: UITextView.textDidChangeNotification,
                                               object: self)

        updatePlaceholderVisibility()
    }

    // MARK: - Overrides

    // We must update the placeholder label's font if the text view's font changes
    override var font: UIFont? {
        didSet {
            placeholderLabel.font = font
        }
    }
    
    // We must manually check for content changes in the setter
    override var text: String! {
        didSet {
            textDidChange() // Ensure placeholder updates when text is set programmatically
        }
    }

    // We must manually check for content changes in the setter
    override var attributedText: NSAttributedString! {
        didSet {
            textDidChange() // Ensure placeholder updates when attributed text is set programmatically
        }
    }

    // MARK: - Placeholder Management

    /// Toggles the placeholder visibility based on whether the text view is empty.
    @objc private func textDidChange() {
        updatePlaceholderVisibility()
    }
    
    private func updatePlaceholderVisibility() {
        // Hide the placeholder if the text view has content, show it if it's empty
        placeholderLabel.isHidden = !self.text.isEmpty
    }
}
