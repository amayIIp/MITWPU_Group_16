//
//  AudioSessionManager.swift
//  Stuttering App
//
//  Created by Prathamesh Patil on 15/03/26.
//

import AVFoundation

final class AudioSessionManager {

    static let shared = AudioSessionManager()
    private var isSessionActive = false
    private init() {}

    // Call this once — from AppDelegate or the PARENT screen.
    // By the time the user navigates to the record screen,
    // the session is already warmed up and setActive is a no-op.
    func prewarmRecordSession() {
        guard !isSessionActive else { return }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playAndRecord, mode: .default)
                try session.setActive(true)
                self.isSessionActive = true
                print("✅ Audio session pre-warmed successfully.")
            } catch {
                print("⚠️ Audio session pre-warm failed: \(error.localizedDescription)")
            }
        }
    }

    func deactivateSession() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            try? AVAudioSession.sharedInstance().setActive(false)
            self.isSessionActive = false
        }
    }
}
