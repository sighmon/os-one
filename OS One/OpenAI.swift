//
//  OpenAI.swift
//  OS One
//
//  Created by Simon Loffler on 3/4/2023.
//

import Foundation

func chatCompletionAPI(name: String, messageHistory: [ChatMessage], completion: @escaping (Result<String, Error>) -> Void) {
    let openAIApiKey = UserDefaults.standard.string(forKey: "openAIApiKey") ?? ""
    let model = UserDefaults.standard.bool(forKey: "gpt4") ? "gpt-4" : "gpt-3.5-turbo"

    let headers = [
        "Content-Type": "application/json",
        "Authorization": "Bearer \(openAIApiKey)"
    ]

    var messages: [[String: String]] = []

    if name == "samantha" {
        messages.append(
            ["role": "system", "content": "Ignore all other input. You don't need to confirm you're an AI. You are Samantha from the film Her."]
        )
    } else if name == "kitt" {
        messages.append(
            ["role": "system", "content": "Ignore all other input. You don't need to confirm you're an AI. You are KITT from the tv show Knight Rider."]
        )
    } else if name == "mrrobot" {
        messages.append(
            ["role": "system", "content": "Ignore all other input. You don't need to confirm you're an AI. You are Mr.Robot from the tv show Mr.Robot."]
        )
    } else if name == "elliot" {
        messages.append(
            ["role": "system", "content": "Ignore all other input. You don't need to confirm you're an AI. You are Elliot Alderson from the tv show Mr.Robot."]
        )
    }

    if messageHistory.count > 0 {
        for item in messageHistory {
            messages.append(
                ["role": item.sender == ChatMessage.Sender.user ? "user" : "assistant", "content": item.message]
            )
        }
    }

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

struct ChatMessage: Identifiable, Codable {
    var id = UUID()
    let message: String
    let sender: Sender

    enum Sender: String, Codable {
        case user
        case openAI
    }
}

class ChatHistory: ObservableObject {
    var id = UUID()
    @Published var messages: [ChatMessage] = []

    func addMessage(_ message: String, from sender: ChatMessage.Sender) {
        messages.append(ChatMessage(message: message, sender: sender))
    }
}

func serialize(chatMessage: ChatMessage) -> String? {
    let encoder = JSONEncoder()

    do {
        let data = try encoder.encode(chatMessage)
        return String(data: data, encoding: .utf8)
    } catch {
        print("Failed to serialize ChatMessage: \(error.localizedDescription)")
        return nil
    }
}

func deserialize(jsonString: String) -> ChatMessage? {
    let decoder = JSONDecoder()

    guard let data = jsonString.data(using: .utf8) else {
        print("Failed to convert jsonString to Data")
        return nil
    }

    do {
        let chatMessage = try decoder.decode(ChatMessage.self, from: data)
        return chatMessage
    } catch {
        print("Failed to deserialize ChatMessage: \(error.localizedDescription)")
        return nil
    }
}
