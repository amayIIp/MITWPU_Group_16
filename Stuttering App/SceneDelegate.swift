//
//  SceneDelegate.swift
//  Stuttering App 1
//
//  Created by Prathamesh Patil on 09/12/25.
//

import UIKit
import Supabase
import GoogleSignIn

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

        // 2. Restore session using SessionManager
        Task {
            let restoredMode = await SessionManager.shared.restoreSession()

            // Initialize the correct user context
            switch restoredMode {
            case .guest:
                LogManager.shared.initializeGuestUser()
                print("🚪 [SESSION] Guest session restored — no Supabase calls")

            case .account:
                LogManager.shared.initializeUserIfNeeded()
                print("🚪 [SESSION] Account session restored — user initialized")

            case .none:
                print("🚪 [SESSION] No session to restore — showing landing page")
            }

            // 3. Route to the correct screen on the Main Thread
            await MainActor.run {
                self.routeUser(mode: restoredMode)
            }
        }
    }

    // MARK: - Session-Based Navigation Routing
    private func routeUser(mode: SessionManager.UserMode) {
        var initialVC: UIViewController

        switch mode {
        case .guest, .account:
            if AppState.isOnboardingCompleted {
                let storyboard = UIStoryboard(name: "Home", bundle: nil)
                initialVC = storyboard.instantiateViewController(withIdentifier: "HomeVC")
            } else {
                let storyboard = UIStoryboard(name: "Onboarding", bundle: nil)
                initialVC = storyboard.instantiateViewController(withIdentifier: "PhonemesSelectionViewController")
            }

        case .none:
            // No session → show welcome/landing screen
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
        
        guard SessionManager.shared.hasActiveSession else { return }
        
        let logic = LogicMaker()
        logic.checkForNewDay()

        if SessionManager.shared.isGuestMode {
            _ = JourneyGenerationEngine.shared.runIfNeeded()
        }

    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        GIDSignIn.sharedInstance.handle(url)
    }

    func sceneDidEnterBackground(_ scene: UIScene) {}
}
