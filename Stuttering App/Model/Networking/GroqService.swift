//
//  GroqService.swift
//  Stuttering App
//
//  Groq-backed text generation, routed through the `groq-chat` Edge Function.
//
//  The Groq API key used to live here as a Swift string constant, which meant it
//  shipped inside the app binary and was recoverable from the IPA with `strings`
//  — anyone could bill inference to the account. The key now exists only as a
//  function secret; this client sends the caller's Supabase session instead, or
//  a device id when the user is a guest with no account.
//
//  The request and response shapes are unchanged (OpenAI-compatible chat
//  completions), so `extractText` and the retry logic still apply as written.
//

import Foundation
import Supabase

class GroqService {

    static let shared = GroqService()

    /// The `groq-chat` Edge Function. The model is chosen server-side now, so
    /// changing it no longer needs an app update.
    private let baseURL = "https://zolaxhyjzkvupkmogdpo.supabase.co/functions/v1/groq-chat"

    /// Max retries for rate-limited (429) responses
    private let maxRetries = 3

    private init() {}

    /// The AI features are account-only (decision D6).
    ///
    /// This is what lets the `groq-chat` Edge Function require a real user
    /// token instead of accepting anonymous callers, and it keeps guest mode
    /// genuinely local-only: nothing a guest does leaves the device.
    ///
    /// Every caller already handles a nil return by falling back to
    /// rule-based text, so guests degrade rather than break. The conversation
    /// partner is the exception — its fallback is an apology loop — so that
    /// feature is gated at the screen instead, in `VoiceViewController`.
    ///
    /// Signed-in users must also have agreed to share data with Groq, which is
    /// what Guideline 5.1.2(i) requires before anything is sent — see `AIConsent`.
    var isAvailable: Bool { SessionManager.shared.isAccountMode && AIConsent.isGranted }

    // MARK: - Request construction

    /// Builds a request to the proxy.
    ///
    /// Always authorised with the user's Supabase session — `isAvailable` has
    /// already established there is an account, and the `groq-chat` function
    /// refuses anything that isn't a real user token. There is deliberately no
    /// anonymous or device-id path; an earlier version had one, back when guests
    /// could use the AI features.
    private func proxiedRequest(messages: [[String: String]],
                                temperature: Double,
                                maxTokens: Int,
                                timeout: TimeInterval) async -> URLRequest? {
        guard let url = URL(string: baseURL) else {
            print("GroqService: Invalid URL")
            return nil
        }

        let body: [String: Any] = [
            "messages": messages,
            "temperature": temperature,
            "max_tokens": maxTokens
        ]

        // Account-only, so there is always a session here. No anonymous
        // fallback: the proxy requires a real user token.
        guard let session = try? await SupabaseManager.shared.client.auth.session,
              !session.isExpired else {
            print("GroqService: no valid session — skipping AI call")
            return nil
        }
        let token = session.accessToken

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            print("GroqService: Failed to serialize request body")
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = timeout
        return request
    }

    // MARK: - Single-Turn Generation (Insight Engine)

    /// Send a prompt with system instructions to Groq and return the text response.
    /// Returns `nil` on any failure so the caller can fall back to rule-based logic.
    func generate(systemInstruction: String, prompt: String) async -> String? {
        guard isAvailable else { return nil }

        let messages: [[String: String]] = [
            ["role": "system", "content": systemInstruction],
            ["role": "user", "content": prompt]
        ]

        guard let request = await proxiedRequest(messages: messages,
                                                 temperature: 0.7,
                                                 maxTokens: 200,
                                                 timeout: 10) else { return nil }

        return await performWithRetry(request: request, label: "Generate")
    }

    // MARK: - Long-Form Generation (Paragraph Generator)

    /// Generate long-form content (e.g., reading passages).
    /// Uses a higher token limit and longer timeout than the insight generator.
    func generateLongForm(systemInstruction: String, prompt: String) async -> String? {
        guard isAvailable else { return nil }

        let messages: [[String: String]] = [
            ["role": "system", "content": systemInstruction],
            ["role": "user", "content": prompt]
        ]

        guard let request = await proxiedRequest(messages: messages,
                                                 temperature: 0.75,
                                                 maxTokens: 4096,
                                                 timeout: 30) else { return nil }

        return await performWithRetry(request: request, label: "LongForm")
    }

    // MARK: - Multi-Turn Chat (Conversation Mode)

    /// Send a multi-turn conversation to Groq.
    /// `history` is an array of (role: "user"/"assistant", text: String) tuples.
    /// Returns `nil` on any failure so the caller can fall back gracefully.
    func generateChat(systemInstruction: String,
                      history: [(role: String, text: String)],
                      latestUserMessage: String) async -> String? {
        guard isAvailable else { return nil }

        // Build OpenAI-style messages array
        var messages: [[String: String]] = [
            ["role": "system", "content": systemInstruction]
        ]

        for turn in history {
            messages.append(["role": turn.role, "content": turn.text])
        }

        messages.append(["role": "user", "content": latestUserMessage])

        guard let request = await proxiedRequest(messages: messages,
                                                 temperature: 0.8,
                                                 maxTokens: 150,
                                                 timeout: 15) else { return nil }

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
