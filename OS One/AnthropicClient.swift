//
//  AnthropicClient.swift
//  OS One
//
//  Claude Haiku 4.5 API integration - simple, fast, no BS
//  Auto-fallback to local models if API fails
//

import Foundation
import Combine

// MARK: - Anthropic API Client

class AnthropicClient: ObservableObject {

    // MARK: - Published Properties
    @Published var isConnected: Bool = false
    @Published var lastError: String?
    @Published var useHaiku: Bool = false {
        didSet {
            UserDefaults.standard.set(useHaiku, forKey: "useHaikuModel")
        }
    }

    // MARK: - Configuration
    private let apiEndpoint = "https://api.anthropic.com/v1/messages"
    private let model = "claude-4-haiku-20250514"
    private let apiVersion = "2023-06-01"

    // MARK: - API Key Management (Keychain)
    private let keychainService = "com.osone.anthropic"
    private let keychainAccount = "api-key"

    var hasAPIKey: Bool {
        getAPIKey() != nil
    }

    // MARK: - Initialization
    init() {
        self.useHaiku = UserDefaults.standard.bool(forKey: "useHaikuModel")

        if hasAPIKey {
            Task {
                await testConnection()
            }
        }
    }

    // MARK: - API Key Storage

    func saveAPIKey(_ key: String) {
        // Save to Keychain
        let data = key.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data
        ]

        // Delete existing
        SecItemDelete(query as CFDictionary)

        // Add new
        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecSuccess {
            print("✅ API key saved securely")
            Task {
                await testConnection()
            }
        } else {
            print("❌ Failed to save API key: \(status)")
        }
    }

    func getAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess,
           let data = result as? Data,
           let key = String(data: data, encoding: .utf8) {
            return key
        }

        return nil
    }

    func deleteAPIKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]

        SecItemDelete(query as CFDictionary)
        isConnected = false
        useHaiku = false
        print("🗑️ API key deleted")
    }

    // MARK: - Connection Test

    @MainActor
    func testConnection() async -> Bool {
        guard let apiKey = getAPIKey() else {
            lastError = "no api key - add one in settings"
            isConnected = false
            return false
        }

        do {
            // Simple test message
            let response = try await generate(
                prompt: "respond with just 'ok'",
                maxTokens: 10
            )

            isConnected = true
            lastError = nil
            print("✅ Haiku 4.5 connection successful")
            return true

        } catch let error as AnthropicError {
            isConnected = false
            lastError = error.userMessage
            print("❌ Connection failed: \(error.userMessage)")
            return false

        } catch {
            isConnected = false
            lastError = "connection test failed - check your internet?"
            print("❌ Connection test failed: \(error)")
            return false
        }
    }

    // MARK: - Generate (Simple)

    func generate(
        prompt: String,
        systemPrompt: String? = nil,
        maxTokens: Int = 1024,
        temperature: Double = 0.7
    ) async throws -> String {

        guard let apiKey = getAPIKey() else {
            throw AnthropicError.noAPIKey
        }

        // Build request
        var messages: [[String: Any]] = [
            [
                "role": "user",
                "content": prompt
            ]
        ]

        var requestBody: [String: Any] = [
            "model": model,
            "messages": messages,
            "max_tokens": maxTokens,
            "temperature": temperature,
            "stream": false
        ]

        if let systemPrompt = systemPrompt {
            requestBody["system"] = systemPrompt
        }

        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

        var request = URLRequest(url: URL(string: apiEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.httpBody = jsonData

        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)

        // Handle response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AnthropicError.networkError("invalid response")
        }

        // Check for errors
        if httpResponse.statusCode != 200 {
            let errorResponse = try? JSONDecoder().decode(AnthropicErrorResponse.self, from: data)
            throw AnthropicError.fromStatusCode(httpResponse.statusCode, message: errorResponse?.error.message)
        }

        // Parse response
        let apiResponse = try JSONDecoder().decode(AnthropicResponse.self, from: data)

        // Extract text
        let text = apiResponse.content.first?.text ?? ""
        return text
    }

    // MARK: - Generate Stream

    func generateStream(
        prompt: String,
        systemPrompt: String? = nil,
        maxTokens: Int = 1024,
        temperature: Double = 0.7
    ) -> AsyncThrowingStream<String, Error> {

        return AsyncThrowingStream { continuation in
            Task {
                guard let apiKey = getAPIKey() else {
                    continuation.finish(throwing: AnthropicError.noAPIKey)
                    return
                }

                do {
                    // Build request
                    var messages: [[String: Any]] = [
                        [
                            "role": "user",
                            "content": prompt
                        ]
                    ]

                    var requestBody: [String: Any] = [
                        "model": model,
                        "messages": messages,
                        "max_tokens": maxTokens,
                        "temperature": temperature,
                        "stream": true
                    ]

                    if let systemPrompt = systemPrompt {
                        requestBody["system"] = systemPrompt
                    }

                    let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

                    var request = URLRequest(url: URL(string: apiEndpoint)!)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                    request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
                    request.httpBody = jsonData

                    // Stream response
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw AnthropicError.networkError("invalid response")
                    }

                    if httpResponse.statusCode != 200 {
                        throw AnthropicError.fromStatusCode(httpResponse.statusCode)
                    }

                    // Parse SSE stream
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))

                            if jsonString == "[DONE]" {
                                continuation.finish()
                                return
                            }

                            if let data = jsonString.data(using: .utf8),
                               let event = try? JSONDecoder().decode(StreamEvent.self, from: data) {

                                switch event.type {
                                case "content_block_delta":
                                    if let delta = event.delta,
                                       let text = delta.text {
                                        continuation.yield(text)
                                    }

                                case "message_stop":
                                    continuation.finish()
                                    return

                                default:
                                    break
                                }
                            }
                        }
                    }

                    continuation.finish()

                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - Response Models

