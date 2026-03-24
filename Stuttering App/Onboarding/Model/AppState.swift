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
    static let kUserMode = "session.userMode"
    static let kDeviceId = "session.deviceId"
    static let kLastActiveUserId = "session.lastUserId"

    static var isLoginCompleted: Bool {
        get { UserDefaults.standard.bool(forKey: kLoginCompleted) }
        set { UserDefaults.standard.set(newValue, forKey: kLoginCompleted) }
    }

    static var isOnboardingCompleted: Bool {
        get { UserDefaults.standard.bool(forKey: kOnboardingCompleted) }
        set { UserDefaults.standard.set(newValue, forKey: kOnboardingCompleted) }
    }
    
    /// Whether the current session is in guest mode
    static var isGuestMode: Bool {
        return SessionManager.shared.isGuestMode
    }
    
    /// Whether the current session is in account mode
    static var isAccountMode: Bool {
        return SessionManager.shared.isAccountMode
    }
}
