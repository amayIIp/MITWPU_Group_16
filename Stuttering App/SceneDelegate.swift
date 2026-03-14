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
        
        // ✅ ALWAYS initialize user if signed in to Supabase
        if let _ = SupabaseManager.shared.currentUser {
            LogManager.shared.initializeUserIfNeeded()
        }
        
        var initialVC: UIViewController
        
        if AppState.isOnboardingCompleted {
            // Both guest users and logged-in users who completed onboarding go to Home
            let storyboard = UIStoryboard(name: "Home", bundle: nil)
            initialVC = storyboard.instantiateViewController(withIdentifier: "HomeVC")
            
        } else if AppState.isLoginCompleted && !AppState.isOnboardingCompleted {
            // Logged in but hasn't done onboarding yet (e.g. new device login)
            let storyboard = UIStoryboard(name: "Onboarding", bundle: nil)
            initialVC = storyboard.instantiateViewController(withIdentifier: "PhonemesSelectionViewController")
            
        }
        else {
            // Fresh install — show landing/welcome screen
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
