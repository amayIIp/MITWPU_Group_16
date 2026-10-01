//
//  LocalDataSnapshot.swift
//  Spasht
//
//  Makes signing in transactional.
//
//  The login sequence resets all three local databases and *then* pulls the
//  user's data down from the cloud. If that download fails — a dropped
//  connection, an expired token, a Supabase blip — the databases have already
//  been wiped, and the user is left signed in with nothing while the error
//  message talks about their password. That is a data-loss bug reachable by
//  anyone on a bad connection.
//
//  `syncAllDataFromCloud()` interleaves four fetch-and-write stages, so
//  "download everything first, then write" would mean restructuring it. This
//  takes the other route: photocopy the databases before the destructive step
//  and put them back if anything downstream throws. The sync internals stay
//  untouched, and the guarantee holds no matter which stage fails.
//

import Foundation

struct LocalDataSnapshot {

    /// The three SQLite files, paired with the manager that owns the connection.
    private static let databases = [
        "ExerciseDatabase.sqlite",
        "Spasht.sqlite",
        "AwardsDB.sqlite"
    ]

    private let backupDirectory: URL
    private let capturedFiles: [String]

    // MARK: - Capture

    /// Copies the current databases somewhere safe. Returns nil if nothing could
    /// be captured, in which case the caller proceeds as before — a snapshot
    /// that cannot be taken must not block a login.
    static func capture() -> LocalDataSnapshot? {
        let fm = FileManager.default
        guard let documents = try? fm.url(for: .documentDirectory, in: .userDomainMask,
                                          appropriateFor: nil, create: false) else { return nil }

        let backup = fm.temporaryDirectory
            .appendingPathComponent("login-snapshot-\(UUID().uuidString)", isDirectory: true)

        do {
            try fm.createDirectory(at: backup, withIntermediateDirectories: true)
        } catch {
            print("⚠️ [SNAPSHOT] Could not create backup directory: \(error.localizedDescription)")
            return nil
        }

        var captured: [String] = []
        for name in databases {
            let source = documents.appendingPathComponent(name)
            guard fm.fileExists(atPath: source.path) else { continue }
            do {
                try fm.copyItem(at: source, to: backup.appendingPathComponent(name))
                captured.append(name)
            } catch {
                print("⚠️ [SNAPSHOT] Could not copy \(name): \(error.localizedDescription)")
            }
        }

        guard !captured.isEmpty else {
            try? fm.removeItem(at: backup)
            return nil
        }

        print("📸 [SNAPSHOT] Captured \(captured.count) database(s)")
        return LocalDataSnapshot(backupDirectory: backup, capturedFiles: captured)
    }

    // MARK: - Restore / discard

    /// Puts the captured databases back and reopens them.
    ///
    /// Every connection is closed before any file is swapped: replacing a SQLite
    /// file underneath a live connection is how you turn a recoverable failure
    /// into a corrupt database.
    func restore() {
        let fm = FileManager.default
        guard let documents = try? fm.url(for: .documentDirectory, in: .userDomainMask,
                                          appropriateFor: nil, create: false) else { return }

        LogManager.shared.closeDatabaseForRestore()
        DatabaseManager.shared.closeDatabaseForRestore()
        AwardsManager.shared.closeDatabaseForRestore()

        for name in capturedFiles {
            let source = backupDirectory.appendingPathComponent(name)
            let destination = documents.appendingPathComponent(name)
            do {
                if fm.fileExists(atPath: destination.path) {
                    try fm.removeItem(at: destination)
                }
                try fm.copyItem(at: source, to: destination)
            } catch {
                print("⚠️ [SNAPSHOT] Could not restore \(name): \(error.localizedDescription)")
            }
        }

        LogManager.shared.reopenDatabaseAfterRestore()
        DatabaseManager.shared.reopenDatabaseAfterRestore()
        AwardsManager.shared.reopenDatabaseAfterRestore()

        cleanUp()
        print("♻️ [SNAPSHOT] Restored \(capturedFiles.count) database(s) after a failed sign-in")
    }

    /// Throws the copy away once the sign-in has succeeded.
    func discard() {
        cleanUp()
    }

    private func cleanUp() {
        try? FileManager.default.removeItem(at: backupDirectory)
    }
}
