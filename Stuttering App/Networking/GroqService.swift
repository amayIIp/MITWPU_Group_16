//
//  GroqService.swift
//  Stuttering App
//
//  Groq API service for conversation mode.
//  Uses the OpenAI-compatible chat completions endpoint
//  with Llama 3.3 70B for fast, reliable responses.
//

import Foundation

class GroqService {

    static let shared = GroqService()

    // TODO: Move to Secrets.xcconfig before production release
    private let apiKey = "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"
    private let model  = "llama-3.3-70b-versatile"

    private let baseURL = "https://api.groq.com/openai/v1/chat/completions"

    /// Max retries for rate-limited (429) responses
    private let maxRetries = 3

    private init() {}

    // MARK: - Single-Turn Generation (Insight Engine)

    /// Send a prompt with system instructions to Groq and return the text response.
    /// Returns `nil` on any failure so the caller can fall back to rule-based logic.
    func generate(systemInstruction: String, prompt: String) async -> String? {
        guard let url = URL(string: baseURL) else {
            print("GroqService: Invalid URL")
            return nil
        }

        let messages: [[String: String]] = [
            ["role": "system", "content": systemInstruction],
            ["role": "user",   "content": prompt]
        ]

        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": 0.7,
            "max_tokens": 200
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            print("GroqService: Failed to serialize request body")
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 10

        return await performWithRetry(request: request, label: "Generate")
    }

    // MARK: - Long-Form Generation (Paragraph Generator)

    /// Generate long-form content (e.g., reading passages).
    /// Uses a higher token limit and longer timeout than the insight generator.
    func generateLongForm(systemInstruction: String, prompt: String) async -> String? {
        guard let url = URL(string: baseURL) else {
            print("GroqService: Invalid URL")
            return nil
        }

        let messages: [[String: String]] = [
            ["role": "system", "content": systemInstruction],
            ["role": "user",   "content": prompt]
        ]

        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": 0.75,
            "max_tokens": 4096
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            print("GroqService: Failed to serialize request body")
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 30

        return await performWithRetry(request: request, label: "LongForm")
    }

    // MARK: - Multi-Turn Chat (Conversation Mode)

    /// Send a multi-turn conversation to Groq.
    /// `history` is an array of (role: "user"/"assistant", text: String) tuples.
    /// Returns `nil` on any failure so the caller can fall back gracefully.
    func generateChat(systemInstruction: String,
                      history: [(role: String, text: String)],
                      latestUserMessage: String) async -> String? {
        guard let url = URL(string: baseURL) else {
            print("GroqService: Invalid URL")
            return nil
        }

        // Build OpenAI-style messages array
        var messages: [[String: String]] = [
            ["role": "system", "content": systemInstruction]
        ]

        for turn in history {
            messages.append(["role": turn.role, "content": turn.text])
        }

        messages.append(["role": "user", "content": latestUserMessage])

        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": 0.8,
            "max_tokens": 150
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            print("GroqService: Failed to serialize request body")
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 15

        return await performWithRetry(request: request, label: "Chat")
    }

    // MARK: - Retry Logic

    /// Performs the URLRequest with automatic retry + exponential backoff on 429 (rate limit).
    private func performWithRetry(request: URLRequest, label: String) async -> String? {
        for attempt in 0..<maxRetries {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let http = response as? HTTPURLResponse else {
                    print("GroqService: \(label) — no HTTP response")
                    return nil
                }

                if (200...299).contains(http.statusCode) {
                    return extractText(from: data)
                }

                if http.statusCode == 429 {
                    // Exponential backoff: 2s, 4s, 8s
                    let delay = pow(2.0, Double(attempt + 1))
                    print("GroqService: \(label) rate-limited (429). Retrying in \(Int(delay))s (attempt \(attempt + 1)/\(maxRetries))...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }

                // Other HTTP errors — log and don't retry
                if let errorBody = String(data: data, encoding: .utf8) {
                    print("GroqService: \(label) HTTP \(http.statusCode) — \(errorBody)")
                } else {
                    print("GroqService: \(label) HTTP \(http.statusCode)")
                }
                return nil

            } catch is CancellationError {
                return nil
            } catch {
                print("GroqService: \(label) error — \(error.localizedDescription)")
                return nil
            }
        }

        print("GroqService: \(label) — exhausted all \(maxRetries) retries")
        return nil
    }

    // MARK: - Response Parsing

    /// Extracts the text from the Groq (OpenAI-compatible) JSON response.
    /// Response shape: { "choices": [{ "message": { "role": "assistant", "content": "..." } }] }
    private func extractText(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            print("GroqService: Failed to parse response")
            if let raw = String(data: data, encoding: .utf8) {
                print("GroqService: Raw response — \(raw.prefix(500))")
            }
            return nil
        }

        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
