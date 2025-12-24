//
//  LastOnboardingViewController.swift
//  Spasht
//
//  Created by SDC-USER on 17/11/25.
//

import UIKit

class LastOnboardingViewController: UIViewController {
    
    @IBOutlet weak var splashStackView: UIStackView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var getStartedButton: UIButton!
    @IBOutlet weak var chartContainerView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupButton()
        setupInitialState()
        setupPieChart()
        setupCustomBackButton()
    }
    
    private func setupPieChart() {
        let chart = PieChartView_N()
        chart.translatesAutoresizingMaskIntoConstraints = false
        chart.backgroundColor = .clear
        chartContainerView.addSubview(chart)
        
        NSLayoutConstraint.activate([
            chart.topAnchor.constraint(equalTo: chartContainerView.topAnchor),
            chart.bottomAnchor.constraint(equalTo: chartContainerView.bottomAnchor),
            chart.leadingAnchor.constraint(equalTo: chartContainerView.leadingAnchor),
            chart.trailingAnchor.constraint(equalTo: chartContainerView.trailingAnchor)
        ])
    }
    
    private func setupCustomBackButton() {
        self.navigationItem.hidesBackButton = true
        
        let customBackButton = UIBarButtonItem(
            image: UIImage(systemName: "chevron.backward"),
            style: .plain,
            target: self,
            action: #selector(didTapResetButton)
        )
        
        self.navigationItem.leftBarButtonItem = customBackButton
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = true
        performEntryAnimation()
    }
    
    private func setupInitialState() {
        // Initial visibility
        splashStackView.alpha = 1.0
        splashStackView.isHidden = false
        
        scrollView.alpha = 0.0
        getStartedButton.alpha = 0.0
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    private func performEntryAnimation() {
        UIView.animate(withDuration: 1.0,
                       delay: 2.0,
                       options: [.curveEaseInOut],
                       animations: {
            // Fade out the Stack View
            self.splashStackView.alpha = 0.0
            
            // Fade in the main content
            self.scrollView.alpha = 1.0
            self.getStartedButton.alpha = 1.0
            self.navigationController?.setNavigationBarHidden(false, animated: false)
            self.navigationController?.navigationBar.prefersLargeTitles = true
            
        }) { _ in
            self.splashStackView.isHidden = true
        }
    }
    func setupButton() {
        getStartedButton.configuration = .prominentGlass()
        getStartedButton.configuration?.title = "Continue"
    }

    @IBAction func getStartedButtonTapped(_ sender: UIButton) {
        AppState.isOnboardingCompleted = true
        AwardsManager.shared.updateAwardProgress(id: "nm_001", progress: 1.0, newStatus: "1 of 1 completed")
        
        let storyboard = UIStoryboard(name: "Home", bundle: nil)
        let homeVC = storyboard.instantiateViewController(withIdentifier: "HomeVC")
        
        if let sceneDelegate = view.window?.windowScene?.delegate as? SceneDelegate,
           let window = sceneDelegate.window {
            
            UIView.transition(with: window, duration: 0.3, options: .curveLinear, animations: {
                window.rootViewController = homeVC
            }, completion: nil)
            
        }
    }
    
    @objc func didTapResetButton() {
        let alert = UIAlertController(
            title: "Reset Test",
            message: "This will reset your current progress. Are you sure you want to continue?",
            preferredStyle: .alert
        )

        let continueAction = UIAlertAction(title: "Reset", style: .destructive) { [weak self] _ in
            self?.navigateHere()
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)

        alert.addAction(continueAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }

    func navigateHere() {
        guard let navigationController = self.navigationController else { return }

        let currentStack = navigationController.viewControllers
        let targetIndex = currentStack.count - 3
        
        if targetIndex >= 0 {
            let targetViewController = currentStack[targetIndex]
            navigationController.popToViewController(targetViewController, animated: true)
        } else {
            navigationController.popToRootViewController(animated: true)
        }
    }
    
}
class PieChartView_N: UIView {
    static let darkBlue_N = UIColor(red: 0/255, green: 51/255, blue: 204/255, alpha: 1.0)
    static let mediumBlue_N = UIColor(red: 0/255, green: 128/255, blue: 255/255, alpha: 1.0)
    static let lightBlue_N = UIColor(red: 102/255, green: 204/255, blue: 255/255, alpha: 1.0)
    
    var slices_N: [(value: CGFloat, color: UIColor)] = [
        (40, darkBlue_N),   
        (30, mediumBlue_N),
        (30, lightBlue_N)
    ] { didSet { setNeedsDisplay() } }

    override func draw(_ rect: CGRect) {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var startAngle: CGFloat = -.pi / 2
        let total = slices_N.reduce(0) { $0 + $1.value }

        for slice in slices_N {
            let endAngle = startAngle + (slice.value / total) * 2 * .pi
            let path = UIBezierPath()
            path.move(to: center)
            path.addArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
            slice.color.setFill()
            path.fill()
            startAngle = endAngle
        }
    }
}
