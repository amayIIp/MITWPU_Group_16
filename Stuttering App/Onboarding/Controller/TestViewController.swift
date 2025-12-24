//
//  TestViewController.swift
//  Spasht
//
//  Created by Prathamesh Patil on 16/11/25.
//

import UIKit

class TestViewController: UIViewController {
    

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var previousButton: UIButton!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var resetButton: UIButton!
    @IBOutlet weak var continueButton: UIButton!
    @IBOutlet weak var bottomViewConstraint: NSLayoutConstraint!
    
    let paragraphs: [String] = [
        "The old clock on the shadowed mantelpiece ticked in a rhythm that was both comforting and profoundly unsettling, each sharp metallic click echoing relentlessly through the oppressive stillness of the room like a measured, faltering heartbeat.",
        "Its polished brass pendulum swung with patient, hypnotic precision, tracing invisible arcs of time that seemed to have little meaning or consequence in the hushed, stifling atmosphere of the forgotten parlor.",
        "Dust motes danced in the pale, watery afternoon light filtering sluggishly through brittle, yellowed curtains, their slow, aimless waltz a stark, silent contrast to the clock's relentless, tyrannical forward march.",
        "She stood motionless by the tall, grimy window, a silhouette against the gloom, watching shadows lengthen like spreading ink across the warped hardwood floor, each passing second marked by the clock's steady, indifferent voice echoing her own profound solitude.",
        "Time moved differently here, stretched thin and brittle like honey left too long in the cold, thick with unwanted memories that clung to every draped surface and refused to fade away completely, forever whispering.",
        "A faint, musty scent of damp plaster and dried lavender hung heavy in the air, a perfume of decay that seemed to catch in her throat. The chill of the room was a physical weight, settling deep into her bones, making her feel as much a fixture of the parlor as the moth-eaten brocade armchair sitting empty in the corner, its springs long since silenced.",
        "On a side table, a porcelain figurine of a dancer was frozen mid-pirouette, its painted smile mocking the stagnation that permeated the very air. Beside it, a teacup, left unwashed, held the dark, circular stain of a final sip taken seasons ago. These artifacts of a life paused were her only companions, their stillness a perfect mirror to her own."
    ]
        
    var paragraphLabels: [UILabel] = []
    var currentIndex: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupButtons()
        createParagraphLabels()
        highlightParagraph(at: currentIndex, animated: false)
    }
    
    func setupButtons() {
        previousButton.configuration = .glass()
        previousButton.configuration?.image = UIImage(systemName: "chevron.left")
        
        nextButton.configuration = .glass()
        nextButton.configuration?.image = UIImage(systemName: "chevron.right")
        
        resetButton.configuration = .glass()
        resetButton.configuration?.image = UIImage(systemName: "repeat")
        
        continueButton.configuration = .prominentGlass()
        continueButton.configuration?.title = "Finish"
        
        continueButton.alpha = 0
        continueButton.isHidden = true
        bottomViewConstraint.constant = 0
        
        updateButtonStates()
        
    }
    
    
        
    func createParagraphLabels() {
        // Clean up existing views
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        paragraphLabels.removeAll()
        
        // Generate Paragraph Labels
        for (index, paragraph) in paragraphs.enumerated() {
            let label = UILabel()
            label.text = paragraph
            label.numberOfLines = 0
            label.textAlignment = .left
            
            label.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
            label.textColor = UIColor.secondaryLabel
            label.alpha = 0.4
            label.tag = index
            
            stackView.addArrangedSubview(label)
            paragraphLabels.append(label)
        }
        
       
        let bottomSpacer = UIView()
        stackView.addArrangedSubview(bottomSpacer)

        bottomSpacer.translatesAutoresizingMaskIntoConstraints = false
        bottomSpacer.heightAnchor.constraint(equalTo: scrollView.heightAnchor, multiplier: 0.4).isActive = true
    }
    
    func highlightParagraph(at index: Int, animated: Bool) {
        guard index >= 0 && index < paragraphLabels.count else { return }
        
        let duration: TimeInterval = animated ? 0.4 : 0
        
        let label = self.paragraphLabels[index]
        let labelFrame = label.convert(label.bounds, to: self.scrollView)
        
        let centerOffset = labelFrame.midY - (self.scrollView.bounds.height / 2)
 
        // min(..., maxOffset) -> prevents scrolling past bottom
        // max(0, centerOffset) -> prevents scrolling past top (This handles the first paragraph automatically)
        let maxOffset = max(0, self.scrollView.contentSize.height - self.scrollView.bounds.height)
        let targetOffset = CGPoint(x: 0, y: min(max(0, centerOffset), maxOffset))
        
        // Animate Visuals and Scroll Position together
        UIView.animate(withDuration: duration, delay: 0, options: .curveEaseInOut, animations: {
            
            // Update Scroll Position (Set offset directly inside animation block)
            self.scrollView.contentOffset = targetOffset
            
            // Update Label Styling
            for (i, lbl) in self.paragraphLabels.enumerated() {
                if i == index {
                    // Focused State
                    lbl.textColor = .label
                    lbl.alpha = 1.0
                    lbl.font = .systemFont(ofSize: 18, weight: .semibold)
                } else if i < index {
                    // Passed State
                    lbl.textColor = .tertiaryLabel
                    lbl.alpha = 0.3
                    lbl.font = .systemFont(ofSize: 17, weight: .semibold)
                } else {
                    // Upcoming State
                    lbl.textColor = .secondaryLabel
                    lbl.alpha = 0.4
                    lbl.font = .systemFont(ofSize: 17, weight: .semibold)
                }
            }
        }, completion: nil)
        
        currentIndex = index
        updateButtonStates()
    }
        
    func updateButtonStates() {
        previousButton.isEnabled = currentIndex > 0
        nextButton.isEnabled = currentIndex < paragraphs.count
        
        previousButton.alpha = previousButton.isEnabled ? 1.0 : 0.5
        nextButton.alpha = nextButton.isEnabled ? 1.0 : 0.5
    }
    
    @IBAction func nextButtonTapped(_ sender: UIButton) {
        if currentIndex < paragraphs.count - 1 {
            highlightParagraph(at: currentIndex + 1, animated: true)
        } else if currentIndex == paragraphs.count - 1 {
            self.bottomViewConstraint.constant = 60
            
            // 2. Prepare the button visibility
            self.continueButton.isHidden = false
            
            // 3. Animate layout and opacity
            UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseOut) {
                
                // This forces the layout engine to update frames based on the new constraint
                self.view.layoutIfNeeded()
                
                // Fade the button in
                self.continueButton.alpha = 1.0
                
            }
        }
    }
    
    @IBAction func previousButtonTapped(_ sender: UIButton) {
        if currentIndex > 0 {
            highlightParagraph(at: currentIndex - 1, animated: true)
        }
    }
    
    @IBAction func resetButtonTapped(_ sender: UIButton) {
        highlightParagraph(at: 0, animated: true)
        
        self.bottomViewConstraint.constant = 0
        
        // 2. Animate layout and opacity
        UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseIn) {
            
            // Forces the layout engine to slide the view back down
            self.view.layoutIfNeeded()
            
            // Fade the button out
            self.continueButton.alpha = 0
            
        } completion: { _ in
            // 3. Cleanup: Actually hide the button after it is invisible
            // This ensures it is not tappable while invisible
            self.continueButton.isHidden = true
        }
    }
}
