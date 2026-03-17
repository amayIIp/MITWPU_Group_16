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

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setup() {
        self.addSubview(placeholderLabel)
        
        placeholderLabel.font = self.font
        placeholderLabel.text = placeholderText
        placeholderLabel.textColor = placeholderColor

        NSLayoutConstraint.activate([
            placeholderLabel.topAnchor.constraint(equalTo: self.topAnchor, constant: self.textContainerInset.top + self.contentInset.top),
            placeholderLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: self.textContainerInset.left + self.contentInset.left + self.textContainer.lineFragmentPadding),
            placeholderLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -(self.textContainerInset.right + self.contentInset.right + self.textContainer.lineFragmentPadding)),
        ])

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(textDidChange),
                                               name: UITextView.textDidChangeNotification,
                                               object: self)

        updatePlaceholderVisibility()
    }

    override var font: UIFont? {
        didSet {
            placeholderLabel.font = font
        }
    }
    
    override var text: String! {
        didSet {
            textDidChange()
        }
    }

    override var attributedText: NSAttributedString! {
        didSet {
            textDidChange()
        }
    }

    @objc private func textDidChange() {
        updatePlaceholderVisibility()
    }
    
    private func updatePlaceholderVisibility() {
        placeholderLabel.isHidden = !self.text.isEmpty
    }
}
