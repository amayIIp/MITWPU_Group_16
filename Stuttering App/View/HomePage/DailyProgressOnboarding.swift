//
//  DailyProgressOnboarding.swift
//  Stuttering App
//
//  Created by Krish Jain on 25/03/26.
//

import UIKit

class DailyProgressOnboarding: UIViewController {

    @IBAction func proceedToNextScreenTapped(_ sender: UIButton) {
        AppState.isDailyProgressCompleted = true

        let storyboard = UIStoryboard(name: "Home", bundle: nil)
        guard let nextVC = storyboard.instantiateViewController(withIdentifier: "PracticeViewController") as? PracticeViewController else {
            print("Error: Could not instantiate SummaryViewController")
            return
        }

        guard let navigationController = self.navigationController else { return }
        var currentStack = navigationController.viewControllers
        currentStack.removeAll { $0 === self }
        currentStack.append(nextVC)
        navigationController.setViewControllers(currentStack, animated: true)
    }

}
