
import UIKit

class SetGoalsViewController: UIViewController {

    // MARK: - Outlets
    
    // 1. Back Button

    
    // 2. Container Views (The white cards)
    // Connect these to the white UIViews holding each section
    @IBOutlet weak var exercisesCardView: UIView!
    @IBOutlet weak var readingCardView: UIView!
    @IBOutlet weak var conversationCardView: UIView!
    
    // 3. Count Labels (The numbers)
    @IBOutlet weak var exercisesLabel: UILabel!
    @IBOutlet weak var readingLabel: UILabel!
    @IBOutlet weak var conversationLabel: UILabel!
    
    // MARK: - Properties
    // Initial values based on your screenshot
    var exerciseCount = 10
    var readingCount = 10
    var conversationCount = 10
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateLabels()
    }
    
    // MARK: - UI Configuration
    func setupUI() {
       
        
        // 2. Style the Cards (Rounded Corners)
        let cards = [exercisesCardView, readingCardView, conversationCardView]
        for card in cards {
            // Apply standard iOS corner radius
            card?.layer.cornerRadius = 12
            // Optional: Add subtle shadow for depth
            card?.layer.shadowColor = UIColor.black.cgColor
            card?.layer.shadowOpacity = 0.05
            card?.layer.shadowOffset = CGSize(width: 0, height: 2)
            card?.layer.shadowRadius = 4
        }
    }
    
    func updateLabels() {
        // Update text. Note: Reading/Conversation have "min" suffix in your design.
        exercisesLabel.text = "\(exerciseCount)"
        readingLabel.text = "\(readingCount)\nmin"     // Using newline or space based on your layout
        conversationLabel.text = "\(conversationCount)\nmin"
    }

    // MARK: - Actions
    

    // 2. Exercises Logic
    @IBAction func decreaseExercises(_ sender: UIButton) {
        if exerciseCount > 0 { // Prevent negative numbers
            exerciseCount -= 1
            updateLabels()
        }
    }
    
    @IBAction func increaseExercises(_ sender: UIButton) {
        exerciseCount += 1
        updateLabels()
    }
    
    // 3. Reading Logic
    @IBAction func decreaseReading(_ sender: UIButton) {
        if readingCount > 5 { // Example: Minimum 5 mins
            readingCount -= 5
            updateLabels()
        }
    }
    
    @IBAction func increaseReading(_ sender: UIButton) {
        readingCount += 5 // Example: Step by 5 mins
        updateLabels()
    }
    
    // 4. Conversation Logic
    @IBAction func decreaseConversation(_ sender: UIButton) {
        if conversationCount > 5 {
            conversationCount -= 5
            updateLabels()
        }
    }
    
    @IBAction func increaseConversation(_ sender: UIButton) {
        conversationCount += 5
        updateLabels()
    }
}
