//
//  UploadSessionManager.swift
//  Stuttering App
//
//  Manages local upload state and initiates uploads via SpashtUploader.
//

import Foundation
import SwiftUI

enum UploadStatus: String, Codable {
    case pending
    case uploading
    case success
    case failed
}

struct MLSession: Identifiable, Codable {
    let id: String // e.g., your sessionId
    let date: Date
    var uploadStatus: UploadStatus
    var localAudioURL: URL?
}

@MainActor
class UploadSessionManager: ObservableObject {
    @Published var sessions: [MLSession] = []
    
    static let shared = UploadSessionManager()
    
    private var uploadsDirectory: URL {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let cacheDirectory = paths[0].appendingPathComponent("SpashtUploads")
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        return cacheDirectory
    }
    
    private init() {
        loadSessions()
        
        // Listen for network connectivity coming back online
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNetworkConnected),
            name: NSNotification.Name("NetworkMonitorConnected"),
            object: nil
        )
        
        // Attempt retry of all pending/failed uploads on launch
        Task {
            await retryAllPendingUploads()
        }
    }
    
    @objc private func handleNetworkConnected() {
        Task {
            await retryAllPendingUploads()
        }
    }
    
    private func saveSessions() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: "UploadSessionManager.sessions")
        }
    }
    
    private func loadSessions() {
        if let data = UserDefaults.standard.data(forKey: "UploadSessionManager.sessions"),
           let decoded = try? JSONDecoder().decode([MLSession].self, from: data) {
            self.sessions = decoded
        }
    }
    
    // Call this immediately after a reading session finishes
    func registerAndUpload(sessionId: String, audioURL: URL) {
        // Copy audio file to persistent cache directory to survive OS temp cleanup
        let destinationURL = uploadsDirectory.appendingPathComponent("\(sessionId).wav")
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try? FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: audioURL, to: destinationURL)
            
            let newSession = MLSession(id: sessionId, date: Date(), uploadStatus: .pending, localAudioURL: destinationURL)
            sessions.insert(newSession, at: 0)
            saveSessions()
            
            Task {
                await processUpload(for: newSession)
            }
        } catch {
            print("Failed to save audio file locally: \(error)")
        }
    }
    
    func retryAllPendingUploads() async {
        guard NetworkMonitor.shared.isConnected else { return }
        
        let pending = sessions.filter { $0.uploadStatus == .pending || $0.uploadStatus == .failed }
        for session in pending {
            await processUpload(for: session)
        }
    }
    
    private func processUpload(for session: MLSession) async {
        guard let audioURL = session.localAudioURL, 
              let index = sessions.firstIndex(where: { $0.id == session.id }) else { return }
        
        // Ensure network is active
        guard NetworkMonitor.shared.isConnected else {
            sessions[index].uploadStatus = .failed
            saveSessions()
            return
        }
        
        sessions[index].uploadStatus = .uploading
        saveSessions()
        
        do {
            let success = try await SpashtUploader.shared.uploadSessionData(
                sessionId: session.id,
                audioFileURL: audioURL
            )
            if success {
                // Remove the session from queue on successful upload to clean up memory
                sessions.removeAll(where: { $0.id == session.id })
                // Delete local file to save space
                let cachedFile = uploadsDirectory.appendingPathComponent("\(session.id).wav")
                try? FileManager.default.removeItem(at: cachedFile)
                saveSessions()
            }
        } catch {
            print("Upload failed for \(session.id): \(error)")
            sessions[index].uploadStatus = .failed
            saveSessions()
        }
    }
}
