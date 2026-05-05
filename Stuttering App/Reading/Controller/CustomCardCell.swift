import UIKit

class CustomCardCell: UICollectionViewCell {
    
    var onHeaderTapped: (() -> Void)?
    
    let headerStack = UIStackView()
    let headerRadio = UIImageView()
    let headerTitle = UILabel()
    let headerChevron = UIImageView()
    
    let expandableContainer = UIView()
    let customTextView = PlaceholderTextView()
    
    var collapsedHeightConstraint: NSLayoutConstraint!
    
    override init(frame: CGRect) { super.init(frame: frame); setupUI() }
    required init?(coder: NSCoder) { super.init(coder: coder); setupUI() }
    
    private func setupUI() {
        contentView.backgroundColor = .systemBackground
        contentView.layer.cornerRadius = 24
        contentView.clipsToBounds = true
        
        // MODERN UIKit
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            let screenWidth = windowScene.screen.bounds.width
            contentView.widthAnchor.constraint(equalToConstant: screenWidth - 32).isActive = true
        }
        
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.spacing = 16
        contentView.addSubview(headerStack)
        
        headerRadio.contentMode = .scaleAspectFit
        headerTitle.text = "Custom"
        headerTitle.font = UIFont.preferredFont(forTextStyle: .body)
        
        headerChevron.contentMode = .scaleAspectFit
        headerChevron.tintColor = .systemGray
        headerChevron.image = UIImage(systemName: "chevron.right")
        
        let flexibleSpacer = UIView()
        headerStack.addArrangedSubview(headerRadio)
        headerStack.addArrangedSubview(headerTitle)
        headerStack.addArrangedSubview(flexibleSpacer)
        headerStack.addArrangedSubview(headerChevron)
        
        // NEW: Make the Header tappable
        headerStack.isUserInteractionEnabled = true
        let headerTap = UITapGestureRecognizer(target: self, action: #selector(headerDidTap))
        headerStack.addGestureRecognizer(headerTap)
        
        expandableContainer.translatesAutoresizingMaskIntoConstraints = false
        expandableContainer.clipsToBounds = true
        contentView.addSubview(expandableContainer)
        
        customTextView.translatesAutoresizingMaskIntoConstraints = false
        customTextView.layer.cornerRadius = 24
        customTextView.backgroundColor = .systemBackground
        customTextView.font = UIFont.preferredFont(forTextStyle: .footnote)
        customTextView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        customTextView.placeholderText = "Enter your text here..."
        expandableContainer.addSubview(customTextView)
        
        collapsedHeightConstraint = expandableContainer.heightAnchor.constraint(equalToConstant: 0)
        
        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: contentView.topAnchor),
            headerStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            headerStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            headerStack.heightAnchor.constraint(equalToConstant: 50),
            
            headerRadio.widthAnchor.constraint(equalToConstant: 24),
            headerRadio.heightAnchor.constraint(equalToConstant: 24),
            headerChevron.widthAnchor.constraint(equalToConstant: 16),
            headerChevron.heightAnchor.constraint(equalToConstant: 16),
            
            expandableContainer.topAnchor.constraint(equalTo: headerStack.bottomAnchor),
            expandableContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            expandableContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            expandableContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            customTextView.topAnchor.constraint(equalTo: expandableContainer.topAnchor, constant: 2),
            customTextView.leadingAnchor.constraint(equalTo: expandableContainer.leadingAnchor, constant: 10),
            customTextView.trailingAnchor.constraint(equalTo: expandableContainer.trailingAnchor, constant: -10),
            customTextView.bottomAnchor.constraint(equalTo: expandableContainer.bottomAnchor, constant: -16),
            customTextView.heightAnchor.constraint(equalToConstant: 300)
        ])
    }
    
    @objc private func headerDidTap() {
        onHeaderTapped?()
    }
    
    func setExpanded(_ isExpanded: Bool, animated: Bool) {
        collapsedHeightConstraint.isActive = !isExpanded
        let targetTransform = isExpanded ? CGAffineTransform(rotationAngle: .pi / 2) : .identity
        
        if animated {
            UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.1, options: .curveEaseInOut, animations: {
                self.headerChevron.transform = targetTransform
                self.contentView.layoutIfNeeded()
            }, completion: nil)
        } else {
            self.headerChevron.transform = targetTransform
            self.contentView.layoutIfNeeded()
        }
    }
    
    func updateSelectionState(isSelected: Bool) {
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: isSelected ? .regular : .light)
        let symbolName = isSelected ? "circle.inset.filled" : "circle"
        headerRadio.image = UIImage(systemName: symbolName, withConfiguration: config)
        headerRadio.tintColor = isSelected ? UIColor(named: "ButtonTheme") : .systemGray3
    }
}
