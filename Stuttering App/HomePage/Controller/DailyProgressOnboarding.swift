//
//  DailyProgressOnboarding.swift
//  Stuttering App
//
//  Created by Krish Jain on 25/03/26.
//

import UIKit

class DailyProgressOnboarding: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    @IBAction func proceedToNextScreenTapped(_ sender: UIButton) {
        AppState.isDailyProgressCompleted = true
        // 1. Instantiate the next View Controller from your Storyboard
        let storyboard = UIStoryboard(name: "Home", bundle: nil)
        guard let nextVC = storyboard.instantiateViewController(withIdentifier: "DailyTasksViewController") as? DailyTasksViewController else {
            print("Error: Could not instantiate NextViewController")
            return
        }
        
        // 2. Safely unwrap the current navigation controller stack
        guard let navigationController = self.navigationController else { return }
        var currentStack = navigationController.viewControllers
        
        // 3. Remove the current View Controller (itself) from the stack
        currentStack.removeAll { $0 === self }
        
        // 4. Append the new View Controller to the stack
        currentStack.append(nextVC)
        
        // 5. Apply the modified stack with a push animation
        navigationController.setViewControllers(currentStack, animated: true)
    }

}
