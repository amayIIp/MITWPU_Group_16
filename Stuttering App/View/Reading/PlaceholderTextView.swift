import UIKit

class PlaceholderTextView: UITextView {

    @IBInspectable var placeholderText: String = "" {
        didSet {
            placeholderLabel.text = placeholderText
            updatePlaceholderVisibility()
        }
    }

    @IBInspectable var placeholderColor: UIColor = .tertiaryLabel {
        didSet {
            placeholderLabel.textColor = placeholderColor
        }
    }

    private let placeholderLabel: UILabel = {
        let label = UILabel()
        // Use modern semantic colors for iOS aesthetics
        label.textColor = .tertiaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // Store constraints so we can update them dynamically
    private var placeholderTopConstraint: NSLayoutConstraint!
    private var placeholderLeadingConstraint: NSLayoutConstraint!
    private var placeholderTrailingConstraint: NSLayoutConstraint!

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
        addSubview(placeholderLabel)

        placeholderLabel.font = self.font
        placeholderLabel.text = placeholderText
        placeholderLabel.textColor = placeholderColor

        // Initialize constraints but do not hardcode the constants yet
        placeholderTopConstraint = placeholderLabel.topAnchor.constraint(equalTo: topAnchor)
        placeholderLeadingConstraint = placeholderLabel.leadingAnchor.constraint(equalTo: leadingAnchor)
        placeholderTrailingConstraint = placeholderLabel.trailingAnchor.constraint(equalTo: trailingAnchor)

        NSLayoutConstraint.activate([
            placeholderTopConstraint,
            placeholderLeadingConstraint,
            placeholderTrailingConstraint,
            // Ensure the placeholder doesn't stretch the text view horizontally
            placeholderLabel.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -32)
        ])

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(textDidChange),
                                               name: UITextView.textDidChangeNotification,
                                               object: self)

        updatePlaceholderVisibility()
    }

    // This is the critical fix: Update constraint constants whenever the layout changes
    override func layoutSubviews() {
        super.layoutSubviews()

        placeholderTopConstraint.constant = textContainerInset.top + contentInset.top
        placeholderLeadingConstraint.constant = textContainerInset.left + contentInset.left + textContainer.lineFragmentPadding
        placeholderTrailingConstraint.constant = -(textContainerInset.right + contentInset.right + textContainer.lineFragmentPadding)
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
