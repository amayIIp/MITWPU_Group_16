//
//  SessionManager.swift
//  Stuttering App
//
//  Central session controller — single source of truth for Guest vs Account mode.
//

import Foundation
import Supabase

class SessionManager {

    static let shared = SessionManager()

    // MARK: - User Mode
    enum UserMode: String {
        case guest
        case account
        case none  // No session yet (first launch or after sign-out)
    }

    // MARK: - UserDefaults Keys
    private enum Keys {
        static let userMode        = "session.userMode"
        static let deviceId        = "session.deviceId"
        static let lastUserId      = "session.lastUserId"
        static let lastSyncDate    = "LastDeltaSyncDate"
    }

    // MARK: - Properties

    /// Current operating mode — persisted across app launches
    private(set) var currentMode: UserMode {
        get {
            let raw = UserDefaults.standard.string(forKey: Keys.userMode) ?? "none"
            return UserMode(rawValue: raw) ?? .none
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Keys.userMode)
            print("🚪 [SESSION] Mode changed → \(newValue.rawValue)")
        }
    }

    /// Unique device identifier — generated once per install, survives sign-outs
    var deviceId: String {
        if let existing = UserDefaults.standard.string(forKey: Keys.deviceId) {
            return existing
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: Keys.deviceId)
        print("🚪 [SESSION] Generated new deviceId: \(newId)")
        return newId
    }

    /// The active user ID — Supabase UUID for accounts, deviceId for guests.
    /// In account mode the fallback chain ends at the stored lastUserId or
    /// the live Supabase session; it does NOT fall through to deviceId so
    /// we never silently write account data under the wrong identifier.
    var currentUserId: String? {
        switch currentMode {
        case .account:
            return UserDefaults.standard.string(forKey: Keys.lastUserId)
                ?? SupabaseManager.shared.currentUser?.id.uuidString
        case .guest:
            return deviceId
        case .none:
            return deviceId
        }
    }

    /// Last synced Supabase user ID (for session restore)
    var lastUserId: String? {
        get { UserDefaults.standard.string(forKey: Keys.lastUserId) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.lastUserId) }
    }

    /// Last sync timestamp — used for delta sync
    var lastSyncTimestamp: String {
        get { UserDefaults.standard.string(forKey: Keys.lastSyncDate) ?? "1970-01-01T00:00:00Z" }
        set { UserDefaults.standard.set(newValue, forKey: Keys.lastSyncDate) }
    }

    // MARK: - Convenience

    var isAccountMode: Bool { currentMode == .account }
    var isGuestMode: Bool { currentMode == .guest }
    var hasActiveSession: Bool { currentMode != .none }

    private init() {
        print("🚪 [SESSION] Initialized — mode: \(currentMode.rawValue), deviceId: \(deviceId)")
    }

    // MARK: - Session Lifecycle

    /// Start a fresh guest session (local-only, no Supabase).
    /// Always pairs with LogManager guest initialisation so that
    /// getCurrentUserId() never returns nil for a guest user.
    func startGuestSession() {
        print("🚪 [SESSION] Starting GUEST session with deviceId: \(deviceId)")
        currentMode = .guest
        lastUserId = nil
        AppState.isLoginCompleted = true

        // Ensure guest user is always initialised in SQLite
        LogManager.shared.initializeGuestUser()
    }

    /// Transition to account session after successful Supabase auth
    func startAccountSession(userId: String) {
        print("🚪 [SESSION] Starting ACCOUNT session for userId: \(userId)")
        currentMode = .account
        lastUserId = userId

        AppState.isLoginCompleted = true
    }

    /// End the current session (sign-out).
    /// Invalidates the Supabase JWT keychain token so that restoreSession()
    /// cannot silently resurrect a session the user explicitly ended.
    func endSession() async {
        print("🚪 [SESSION] Ending session (was: \(currentMode.rawValue))")
        currentMode = .none
        lastUserId = nil
        lastSyncTimestamp = "1970-01-01T00:00:00Z"

        AppState.isLoginCompleted = false
        AppState.isOnboardingCompleted = false

        // Clear the in-memory insight cache so the next user never sees stale data
        LogManager.shared.cachedHomeInsight = nil

        // Clear account-specific UserDefaults but PRESERVE deviceId
        let preservedDeviceId = deviceId

        let keysToRemove = [
            AppState.kLoginCompleted,
            AppState.kOnboardingCompleted,
            Keys.lastUserId,
            Keys.lastSyncDate,
            "lastDailyTaskRefreshDate"
        ]
        for key in keysToRemove {
            UserDefaults.standard.removeObject(forKey: key)
        }

        // Restore preserved values
        UserDefaults.standard.set(preservedDeviceId, forKey: Keys.deviceId)
        UserDefaults.standard.set(UserMode.none.rawValue, forKey: Keys.userMode)

        // Invalidate the Supabase JWT stored in the keychain so that
        // restoreSession() cannot restore this session on next launch.
        try? await SupabaseManager.shared.client.auth.signOut()

        print("🚪 [SESSION] Session ended. DeviceId preserved: \(preservedDeviceId)")
    }

    /// Restore session on app launch — determines which mode to enter
    func restoreSession() async -> UserMode {
        print("🚪 [SESSION] Restoring session... stored mode: \(currentMode.rawValue)")

        switch currentMode {
        case .guest:
            // Guest sessions restore instantly — no network needed
            print("🚪 [SESSION] Restored GUEST session")
            return .guest

        case .account:
            // Validate the Supabase session token
            do {
                let session = try await SupabaseManager.shared.client.auth.session
                if !session.isExpired {
                    print("🚪 [SESSION] Restored ACCOUNT session (token valid)")
                    return .account
                } else {
                    print("🚪 [SESSION] Account session expired — falling back to none")
                    currentMode = .none
                    return .none
                }
            } catch {
                print("🚪 [SESSION] Failed to validate account session: \(error)")
                currentMode = .none
                return .none
            }

        case .none:
            print("🚪 [SESSION] No previous session found")
            return .none
        }
    }

    // MARK: - Sync Helpers

    /// Whether a Supabase call is allowed right now
    func canAccessSupabase() -> Bool {
        return isAccountMode
    }

    /// Log a blocked Supabase call attempt (for debugging)
    func logBlockedSupabaseCall(_ functionName: String) {
        print("🚫 [GUARD] Supabase call BLOCKED in \(currentMode.rawValue) mode: \(functionName)")
    }
}
