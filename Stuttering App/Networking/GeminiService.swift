//
//  GeminiService.swift
//  Spasht
//
//  Gemini API fallback for insight generation when
//  the on-device Foundation Model is unavailable.
//

import Foundation

class GeminiService {

    static let shared = GeminiService()

    // TODO: Move to Secrets.xcconfig before production release
    //private let apiKey = "AIzaSyCfnymFZk7hNphydaKhNPhJUwDv1HvSEV0"
    private let apiKey = "AIzaSyAMIzqsMXTPLGB0hOE93Oeyn-zPmuf4Bm4"
    private let model  = "gemini-3.0-flash"

    private var baseURL: String {
        "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
    }

    /// Max retries for rate-limited (429) responses
    private let maxRetries = 3

    private init() {}

    // MARK: - Public API

    /// Send a prompt with system instructions to Gemini and return the text response.
    /// Returns `nil` on any failure so the caller can fall back to rule-based logic.
    func generate(systemInstruction: String, prompt: String) async -> String? {
        guard let url = URL(string: baseURL) else {
            print("GeminiService: Invalid URL")
            return nil
        }

        let body: [String: Any] = [
            "system_instruction": [
                "parts": [
                    ["text": systemInstruction]
                ]
            ],
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.7,
                "maxOutputTokens": 200
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            print("GeminiService: Failed to serialize request body")
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 10

        return await performWithRetry(request: request, label: "Generate")
    }

    // MARK: - Multi-Turn Chat (Conversation Mode)

    /// Send a multi-turn conversation to Gemini.
    /// `history` is an array of (role: "user"/"model", text: String) tuples.
    /// Returns `nil` on any failure.
    func generateChat(systemInstruction: String,
                      history: [(role: String, text: String)],
                      latestUserMessage: String) async -> String? {
        guard let url = URL(string: baseURL) else { return nil }

        var contents: [[String: Any]] = history.map { turn in
            [
                "role": turn.role,
                "parts": [["text": turn.text]]
            ]
        }
        contents.append([
            "role": "user",
            "parts": [["text": latestUserMessage]]
        ])

        let body: [String: Any] = [
            "system_instruction": [
                "parts": [["text": systemInstruction]]
            ],
            "contents": contents,
            "generationConfig": [
                "temperature": 0.8,
                "maxOutputTokens": 150
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 12

        return await performWithRetry(request: request, label: "Chat")
    }

    // MARK: - Long-Form Generation (Paragraph Generator)

    /// Generate long-form content (e.g., reading passages).
    /// Uses a higher token limit and longer timeout than the insight generator.
    func generateLongForm(systemInstruction: String, prompt: String) async -> String? {
        guard let url = URL(string: baseURL) else { return nil }

        let body: [String: Any] = [
            "system_instruction": [
                "parts": [["text": systemInstruction]]
            ],
            "contents": [
                [
                    "parts": [["text": prompt]]
                ]
            ],
            "generationConfig": [
                "temperature": 0.75,
                "maxOutputTokens": 4096
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 30

        return await performWithRetry(request: request, label: "LongForm")
    }

    // MARK: - Retry Logic

    /// Performs the URLRequest with automatic retry + exponential backoff on 429 (rate limit).
    private func performWithRetry(request: URLRequest, label: String) async -> String? {
        for attempt in 0..<maxRetries {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let http = response as? HTTPURLResponse else {
                    print("GeminiService: \(label) — no HTTP response")
                    return nil
                }

                if (200...299).contains(http.statusCode) {
                    return extractText(from: data)
                }

                if http.statusCode == 429 {
                    // Exponential backoff: 2s, 4s, 8s
                    let delay = pow(2.0, Double(attempt + 1))
                    print("GeminiService: \(label) rate-limited (429). Retrying in \(Int(delay))s (attempt \(attempt + 1)/\(maxRetries))...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }

                // Other HTTP errors — don't retry
                print("GeminiService: \(label) HTTP \(http.statusCode)")
                return nil

            } catch is CancellationError {
                return nil
            } catch {
                print("GeminiService: \(label) error — \(error.localizedDescription)")
                return nil
            }
        }

        print("GeminiService: \(label) — exhausted all \(maxRetries) retries")
        return nil
    }

    // MARK: - Response Parsing

    /// Extracts the text from the Gemini API JSON response.
    /// Response shape: { "candidates": [{ "content": { "parts": [{ "text": "..." }] } }] }
    private func extractText(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            print("GeminiService: Failed to parse response")
            return nil
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
