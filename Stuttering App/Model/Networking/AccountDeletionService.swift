//
//  AccountDeletionService.swift
//  Spasht
//
//  Guideline 5.1.1(v): an app that supports account creation must let the user
//  delete that account from inside the app. Apple is explicit that temporary
//  deactivation is not enough, that user-generated content goes too, and that
//  automatically generated accounts — guest mode, here — are included.
//
//  The cloud half runs in the `delete-account` Edge Function, because deleting
//  an auth.users row needs the service role key, which must never ship in an
//  app. This type owns the local half and the ordering between them.
//

import Foundation
import Supabase

@MainActor
final class AccountDeletionService {

    static let shared = AccountDeletionService()
    private init() {}

    enum DeletionError: LocalizedError {
        case notSignedIn
        case serverRefused(String)

        var errorDescription: String? {
            switch self {
            case .notSignedIn:
                return "You're not signed in, so there's no account to delete."
            case .serverRefused(let reason):
                return "We couldn't delete your account: \(reason)"
            }
        }
    }

    // MARK: - Deletion

    /// Deletes the signed-in account: the Supabase auth record, every cloud row,
    /// the Apple token grant, and all local data.
    ///
    /// The cloud call goes first on purpose. If it fails the user keeps their
    /// data and sees an error, which is recoverable; wiping locally first and
    /// then failing would destroy their history while leaving the account alive
    /// — the worst of both outcomes.
    func deleteAccount() async throws {
        guard SessionManager.shared.isAccountMode else { throw DeletionError.notSignedIn }

        do {
            _ = try await SupabaseManager.shared.client.functions
                .invoke("delete-account", options: .init(method: .post))
        } catch {
            throw DeletionError.serverRefused(error.localizedDescription)
        }

        await wipeEverythingLocal()
    }

    // MARK: - Apple

    /// Hands Apple's single-use authorization code to the backend, which trades
    /// it for a refresh token so deletion can later revoke the grant. Apple's
    /// code expires in about five minutes, so this is called immediately after
    /// sign-in rather than stored for deletion time.
    ///
    /// Best-effort by design: failing to register a code must never block a
    /// sign-in the user has already completed.
    func registerAppleAuthorizationCode(_ code: String) async {
        do {
            _ = try await SupabaseManager.shared.client.functions.invoke(
                "apple-register-code",
                options: .init(method: .post, body: ["authorization_code": code])
            )
        } catch {
            print("⚠️ [DELETION] Apple code registration failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Local teardown

    private func wipeEverythingLocal() async {
        // Media first: the databases hold the filenames, so wiping them first
        // would orphan the files on disk with no way to find them again.
        deleteUserMediaFiles()

        // The cloud copy goes with the storage objects the `delete-account`
        // Edge Function removes; this is the local cache.
        AvatarStore.removeAllLocal()

        LogManager.shared.resetDatabaseForNewUser()
        DatabaseManager.shared.resetDatabaseForNewUser()
        AwardsManager.shared.resetDatabaseForNewUser()
        AppState.resetModuleOnboarding()
        LogManager.shared.cachedHomeInsight = nil

        NotificationManager.shared.cancelAllNotifications()

        // Keyed by user id, so it goes with everything else identifying.
        AIConsent.removeAll()

        // Clears session state and signs out of Supabase, invalidating the
        // keychain JWT so restoreSession() can't resurrect the account.
        await SessionManager.shared.endSession()

        // endSession() deliberately preserves deviceId, which is right for a
        // sign-out and wrong here — after a deletion nothing identifying should
        // survive. A fresh id is generated on next use.
        UserDefaults.standard.removeObject(forKey: "session.deviceId")

        print("🗑️ [DELETION] Local teardown complete")
    }

    /// Video diary recordings and Story Cubes audio are written loose into the
    /// Documents directory rather than tracked in a table, so they have to be
    /// swept by extension. Reading-session audio lives in tmp and is already
    /// removed when each session ends.
    private func deleteUserMediaFiles() {
        let fm = FileManager.default
        guard let documents = fm.urls(for: .documentDirectory, in: .userDomainMask).first,
              let contents = try? fm.contentsOfDirectory(at: documents,
                                                         includingPropertiesForKeys: nil) else {
            return
        }

        let mediaExtensions: Set<String> = ["m4a", "mov", "mp4", "wav", "caf"]
        var removed = 0
        for url in contents where mediaExtensions.contains(url.pathExtension.lowercased()) {
            do {
                try fm.removeItem(at: url)
                removed += 1
            } catch {
                print("⚠️ [DELETION] Could not remove \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        print("🗑️ [DELETION] Removed \(removed) media file(s)")
    }
}
