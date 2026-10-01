//
//  AsyncDeadline.swift
//  Spasht
//
//  Gives an async operation a deadline without cancelling it.
//
//  The loading screens in Read Aloud ("Generating your story", "Analysing your
//  reading") used to await on-device model calls with no limit at all. When the
//  model was busy — the launch batch writes six passages back to back — the
//  screen simply never went away.
//
//  A task group can't be used for this: it waits for every child before
//  returning, so a model call that ignores cancellation would hold the caller
//  hostage anyway. Here the operation runs in its own Task and the caller is
//  released at the deadline; the operation keeps going and can still do
//  something useful with its result, like caching it for next time.
//

import Foundation

/// Returns the operation's result, or nil if it hasn't finished within `seconds`.
func withDeadline<T: Sendable>(seconds: TimeInterval,
                               _ operation: @escaping @Sendable () async -> T) async -> T? {
    let gate = ResumeOnce()
    return await withCheckedContinuation { (continuation: CheckedContinuation<T?, Never>) in
        Task {
            let value = await operation()
            if gate.claim() { continuation.resume(returning: value) }
        }
        Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            if gate.claim() { continuation.resume(returning: nil) }
        }
    }
}

/// Lets exactly one of two racing tasks resume a continuation.
private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var claimed = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !claimed else { return false }
        claimed = true
        return true
    }
}
