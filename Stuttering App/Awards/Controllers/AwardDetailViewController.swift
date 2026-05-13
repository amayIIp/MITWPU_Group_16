//
//  AwardDetailViewController.swift
//  Stuttering App 1
//
//  Created by Prathamesh Patil on 15/12/25.
//

import UIKit

class AwardDetailViewController: UIViewController {
    
    @IBOutlet weak var awardImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var progressBar: UIProgressView!
    
    var award: AwardModel?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        populateData()
        setupShareButton()
    }
    
    private func setupUI() {
        nameLabel.font = .systemFont(ofSize: 28, weight: .bold)
        descriptionLabel.textColor = .secondaryLabel
    }
    
    private func populateData() {
        guard let award = award else { return }
        
        nameLabel.text = award.name
        descriptionLabel.text = award.description
        awardImageView.image = UIImage(named: award.id) ?? UIImage(systemName: "trophy")
        
        if award.isCompleted {
            progressBar.isHidden = true
            awardImageView.alpha = 1.0
            
            if let date = award.completionDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .long
                dateLabel.text = "Earned on " + formatter.string(from: date)
            } else {
                dateLabel.text = "Completed"
            }
            
        } else {
            progressBar.isHidden = false
            progressBar.progress = Float(award.progress)
            awardImageView.alpha = 0.5
            dateLabel.text = award.status
        }
    }
    
    // MARK: - Sharing
    
    private func setupShareButton() {
        guard let award = award, award.isCompleted else { return }
        let shareButton = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"), style: .plain, target: self, action: #selector(shareTapped))
        navigationItem.rightBarButtonItem = shareButton
    }
    
    @objc private func shareTapped() {
        guard let award = award, award.isCompleted else { return }
        
        let shareImage = generateShareImage(for: award)
        
        // Instagram, Snapchat, and others often hide themselves from the Share Sheet
        // if you pass both a UIImage and a String simultaneously. Passing only the image
        // ensures it can be posted directly to Stories or feeds on all platforms.
        let activityVC = UIActivityViewController(activityItems: [shareImage], applicationActivities: nil)
        
        // iPad support
        if let popover = activityVC.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        
        present(activityVC, animated: true)
    }
    
    private func generateShareImage(for award: AwardModel) -> UIImage {
        // Standard Instagram/Story size (1080x1080). We'll do a nice square card.
        let cardSize = CGSize(width: 1080, height: 1080)
        let padding: CGFloat = 80
        
        let container = UIView(frame: CGRect(origin: .zero, size: cardSize))
        
        // 1. Generate Textured Background
        let bgImageView = UIImageView(frame: container.bounds)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        let bgRenderer = UIGraphicsImageRenderer(size: cardSize, format: format)
        
        bgImageView.image = bgRenderer.image { ctx in
            let cgCtx = ctx.cgContext
            
            // Base Gradient
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let themeColor = UIColor(named: "ButtonTheme") ?? .systemBlue
            let colors = [themeColor.cgColor, UIColor.systemIndigo.cgColor, UIColor.systemPurple.cgColor] as CFArray
            
            if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 0.5, 1]) {
                cgCtx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: cardSize.width, y: cardSize.height), options: [])
            }
            
            // Aurora Blobs
            cgCtx.setBlendMode(.screen)
            cgCtx.setAlpha(0.4)
            
            cgCtx.setFillColor(UIColor.systemPink.cgColor)
            cgCtx.fillEllipse(in: CGRect(x: -200, y: -200, width: 800, height: 800))
            
            cgCtx.setFillColor(UIColor.systemTeal.cgColor)
            cgCtx.fillEllipse(in: CGRect(x: 500, y: 600, width: 900, height: 900))
            
            cgCtx.setBlendMode(.normal)
            cgCtx.setAlpha(1.0)
            
            // Subtle Dot Grid Texture
            let dotSize: CGFloat = 3
            let spacing: CGFloat = 30
            cgCtx.setFillColor(UIColor.white.withAlphaComponent(0.08).cgColor)
            
            for x in stride(from: 0, through: cardSize.width, by: spacing) {
                for y in stride(from: 0, through: cardSize.height, by: spacing) {
                    cgCtx.fillEllipse(in: CGRect(x: x, y: y, width: dotSize, height: dotSize))
                }
            }
        }
        container.addSubview(bgImageView)
        
        // Top Branding
        let brandingLabel = UILabel(frame: CGRect(x: padding, y: padding + 20, width: cardSize.width - padding*2, height: 60))
        let attributes: [NSAttributedString.Key: Any] = [
            .kern: 12.0, // Premium wide letter spacing
            .font: UIFont.systemFont(ofSize: 32, weight: .black),
            .foregroundColor: UIColor.white.withAlphaComponent(0.9)
        ]
        brandingLabel.attributedText = NSAttributedString(string: "SPASHT", attributes: attributes)
        brandingLabel.textAlignment = .center
        container.addSubview(brandingLabel)
        
        // Award Icon
        let iconSize: CGFloat = 350
        let iconView = UIImageView(frame: CGRect(
            x: (cardSize.width - iconSize) / 2,
            y: brandingLabel.frame.maxY + 100,
            width: iconSize,
            height: iconSize
        ))
        
        // Load custom image or fallback to trophy symbol
        if let customImage = UIImage(named: award.id) {
            iconView.image = customImage
        } else {
            let config = UIImage.SymbolConfiguration(pointSize: iconSize, weight: .regular)
            iconView.image = UIImage(systemName: "trophy", withConfiguration: config)
        }
        
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .systemYellow
        
        // Glow effect
        iconView.layer.shadowColor = UIColor.white.cgColor
        iconView.layer.shadowOpacity = 0.5
        iconView.layer.shadowOffset = .zero
        iconView.layer.shadowRadius = 50
        container.addSubview(iconView)
        
        // "ACHIEVEMENT UNLOCKED" subtitle
        let achievementLabel = UILabel(frame: CGRect(x: padding, y: iconView.frame.maxY + 60, width: cardSize.width - padding*2, height: 40))
        achievementLabel.text = "ACHIEVEMENT UNLOCKED"
        achievementLabel.font = .systemFont(ofSize: 28, weight: .bold)
        achievementLabel.textColor = .systemYellow
        achievementLabel.textAlignment = .center
        container.addSubview(achievementLabel)
        
        // Award Name
        let nameLabel = UILabel(frame: CGRect(x: padding, y: achievementLabel.frame.maxY + 10, width: cardSize.width - padding*2, height: 90))
        nameLabel.text = award.name
        nameLabel.font = .systemFont(ofSize: 72, weight: .heavy)
        nameLabel.textColor = .white
        nameLabel.textAlignment = .center
        nameLabel.adjustsFontSizeToFitWidth = true
        nameLabel.minimumScaleFactor = 0.5
        container.addSubview(nameLabel)
        
        // Description
        let descLabel = UILabel(frame: CGRect(x: padding + 40, y: nameLabel.frame.maxY + 20, width: cardSize.width - (padding + 40)*2, height: 100))
        descLabel.text = award.description
        descLabel.font = .systemFont(ofSize: 32, weight: .medium)
        descLabel.textColor = .white.withAlphaComponent(0.9)
        descLabel.textAlignment = .center
        descLabel.numberOfLines = 0
        container.addSubview(descLabel)
        
        // Date Earned
        if let date = award.completionDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            
            let dateLabel = UILabel(frame: CGRect(x: padding, y: cardSize.height - padding - 30, width: cardSize.width - padding*2, height: 40))
            dateLabel.text = "EARNED ON \(formatter.string(from: date).uppercased())"
            dateLabel.font = .systemFont(ofSize: 24, weight: .bold)
            dateLabel.textColor = .white.withAlphaComponent(0.5)
            dateLabel.textAlignment = .center
            container.addSubview(dateLabel)
        }
        
        // Render final composition to image
        let renderer = UIGraphicsImageRenderer(size: cardSize)
        let image = renderer.image { context in
            container.layer.render(in: context.cgContext)
        }
        
        return image
    }
}
