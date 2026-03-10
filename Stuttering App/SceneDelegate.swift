//
//  SceneDelegate.swift
//  Stuttering App 1
//
//  Created by Prathamesh Patil on 09/12/25.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?


    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        window = UIWindow(windowScene: windowScene)
        
        // ✅ ALWAYS initialize user if email exists
        if let _ = StorageManager.shared.getEmail() {
            LogManager.shared.initializeUserIfNeeded()
        }
        
        var initialVC: UIViewController
        
        if AppState.isLoginCompleted || AppState.isOnboardingCompleted {
            
            let storyboard = UIStoryboard(name: "Home", bundle: nil)
            initialVC = storyboard.instantiateViewController(withIdentifier: "HomeVC")
            
        } else if AppState.isLoginCompleted && !AppState.isOnboardingCompleted {
            
            let storyboard = UIStoryboard(name: "Onboarding", bundle: nil)
            initialVC = storyboard.instantiateViewController(withIdentifier: "PhonemesSelectionViewController")
            
        }
        else {
            
            let storyboard = UIStoryboard(name: "Onboarding", bundle: nil)
            initialVC = storyboard.instantiateViewController(withIdentifier: "LandingNav")
        }
        
        window?.rootViewController = initialVC
        window?.makeKeyAndVisible()
    }


    func sceneDidDisconnect(_ scene: UIScene) {}

    func sceneDidBecomeActive(_ scene: UIScene) {}

    func sceneWillResignActive(_ scene: UIScene) {}

    func sceneWillEnterForeground(_ scene: UIScene) {
        let logic = LogicMaker()
        logic.checkForNewDay()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {}
}
