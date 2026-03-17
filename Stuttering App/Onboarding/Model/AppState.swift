//
//  AppState.swift
//  Spasht
//
//  Created by SDC-USER on 18/11/25.
//

import Foundation

struct AppState {
    static let kLoginCompleted = "login.isCompleted"
    static let kOnboardingCompleted = "onboarding.isCompleted"

    static var isLoginCompleted: Bool {
        get { UserDefaults.standard.bool(forKey: kLoginCompleted) }
        set { UserDefaults.standard.set(newValue, forKey: kLoginCompleted) }
    }

    static var isOnboardingCompleted: Bool {
        get { UserDefaults.standard.bool(forKey: kOnboardingCompleted) }
        set { UserDefaults.standard.set(newValue, forKey: kOnboardingCompleted) }
    }
}
