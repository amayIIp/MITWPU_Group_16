//
//  conversationresultViewController.swift
//  Stuttering App
//
//  Created by SDC-USER on 27/11/25.
//

import UIKit

class ReadingResultViewController: UIViewController {
    
    
    @IBOutlet var exercisesStackView: UIStackView!
    @IBOutlet weak var troubledWordsStackView: UIStackView!
    
    @IBOutlet weak var insightsLabel: UILabel!
    
    @IBOutlet weak var fluencyCircleView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupFluencyCircle(score: 60)
        navigationItem.title = "Result"
        
        insightsLabel.text = ResultData.insightsText
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "xmark"), style: .plain, target: self, action: #selector(didTapCloseResult))
        
        
        loadTroubledWords()
        loadExercises()
    }
    
    func loadTroubledWords() {
        let words = ResultData.troubledWordsArray
        let maxPerRow = 3
        
        troubledWordsStackView.arrangedSubviews.forEach {
            $0.removeFromSuperview()
        }
        
        var currentRowStack: UIStackView?
        
        for (index, word) in words.enumerated() {
            
            // Create new row every 4 items
            if index % maxPerRow == 0 {
                currentRowStack = UIStackView()
                currentRowStack?.axis = .horizontal
                currentRowStack?.alignment = .leading
                currentRowStack?.distribution = .fillProportionally
                currentRowStack?.spacing = 12
                
                troubledWordsStackView.addArrangedSubview(currentRowStack!)
            }
            
            let chip = createChipLabel(text: word, textColor: .systemBlue)
            currentRowStack?.addArrangedSubview(chip)
        }
    }
    
    func loadExercises() {
        let exercises = ResultData.recommendedExercisesArray
        let maxPerRow = 3
        
        exercisesStackView.arrangedSubviews.forEach {
            $0.removeFromSuperview()
        }
        
        var currentRowStack: UIStackView?
        
        for (index, exercise) in exercises.enumerated() {
            
            if index % maxPerRow == 0 {
                currentRowStack = UIStackView()
                currentRowStack?.axis = .horizontal
                currentRowStack?.alignment = .leading
                currentRowStack?.distribution = .fillProportionally
                currentRowStack?.spacing = 12
                
                exercisesStackView.addArrangedSubview(currentRowStack!)
            }
            
            let chip = createChipLabel(text: exercise, textColor: .systemGreen)
            currentRowStack?.addArrangedSubview(chip)
        }
    }
    
    func createChipLabel(text: String, textColor: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = textColor
        label.backgroundColor = textColor.withAlphaComponent(0.12)
        label.textAlignment = .center
        label.numberOfLines = 1
        
        label.layer.cornerRadius = 14
        label.layer.masksToBounds = true
        
        label.translatesAutoresizingMaskIntoConstraints = false
        label.heightAnchor.constraint(equalToConstant: 28).isActive = true
        
        // Prevent stretching
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        label.layoutMargins = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        
        return label
    }
    
    func setupFluencyCircle(score: CGFloat) {
        fluencyCircleView.layoutIfNeeded()
        
        // Remove old layers
        fluencyCircleView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        
        let center = CGPoint(
            x: fluencyCircleView.bounds.midX,
            y: fluencyCircleView.bounds.midY
        )
        
        let radius: CGFloat = min(
            fluencyCircleView.bounds.width,
            fluencyCircleView.bounds.height
        ) / 2 - 30
        
        let lineWidth: CGFloat = 36
        
        let circlePath = UIBezierPath(
            arcCenter: center,
            radius: radius,
            startAngle: -.pi / 2,
            endAngle: 1.5 * .pi,
            clockwise: true
        )
        
        let backgroundCircle = CAShapeLayer()
        backgroundCircle.path = circlePath.cgPath
        backgroundCircle.strokeColor = UIColor.systemGray5.cgColor
        backgroundCircle.lineWidth = lineWidth
        backgroundCircle.fillColor = UIColor.clear.cgColor
        backgroundCircle.lineCap = .round
        fluencyCircleView.layer.addSublayer(backgroundCircle)
        
        let progressCircle = CAShapeLayer()
        progressCircle.path = circlePath.cgPath
        progressCircle.strokeColor = UIColor.systemBlue.cgColor
        progressCircle.lineWidth = lineWidth
        progressCircle.fillColor = UIColor.clear.cgColor
        progressCircle.lineCap = .round
        progressCircle.strokeEnd = 0
        fluencyCircleView.layer.addSublayer(progressCircle)
        
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.toValue = score / 100
        animation.duration = 1.2
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        progressCircle.add(animation, forKey: "progressAnim")
        
        let scoreLabel = UILabel(frame: fluencyCircleView.bounds)
        scoreLabel.text = "\(Int(score))"
        scoreLabel.textAlignment = .center
        scoreLabel.font = UIFont.boldSystemFont(ofSize: 42)
        scoreLabel.textColor = .black
        fluencyCircleView.addSubview(scoreLabel)
    }
    
    @objc func didTapCloseResult() {
        if let initialPresenter = self.presentingViewController?.presentingViewController {
            // Ask A to dismiss everything it presented (B and B's presented child, C)
            initialPresenter.dismiss(animated: true, completion: nil)
        }
    }
}
