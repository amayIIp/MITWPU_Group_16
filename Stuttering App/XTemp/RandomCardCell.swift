import UIKit

// A tiny helper view to create the subcategory rows easily
class SubcategoryRowView: UIView {
    let radioImageView = UIImageView()
    let titleLabel = UILabel()
    var index: Int = 0
    
    init(title: String, index: Int) {
        super.init(frame: .zero)
        self.index = index
        setup(title: title)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func setup(title: String) {
        self.translatesAutoresizingMaskIntoConstraints = false
        self.heightAnchor.constraint(equalToConstant: 44).isActive = true
        
        radioImageView.translatesAutoresizingMaskIntoConstraints = false
        radioImageView.contentMode = .scaleAspectFit
        setRadioSelected(false) // Default state
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.font = UIFont.preferredFont(forTextStyle: .callout)
        
        addSubview(radioImageView)
        addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            radioImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 48), // Indented
            radioImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            radioImageView.widthAnchor.constraint(equalToConstant: 22),
            radioImageView.heightAnchor.constraint(equalToConstant: 22),
            
            titleLabel.leadingAnchor.constraint(equalTo: radioImageView.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    func setRadioSelected(_ isSelected: Bool) {
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: isSelected ? .regular : .light)
        let symbolName = isSelected ? "circle.inset.filled" : "circle"
        radioImageView.image = UIImage(systemName: symbolName, withConfiguration: config)
        radioImageView.tintColor = isSelected ? .systemBlue : .systemGray3
    }
}

// MARK: - The Random Card Cell
class RandomCardCell: UICollectionViewCell {
    
    let headerView = UIView()
    let titleLabel = UILabel()
    let radioImageView = UIImageView()
    let chevronImageView = UIImageView()
    
    let expandableContainer = UIView()
    let stackView = UIStackView()
    
    // We use a zero-height constraint to collapse the view.
    // When expanded, we deactivate this so the Stack View can take its natural size.
    var collapsedHeightConstraint: NSLayoutConstraint!
    var rowViews: [SubcategoryRowView] = []
    
    let subcategories = ["Science", "Space", "Astronomy", "Mindset", "Sports"]
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    required init?(coder: NSCoder) { super.init(coder: coder); setupUI() }
    
    private func setupUI() {
        contentView.backgroundColor = .secondarySystemGroupedBackground
        contentView.layer.cornerRadius = 12
        contentView.clipsToBounds = true
        
        // --- HEADER ---
        headerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(headerView)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Random"
        titleLabel.font = UIFont.preferredFont(forTextStyle: .body)
        
        radioImageView.translatesAutoresizingMaskIntoConstraints = false
        radioImageView.contentMode = .scaleAspectFit
        
        chevronImageView.translatesAutoresizingMaskIntoConstraints = false
        chevronImageView.contentMode = .scaleAspectFit
        chevronImageView.tintColor = .systemGray
        
        headerView.addSubview(radioImageView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(chevronImageView)
        
        // --- EXPANDABLE CONTAINER ---
        expandableContainer.translatesAutoresizingMaskIntoConstraints = false
        expandableContainer.clipsToBounds = true // THIS IS THE MAGIC CLIPPING MASK
        contentView.addSubview(expandableContainer)
        
        // --- STACK VIEW (Holds the 5 options) ---
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.distribution = .fillEqually
        expandableContainer.addSubview(stackView)
        
        for (index, title) in subcategories.enumerated() {
            let row = SubcategoryRowView(title: title, index: index)
            stackView.addArrangedSubview(row)
            rowViews.append(row)
        }
        
        // --- CONSTRAINTS ---
        collapsedHeightConstraint = expandableContainer.heightAnchor.constraint(equalToConstant: 0)
        
        NSLayoutConstraint.activate([
            // Header
            headerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 50),
            
            radioImageView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            radioImageView.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            radioImageView.widthAnchor.constraint(equalToConstant: 24),
            radioImageView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.leadingAnchor.constraint(equalTo: radioImageView.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            
            chevronImageView.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            chevronImageView.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            chevronImageView.widthAnchor.constraint(equalToConstant: 16),
            chevronImageView.heightAnchor.constraint(equalToConstant: 16),
            
            // Container
            expandableContainer.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            expandableContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            expandableContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            expandableContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            // Stack View (Pinned inside container)
            stackView.topAnchor.constraint(equalTo: expandableContainer.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: expandableContainer.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: expandableContainer.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: expandableContainer.bottomAnchor, constant: -8)
        ])
    }
    
    // MARK: - Animation & State Updates
    
    func setExpanded(_ isExpanded: Bool, animated: Bool) {
        // Toggle the constraint. If expanded, we turn off the 0-height constraint so it grows naturally.
        collapsedHeightConstraint.isActive = !isExpanded
        
        let targetTransform = isExpanded ? CGAffineTransform(rotationAngle: .pi / 2) : .identity
        
        if animated {
            UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.1, options: .curveEaseInOut, animations: {
                self.chevronImageView.transform = targetTransform
                self.contentView.layoutIfNeeded() // Animate the height change
            }, completion: nil)
        } else {
            self.chevronImageView.transform = targetTransform
            self.contentView.layoutIfNeeded()
        }
    }
    
    func updateHeaderSelection(isSelected: Bool) {
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: isSelected ? .regular : .light)
        let symbolName = isSelected ? "circle.inset.filled" : "circle"
        radioImageView.image = UIImage(systemName: symbolName, withConfiguration: config)
        radioImageView.tintColor = isSelected ? .systemBlue : .systemGray3
    }
    
    func updateSubcategorySelection(selectedIndex: Int?) {
        for row in rowViews {
            row.setRadioSelected(row.index == selectedIndex)
        }
    }
}
