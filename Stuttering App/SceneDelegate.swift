//
//  SceneDelegate.swift
//  Stuttering App 1
//
//  Created by Prathamesh Patil on 09/12/25.
//

import UIKit
import Supabase

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        let window = UIWindow(windowScene: windowScene)
        self.window = window
        
        // 1. Show a temporary blank screen or LaunchScreen while checking auth state
        let launchStoryboard = UIStoryboard(name: "LaunchScreen", bundle: nil)
        window.rootViewController = launchStoryboard.instantiateInitialViewController() ?? UIViewController()
        window.makeKeyAndVisible()
        
        // 2. Check the session asynchronously
        Task {
            let isSessionValid = await checkSessionValidity()
            
            if isSessionValid {
                LogManager.shared.initializeUserIfNeeded()
            }
            
            // 3. Route to the correct Storyboard on the Main Thread
            await MainActor.run {
                self.routeUser(isSessionValid: isSessionValid)
            }
        }
    }
    
    // MARK: - Auth State Verification
    private func checkSessionValidity() async -> Bool {
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            return !session.isExpired
        } catch {
            return false // No session or failed to fetch
        }
    }

    // MARK: - iOS 26 Navigation Routing
    private func routeUser(isSessionValid: Bool) {
        var initialVC: UIViewController
        
        if isSessionValid && AppState.isOnboardingCompleted {
            let storyboard = UIStoryboard(name: "Home", bundle: nil)
            initialVC = storyboard.instantiateViewController(withIdentifier: "HomeVC")
            
        } else if isSessionValid && AppState.isLoginCompleted && !AppState.isOnboardingCompleted {
            let storyboard = UIStoryboard(name: "Onboarding", bundle: nil)
            initialVC = storyboard.instantiateViewController(withIdentifier: "PhonemesSelectionViewController")
            
        } else {
            let storyboard = UIStoryboard(name: "Onboarding", bundle: nil)
            initialVC = storyboard.instantiateViewController(withIdentifier: "LandingNav")
        }
        
        // Smoothly swap the root view controller
        guard let window = self.window else { return }
        window.rootViewController = initialVC
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
    }

    // MARK: - Scene Lifecycle
    func sceneDidDisconnect(_ scene: UIScene) {}
    func sceneDidBecomeActive(_ scene: UIScene) {}
    func sceneWillResignActive(_ scene: UIScene) {}
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        AwardsManager.shared.seedDatabaseIfNeeded()
        
        let logic = LogicMaker()
        logic.checkForNewDay()
        
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {}
}