struct AnthropicResponse: Codable {
    let id: String
    let type: String
    let role: String
    let content: [ContentBlock]
    let model: String
    let stop_reason: String?
    let usage: Usage

    struct ContentBlock: Codable {
        let type: String
        let text: String?
    }

    struct Usage: Codable {
        let input_tokens: Int
        let output_tokens: Int
    }
}

struct StreamEvent: Codable {
    let type: String
    let delta: Delta?

    struct Delta: Codable {
        let type: String?
        let text: String?
    }
}

struct AnthropicErrorResponse: Codable {
    let error: ErrorDetail

    struct ErrorDetail: Codable {
        let type: String
        let message: String
    }
}

// MARK: - Errors

enum AnthropicError: LocalizedError {
    case noAPIKey
    case invalidAPIKey
    case rateLimited
    case networkError(String)
    case serverError
    case unknown

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API Key"
        case .invalidAPIKey:
            return "Invalid API Key"
        case .rateLimited:
            return "Rate Limited"
        case .networkError(let message):
            return "Network Error: \(message)"
        case .serverError:
            return "Server Error"
        case .unknown:
            return "Unknown Error"
        }
    }

    var userMessage: String {
        switch self {
        case .noAPIKey:
            return "no api key - add one in settings"
        case .invalidAPIKey:
            return "api key doesn't work - check it?"
        case .rateLimited:
            return "rate limited - chill for a sec, then retry"
        case .networkError:
            return "no internet - using local model instead"
        case .serverError:
            return "anthropic's servers are down - using local instead"
        case .unknown:
            return "something went wrong - using local model"
        }
    }

    static func fromStatusCode(_ code: Int, message: String? = nil) -> AnthropicError {
        switch code {
        case 401:
            return .invalidAPIKey
        case 429:
            return .rateLimited
        case 500...599:
            return .serverError
        default:
            return .networkError(message ?? "status \(code)")
        }
    }
}

// MARK: - Model Type Extension

enum ModelProvider: String {
    case local = "local"
    case haiku = "haiku"

    var displayName: String {
        switch self {
        case .local:
            return "🔒 Local (Private)"
        case .haiku:
            return "⚡ Haiku 4.5 (Fast)"
        }
    }

    var icon: String {
        switch self {
        case .local:
            return "🔒"
        case .haiku:
            return "⚡"
        }
    }
}
