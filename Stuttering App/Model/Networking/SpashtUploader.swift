//
//  SpashtUploader.swift
//  Stuttering App
//
//  Created to replace GoogleDriveUploader. Uploads raw WAV session audio to Supabase Edge Function.
//

import Foundation

enum UploadError: Error {
    case fileNotFound
    case invalidResponse
    case serverError(String)
}

class SpashtUploader {
    static let shared = SpashtUploader()
    
    // Your live Edge Function URL
    private let edgeFunctionURL = URL(string: "https://woatlzolrisargsmpeji.supabase.co/functions/v1/spasht-drive-upload")!
    
    // Uses the central Supabase key defined in AppSecrets
    private let supabaseAnonKey = AppSecrets.supabaseKey
    
    private init() {}
    
    /// Uploads an audio file to the Supabase Edge Function
    func uploadSessionData(sessionId: String, audioFileURL: URL) async throws -> Bool {
        guard FileManager.default.fileExists(atPath: audioFileURL.path) else {
            throw UploadError.fileNotFound
        }
        
        let audioData = try Data(contentsOf: audioFileURL)
        let boundary = "Boundary-\(UUID().uuidString)"
        
        var request = URLRequest(url: edgeFunctionURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Build the multipart payload
        request.httpBody = createMultipartBody(
            audioData: audioData,
            boundary: boundary,
            fileName: "\(sessionId).wav"
        )
        
        // Execute the upload
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UploadError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            // Optional: Delete local file after successful upload to save space
            try? FileManager.default.removeItem(at: audioFileURL)
            return true
        } else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw UploadError.serverError(errorMessage)
        }
    }
    
    /// Helper to construct the multipart form data format
    private func createMultipartBody(audioData: Data, boundary: String, fileName: String) -> Data {
        var body = Data()
        let lineBreak = "\r\n"
        
        body.append("--\(boundary)\(lineBreak)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audioFile\"; filename=\"\(fileName)\"\(lineBreak)".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\(lineBreak)\(lineBreak)".data(using: .utf8)!)
        body.append(audioData)
        body.append("\(lineBreak)--\(boundary)--\(lineBreak)".data(using: .utf8)!)
        
        return body
    }
}
