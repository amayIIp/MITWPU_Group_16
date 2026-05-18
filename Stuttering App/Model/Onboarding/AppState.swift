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

    static let kDailyChallengesCompleted = "dailyChallenges.isCompleted"
    static let kDailyProgressCompleted   = "dailyProgress.isCompleted"
    static let kExercisesCompleted       = "exercises.isCompleted"
    static let kReadAloudCompleted       = "readAloud.isCompleted"
    static let kConvoCompleted           = "convo.isCompleted"

    static var isLoginCompleted: Bool {
        get { UserDefaults.standard.bool(forKey: kLoginCompleted) }
        set { UserDefaults.standard.set(newValue, forKey: kLoginCompleted) }
    }

    static var isOnboardingCompleted: Bool {
        get { UserDefaults.standard.bool(forKey: kOnboardingCompleted) }
        set { UserDefaults.standard.set(newValue, forKey: kOnboardingCompleted) }
    }

    // Section Onboarding

    static var isDailyChallengesCompleted: Bool {
        get { UserDefaults.standard.bool(forKey: kDailyChallengesCompleted) }
        set { UserDefaults.standard.set(newValue, forKey: kDailyChallengesCompleted) }
    }

    static var isDailyProgressCompleted: Bool {
        get { UserDefaults.standard.bool(forKey: kDailyProgressCompleted) }
        set { UserDefaults.standard.set(newValue, forKey: kDailyProgressCompleted) }
    }

    static var isExercisesCompleted: Bool {
        get { UserDefaults.standard.bool(forKey: kExercisesCompleted) }
        set { UserDefaults.standard.set(newValue, forKey: kExercisesCompleted) }
    }

    static var isReadAloudCompleted: Bool {
        get { UserDefaults.standard.bool(forKey: kReadAloudCompleted) }
        set { UserDefaults.standard.set(newValue, forKey: kReadAloudCompleted) }
    }

    static var isConvoCompleted: Bool {
        get { UserDefaults.standard.bool(forKey: kConvoCompleted) }
        set { UserDefaults.standard.set(newValue, forKey: kConvoCompleted) }
    }

    /// Call on logout or new user login to reset all module onboarding gates.
    static func resetModuleOnboarding() {
        isExercisesCompleted = false
        isReadAloudCompleted = false
        isConvoCompleted    = false
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
