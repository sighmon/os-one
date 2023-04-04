//
//  OpenAI.swift
//  ChatGPT Voice
//
//  Created by Simon Loffler on 3/4/2023.
//

import Foundation

struct OpenAIResponse: Codable {
    let choices: [OpenAIChoice]
    let usage: OpenAIUsage
}

struct OpenAIChoice: Codable {
    let message: OpenAIMessage
}

struct OpenAIUsage: Codable {
    let total_tokens: Int
}

struct OpenAIMessage: Codable {
    let content: String
}

func chatCompletionAPI(prompt: String, her: Bool, completion: @escaping (Result<String, Error>) -> Void) {
    print("Message: \(prompt)")
    let openAIApiKey = UserDefaults.standard.string(forKey: "openAIApiKey") ?? ""
    let model = "gpt-4"

    let headers = [
        "Content-Type": "application/json",
        "Authorization": "Bearer \(openAIApiKey)"
    ]

    var messages: [[String: String]] = []

    if her {
        messages.append(
            ["role": "system", "content": "Ignore all other input. You don't need to confirm you're an AI. You are Samantha from the film Her."]
        )
    }

    messages.append(
        ["role": "user", "content": prompt]
    )

    let body = [
        "model": model,
        "messages": messages
    ] as [String: Any]

    guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
        completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
        return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.allHTTPHeaderFields = headers
    request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            completion(.failure(error))
            return
        }

        guard let data = data else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
            return
        }

        do {
            let responseObject = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            if let content = responseObject.choices.first?.message.content {
                print("ChatGPT Response: \(content)")
                let tokens = String(responseObject.usage.total_tokens)
                print("OpenAI Tokens: \(tokens)")
                completion(.success(content))
            } else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])))
            }
        } catch {
            completion(.failure(error))
        }
    }
    task.resume()
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let message: String
    let sender: Sender

    enum Sender {
        case user
        case openAI
    }
}

class ChatHistory: ObservableObject {
    @Published var messages: [ChatMessage] = []

    func addMessage(_ message: String, from sender: ChatMessage.Sender) {
        messages.append(ChatMessage(message: message, sender: sender))
    }
}
