import UIKit

struct OnboardingFeature {
    let iconName: String
    let title: String
    let description: String
}

class FeatureRowView: UIView {
    init(feature: OnboardingFeature) {
        super.init(frame: .zero)

        let iconImageView = UIImageView(image: UIImage(systemName: feature.iconName))
        iconImageView.tintColor = UIColor(named: "ButtonTheme") ?? .systemBlue
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = feature.title
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textColor = .label

        let descLabel = UILabel()
        descLabel.text = feature.description
        descLabel.font = .preferredFont(forTextStyle: .body)
        descLabel.textColor = .secondaryLabel
        descLabel.numberOfLines = 0

        let textStack = UIStackView(arrangedSubviews: [titleLabel, descLabel])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconImageView)
        addSubview(textStack)

        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            iconImageView.topAnchor.constraint(equalTo: textStack.topAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 32),
            iconImageView.heightAnchor.constraint(equalToConstant: 32),

            textStack.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 16),
            textStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            textStack.topAnchor.constraint(equalTo: topAnchor),
            textStack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class ModuleOnboardingOverlayView: UIView {

    // MARK: - Callback
    var onContinue: (() -> Void)?

    // MARK: - UI Elements
    private let subtitleLabel = UILabel()
    private let featuresStack = UIStackView()
    private let footerLabel = UILabel()
    private let continueButton = UIButton(type: .system)

    // MARK: - Initialization
    init(subtitle: String, features: [OnboardingFeature], footerText: String? = nil) {
        super.init(frame: .zero)
        self.backgroundColor = .bg // Covers everything beneath it natively
        setupUI(subtitle: subtitle, features: features, footerText: footerText)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup
    private func setupUI(subtitle: String, features: [OnboardingFeature], footerText: String?) {

        // Subtitle (Title is handled by the Navigation Bar large title!)
        subtitleLabel.text = subtitle
        subtitleLabel.font = .preferredFont(forTextStyle: .body)
        subtitleLabel.textColor = .label
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        scrollView.indicatorStyle = .default

        featuresStack.axis = .vertical
        featuresStack.spacing = 32
        featuresStack.translatesAutoresizingMaskIntoConstraints = false

        // Add the subtitle at the very top of the scrollable stack
        featuresStack.addArrangedSubview(subtitleLabel)
        featuresStack.setCustomSpacing(40, after: subtitleLabel)

        for feature in features {
            featuresStack.addArrangedSubview(FeatureRowView(feature: feature))
        }

        scrollView.addSubview(featuresStack)

        if let footer = footerText {
            footerLabel.text = footer
            footerLabel.font = .systemFont(ofSize: 13, weight: .regular)
            footerLabel.textColor = .secondaryLabel
            footerLabel.textAlignment = .center
            footerLabel.numberOfLines = 0
        }
        footerLabel.translatesAutoresizingMaskIntoConstraints = false

        // Continue Button
        continueButton.setTitle("Continue", for: .normal)
        continueButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        continueButton.setTitleColor(.white, for: .normal)
        continueButton.backgroundColor = UIColor(named: "ButtonTheme") ?? .systemBlue
        continueButton.layer.cornerRadius = 25
        continueButton.translatesAutoresizingMaskIntoConstraints = false
        continueButton.addTarget(self, action: #selector(proceedTapped), for: .touchUpInside)

        // Add subviews
        addSubview(scrollView)
        addSubview(footerLabel)
        addSubview(continueButton)

        // Layout constraints
        NSLayoutConstraint.activate([
            // Stretch scroll view to edges so the scrollbar sits exactly on the edge
            scrollView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: footerLabel.topAnchor, constant: -16),

            featuresStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            // Apply the 32 point padding to the features stack *inside* the scroll view
            featuresStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 32),
            featuresStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -32),
            featuresStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            featuresStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -64),

            footerLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            footerLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32),
            footerLabel.bottomAnchor.constraint(equalTo: continueButton.topAnchor, constant: -16),

            continueButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            continueButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32),
            // Pinned with a larger offset to clear the custom floating tab bar which sits on top of the view
            continueButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -110),
            continueButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    // MARK: - Lifecycle
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if self.window != nil {
            // Flash the scroll bar briefly when the view appears so the user knows it's scrollable
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                if let scrollView = self?.subviews.first(where: { $0 is UIScrollView }) as? UIScrollView {
                    scrollView.flashScrollIndicators()
                }
            }
        }
    }

    // MARK: - Actions
    @objc private func proceedTapped() {
        onContinue?()
    }
}
