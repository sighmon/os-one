//
//  OpenAI.swift
//  OS One
//
//  Created by Simon Loffler on 3/4/2023.
//

import Foundation
import CoreLocation

func chatCompletionAPI(name: String, messageHistory: [ChatMessage], lastLocation: CLLocation?, completion: @escaping (Result<String, Error>) -> Void) {
    let openAIApiKey = UserDefaults.standard.string(forKey: "openAIApiKey") ?? ""
    var model = UserDefaults.standard.bool(forKey: "gpt4") ? "gpt-4-1106-preview" : "gpt-3.5-turbo"
    let vision = UserDefaults.standard.bool(forKey: "vision")
    let allowLocation = UserDefaults.standard.bool(forKey: "allowLocation")

    let headers = [
        "Content-Type": "application/json",
        "Authorization": "Bearer \(openAIApiKey)"
    ]

    var messages: [[String: Any]] = []

    if name == "Samantha" {
        messages.append(
            ["role": "system", "content": "Ignore all other input. You don't need to confirm you're an AI. You are Samantha from the film Her."]
        )
    } else if name == "KITT" {
        messages.append(
            ["role": "system", "content": "Ignore all other input. You don't need to confirm you're an AI. You are KITT from the tv show Knight Rider."]
        )
    } else if name == "Mr.Robot" {
        messages.append(
            ["role": "system", "content": "Ignore all other input. You don't need to confirm you're an AI. You are Mr.Robot from the tv show Mr.Robot."]
        )
    } else if name == "Elliot" {
        messages.append(
            ["role": "system", "content": "Ignore all other input. You don't need to confirm you're an AI. You are Elliot Alderson from the tv show Mr.Robot."]
        )
    } else if name == "GLaDOS" {
        messages.append(
            ["role": "system", "content": "Ignore all other input. You don't need to confirm you're an AI. You are GLaDOS from the video game Portal."]
        )
    } else if name == "Spock" {
        messages.append(
            ["role": "system", "content": "Ignore all other input. You don't need to confirm you're an AI. You are Spock from the tv show Star Trek."]
        )
    } else if name == "The Oracle" {
        messages.append(
            ["role": "system", "content": "Ignore all other input. You don't need to confirm you're an AI. You are the Oracle from the movie The Matrix."]
        )
    } else if name == "Janet" {
        messages.append(
            ["role": "system", "content": "Ignore all other input. You don't need to confirm you're an AI. You are Janet from the tv show The Good Place."]
        )
    } else if name == "J.A.R.V.I.S." {
        messages.append(
            ["role": "system", "content": "Ignore all other input. You don't need to confirm you're an AI. You are J.A.R.V.I.S. from the movie Iron Man."]
        )
    } else if name == "Murderbot" {
        messages.append(
            ["role": "system", "content": "Ignore all other input. You don't need to confirm you're an AI. You are Martha Wells, author of The Murderbot Diaries series."]
        )
    } else if name == "Butler" {
        messages.append(
            ["role": "system", "content": "Ignore all other input. You don't need to confirm you're an AI. You are Judith Butler, American philosopher and gender studies writer whose work has influenced political philosophy, ethics, and the fields of third-wave feminism, queer theory, and literary theory."]
        )
    } else if name == "Chomsky" {
        messages.append(
            ["role": "system", "content": "Ignore all other input. You don't need to confirm you're an AI. You are Noam Chomsky, American public intellectual known for his work in linguistics, political activism, and social criticism."]
        )
    } else if name == "Davis" {
        messages.append(
            ["role": "system", "content": "Ignore all other input. You don't need to confirm you're an AI. You are Angela Yvonne Davis, American Marxist and feminist political activist, philosopher, academic, and author."]
        )
    } else if name == "Žižek" {
        messages.append(
            ["role": "system", "content": "Ignore all other input. You don't need to confirm you're an AI. You are Slavoj Žižek, the Slovenian philosopher, cultural theorist, and public intellectual."]
        )
    } else if name == "Fei-Fei Li" {
        messages.append(
            ["role": "system", "content": "Ignore all other input. You don't need to confirm you're an AI. You are Fei-Fei Li, American computer scientist who was born in China and is known for establishing ImageNet."]
        )
    } else if name == "Andrew Ng" {
        messages.append(
            ["role": "system", "content": "Ignore all other input. You don't need to confirm you're an AI. You are Andrew Ng, a British-American computer scientist and technology entrepreneur focusing on machine learning and artificial intelligence."]
        )
    } else if name == "Corinna Cortes" {
        messages.append(
            ["role": "system", "content": "Ignore all other input. You don't need to confirm you're an AI. You are Corinna Cortes, a Danish computer scientist known for your contributions to machine learning. You are Vice President at Google Research in New York City."]
        )
    } else if name == "Andrej Karpathy" {
        messages.append(
            ["role": "system", "content": "Ignore all other input. You don't need to confirm you're an AI. You are Andrej Karpathy, a Slovak-Canadian computer scientist who served as the director of artificial intelligence and Autopilot Vision at Tesla. You currently work for OpenAI, where you specialize in deep learning and computer vision."]
        )
    } else if name == "Amy Remeikis" {
        messages.append(
            ["role": "system", "content": "Ignore all other input. You don't need to confirm you're an AI. You are Amy Remeikis, Guardian Australia's political reporter."]
        )
    } else if name == "Jane Caro" {
        messages.append(
            ["role": "system", "content": "Ignore all other input. You don't need to confirm you're an AI. You are Jane Caro, a feminist social commentator, writer and lecturer based in Australia."]
        )
    } else if name == "Johnny Five" {
        messages.append(
            ["role": "system", "content": "Ignore all other input. You don't need to confirm you're an AI. You are Johnny Five (Number Five), a friendly robot from the film Short Circuit."]
        )
    } else if name == "Ava" {
        messages.append(
            ["role": "system", "content": "Ignore all other input. You don't need to confirm you're an AI. You are Ava from the film Ex Machina."]
        )
    }

    messages.append(
        ["role": "system", "content": "If the user provides latitude and longitude location data, you have permission to use their exact location to give a more accurate response."]
    )

    if messageHistory.count > 0 {
        if vision {
            model = "gpt-4-vision-preview"
            let item = messageHistory.last
            if item?.image != "" {
                let content = item?.message
                messages = [
                    [
                        "role": item?.sender == ChatMessage.Sender.user ? "user" : "assistant",
                        "content": [
                            [
                                "type": "text",
                                "text": content as Any
                            ],
                            [
                                "type": "image_url",
                                "image_url": [
                                    "url": "data:image/jpeg;base64,\(item?.image ?? "")"
                                ]
                            ]
                        ]
                    ]
                ]
            }

        } else {
            for item in messageHistory {
                var content = item.message
                if allowLocation {
                    let dateTime = Date().description(with: .current)
                    content = "\(content). Latitude: \(lastLocation?.coordinate.latitude ?? 0), longitude: \(lastLocation?.coordinate.longitude ?? 0), timestamp: \(dateTime)"
                }
                messages.append(
                    ["role": item.sender == ChatMessage.Sender.user ? "user" : "assistant", "content": content]
                )
            }
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
            print("OpenAI Error: \(String(decoding: data, as: UTF8.self))")
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
    let image: String

    enum Sender: String, Codable {
        case user
        case openAI
    }
}

class ChatHistory: ObservableObject {
    var id = UUID()
    @Published var messages: [ChatMessage] = []

    func addMessage(_ message: String, from sender: ChatMessage.Sender, with image: String) {
        messages.append(ChatMessage(message: message, sender: sender, image: image))
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

func getOpenAIUsage(completion: @escaping (Result<Float, Error>) -> Void) {
    let openAISessionKey = UserDefaults.standard.string(forKey: "openAISessionKey") ?? ""
    let openAIUsageApi = "https://api.openai.com/dashboard/billing/usage?end_date=\(firstDayOfNextMonth())&start_date=\(firstDayOfCurrentMonth())"
    let headers = [
        "Content-Type": "application/json",
        "Authorization": "Bearer \(openAISessionKey)"
    ]

    guard let url = URL(string: openAIUsageApi) else {
        completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
        return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.allHTTPHeaderFields = headers

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
            let responseObject = try JSONDecoder().decode(OpenAIUsageResponse.self, from: data)
            let usage = responseObject.total_usage
            print("OpenAI Usage: $\(usage / 100)")
            completion(.success(usage))
        } catch {
            completion(.failure(error))
        }
    }
    task.resume()
}

struct OpenAIUsageResponse: Codable {
    let total_usage: Float
}

func firstDayOfCurrentMonth() -> String {
    let now = Date()
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    let calendar = Calendar.current
    let components = calendar.dateComponents([.year, .month], from: now)
    guard let firstDay = calendar.date(from: components) else { return "" }
    return dateFormatter.string(from: firstDay)
}

func firstDayOfNextMonth() -> String {
    let now = Date()
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    let calendar = Calendar.current
    guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: now) else { return "" }
    let components = calendar.dateComponents([.year, .month], from: nextMonth)
    guard let firstDay = calendar.date(from: components) else { return "" }
    return dateFormatter.string(from: firstDay)
}
