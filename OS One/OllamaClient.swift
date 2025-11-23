//
//  OllamaClient.swift
//  OS One
//
//  Ollama integration for macOS - run local models easily
//  Works with Ollama running on localhost
//

import Foundation
import Combine

#if os(macOS)

// MARK: - Ollama Client (macOS Only)
class OllamaClient: ObservableObject {

    // MARK: - Published Properties
    @Published var isConnected: Bool = false
    @Published var isGenerating: Bool = false
    @Published var availableModels: [OllamaModel] = []
    @Published var selectedModel: String = "qwen2.5:3b"
    @Published var lastError: String?

    // MARK: - Configuration
    private var baseURL: String {
        UserDefaults.standard.string(forKey: "ollamaBaseURL") ?? "http://localhost:11434"
    }

    var useOllama: Bool {
        get {
            UserDefaults.standard.bool(forKey: "useOllama")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "useOllama")
        }
    }

    // MARK: - Initialization
    init() {
        selectedModel = UserDefaults.standard.string(forKey: "ollamaSelectedModel") ?? "qwen2.5:3b"

        // Check connection on init
        Task {
            await checkConnection()
        }
    }

    // MARK: - Connection Check
    @MainActor
    func checkConnection() async -> Bool {
        do {
            let url = URL(string: "\(baseURL)/api/tags")!
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                isConnected = false
                lastError = "ollama not running - start it with 'ollama serve'"
                return false
            }

            // Parse available models
            let decoder = JSONDecoder()
            let modelList = try decoder.decode(OllamaModelList.self, from: data)
            availableModels = modelList.models

            isConnected = true
            lastError = nil
            print("✅ Ollama connected - \(availableModels.count) models available")
            return true

        } catch {
            isConnected = false
            lastError = "ollama not running - start it with 'ollama serve'"
            print("❌ Ollama connection failed: \(error)")
            return false
        }
    }

    // MARK: - Generate (Non-Streaming)
    func generate(
        prompt: String,
        systemPrompt: String? = nil,
        temperature: Double = 0.7,
        maxTokens: Int = 1024
    ) async throws -> String {

        guard isConnected else {
            throw OllamaError.notConnected
        }

        let url = URL(string: "\(baseURL)/api/generate")!

        var requestBody: [String: Any] = [
            "model": selectedModel,
            "prompt": prompt,
            "stream": false,
            "options": [
                "temperature": temperature,
                "num_predict": maxTokens
            ]
        ]

        if let systemPrompt = systemPrompt {
            requestBody["system"] = systemPrompt
        }

        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OllamaError.requestFailed
        }

        let result = try JSONDecoder().decode(OllamaResponse.self, from: data)
        return result.response
    }

    // MARK: - Generate Stream
    func generateStream(
        prompt: String,
        systemPrompt: String? = nil,
        temperature: Double = 0.7,
        maxTokens: Int = 1024
    ) -> AsyncThrowingStream<String, Error> {

        return AsyncThrowingStream { continuation in
            Task {
                guard isConnected else {
                    continuation.finish(throwing: OllamaError.notConnected)
                    return
                }

                do {
                    await MainActor.run {
                        isGenerating = true
                    }

                    let url = URL(string: "\(baseURL)/api/generate")!

                    var requestBody: [String: Any] = [
                        "model": selectedModel,
                        "prompt": prompt,
                        "stream": true,
                        "options": [
                            "temperature": temperature,
                            "num_predict": maxTokens
                        ]
                    ]

                    if let systemPrompt = systemPrompt {
                        requestBody["system"] = systemPrompt
                    }

                    let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = jsonData

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode == 200 else {
                        throw OllamaError.requestFailed
                    }

                    for try await line in bytes.lines {
                        if let data = line.data(using: .utf8),
                           let chunk = try? JSONDecoder().decode(OllamaStreamChunk.self, from: data) {

                            if !chunk.response.isEmpty {
                                continuation.yield(chunk.response)
                            }

                            if chunk.done {
                                continuation.finish()
                                await MainActor.run {
                                    isGenerating = false
                                }
                                return
                            }
                        }
                    }

                    continuation.finish()
                    await MainActor.run {
                        isGenerating = false
                    }

                } catch {
                    continuation.finish(throwing: error)
                    await MainActor.run {
                        isGenerating = false
                    }
                }
            }
        }
    }

    // MARK: - Model Management
    func setModel(_ modelName: String) {
        selectedModel = modelName
        UserDefaults.standard.set(modelName, forKey: "ollamaSelectedModel")
    }

    func setBaseURL(_ url: String) {
        UserDefaults.standard.set(url, forKey: "ollamaBaseURL")
        Task {
            await checkConnection()
        }
    }

    // MARK: - Pull Model
    func pullModel(_ modelName: String) async throws {
        let url = URL(string: "\(baseURL)/api/pull")!

        let requestBody: [String: Any] = [
            "name": modelName,
            "stream": false
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OllamaError.pullFailed
        }

        // Refresh available models
        await checkConnection()
    }
}

// MARK: - Models
struct OllamaModel: Codable, Identifiable {
    let name: String
    let modified_at: String
    let size: Int64
    let digest: String?

    var id: String { name }

    var sizeInGB: Double {
        Double(size) / 1_073_741_824.0
    }

    var displaySize: String {
        String(format: "%.1f GB", sizeInGB)
    }
}

struct OllamaModelList: Codable {
    let models: [OllamaModel]
}

struct OllamaResponse: Codable {
    let model: String
    let created_at: String
    let response: String
    let done: Bool
}

struct OllamaStreamChunk: Codable {
    let model: String
    let created_at: String
    let response: String
    let done: Bool
}

// MARK: - Errors
enum OllamaError: LocalizedError {
    case notConnected
    case requestFailed
    case pullFailed

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Ollama Not Connected"
        case .requestFailed:
            return "Request Failed"
        case .pullFailed:
            return "Model Pull Failed"
        }
    }

    var userMessage: String {
        switch self {
        case .notConnected:
            return "ollama not running - start it with 'ollama serve'"
        case .requestFailed:
            return "request failed - check ollama is running"
        case .pullFailed:
            return "failed to pull model - check connection"
        }
    }
}

// MARK: - Popular Models
extension OllamaClient {
    static let popularModels = [
        "qwen2.5:3b",
        "qwen2.5:7b",
        "llama3.2:3b",
        "llama3.2:1b",
        "gemma2:2b",
        "gemma2:9b",
        "mistral:7b",
        "phi3:3.8b"
    ]

    static let modelDescriptions: [String: String] = [
        "qwen2.5:3b": "Qwen 2.5 3B - Fast & smart, 32K context",
        "qwen2.5:7b": "Qwen 2.5 7B - High quality, 128K context",
        "llama3.2:3b": "Llama 3.2 3B - Meta's latest, 128K context",
        "llama3.2:1b": "Llama 3.2 1B - Ultra fast, 128K context",
        "gemma2:2b": "Gemma 2 2B - Google, 8K context",
        "gemma2:9b": "Gemma 2 9B - Google high quality, 8K context",
        "mistral:7b": "Mistral 7B - Excellent quality, 32K context",
        "phi3:3.8b": "Phi-3 - Microsoft, strong reasoning"
    ]
}

#endif
