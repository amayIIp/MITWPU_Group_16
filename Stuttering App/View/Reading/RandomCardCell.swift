import UIKit

class SubcategoryRowView: UIView {
    let radioImageView = UIImageView()
    let titleLabel = UILabel()
    var index: Int = 0

    var onTap: ((Int) -> Void)?

    init(title: String, index: Int) {
        super.init(frame: .zero)
        self.index = index
        setup(title: title)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup(title: String) {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 16
        addSubview(stack)

        radioImageView.contentMode = .scaleAspectFit
        setRadioSelected(false)

        titleLabel.text = title
        titleLabel.font = UIFont.preferredFont(forTextStyle: .body)

        // A flexible spacer to ensure the text doesn't stretch and pushes everything left
        let flexibleSpacer = UIView()

        stack.addArrangedSubview(radioImageView)
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(flexibleSpacer)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            // THIS EXACTLY MATCHES THE HEADER'S LEADING PADDING
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            self.heightAnchor.constraint(equalToConstant: 50),
            radioImageView.widthAnchor.constraint(equalToConstant: 24),
            radioImageView.heightAnchor.constraint(equalToConstant: 24)
        ])

        self.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        self.addGestureRecognizer(tap)
    }

    @objc private func handleTap() {
        onTap?(index)
    }

    func setRadioSelected(_ isSelected: Bool) {
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: isSelected ? .regular : .light)
        let symbolName = isSelected ? "circle.inset.filled" : "circle"
        radioImageView.image = UIImage(systemName: symbolName, withConfiguration: config)
        radioImageView.tintColor = isSelected ? UIColor(named: "ButtonTheme") : .systemGray3
    }
}

class RandomCardCell: UICollectionViewCell {

    // NEW: Closures for the View Controller
    var onHeaderTapped: (() -> Void)?
    var onSubcategoryTapped: ((Int) -> Void)?

    let headerStack = UIStackView()
    let headerRadio = UIImageView()
    let headerTitle = UILabel()
    let headerChevron = UIImageView()

    let expandableContainer = UIView()
    let optionsStack = UIStackView()

    var collapsedHeightConstraint: NSLayoutConstraint!
    var rowViews: [SubcategoryRowView] = []
    let subcategories = ["Science", "Space", "Astronomy", "Mindset", "Sports"]

    override init(frame: CGRect) { super.init(frame: frame); setupUI() }
    required init?(coder: NSCoder) { super.init(coder: coder); setupUI() }

    private func setupUI() {
        contentView.backgroundColor = .secondarySystemGroupedBackground
        contentView.layer.cornerRadius = 24
        contentView.clipsToBounds = true

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
        headerTitle.text = "Random"
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

        optionsStack.translatesAutoresizingMaskIntoConstraints = false
        optionsStack.axis = .vertical
        expandableContainer.addSubview(optionsStack)

        for (index, title) in subcategories.enumerated() {
            let row = SubcategoryRowView(title: title, index: index)
            row.onTap = { [weak self] tappedIndex in
                self?.onSubcategoryTapped?(tappedIndex)
            }
            optionsStack.addArrangedSubview(row)
            rowViews.append(row)
        }

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

            optionsStack.topAnchor.constraint(equalTo: expandableContainer.topAnchor),
            optionsStack.leadingAnchor.constraint(equalTo: expandableContainer.leadingAnchor),
            optionsStack.trailingAnchor.constraint(equalTo: expandableContainer.trailingAnchor),
            optionsStack.bottomAnchor.constraint(equalTo: expandableContainer.bottomAnchor, constant: -12)
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

    func updateHeaderSelection(isSelected: Bool) {
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: isSelected ? .regular : .light)
        let symbolName = isSelected ? "circle.inset.filled" : "circle"
        headerRadio.image = UIImage(systemName: symbolName, withConfiguration: config)
        headerRadio.tintColor = isSelected ? UIColor(named: "ButtonTheme") : .systemGray3
    }

    func updateSubcategorySelection(selectedIndex: Int?) {
        for row in rowViews {
            row.setRadioSelected(row.index == selectedIndex)
        }
    }
}
