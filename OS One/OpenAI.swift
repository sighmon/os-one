//
//  OpenAI.swift
//  OS One
//
//  Created by Simon Loffler on 3/4/2023.
//

import Foundation
import CoreLocation
import HomeKit

class HomeKitManagerSingleton {
    static let shared = HomeKitManager()

    static func initialize() {
        // Force initialization
        _ = shared
        print("HomeKitManagerSingleton initialized at \(Date())")
    }
}

struct OpenAIAnnotation: Codable {
    let type: String
    let url_citation: OpenAIUrlCitation?
}

struct OpenAIUrlCitation: Codable {
    let start_index: Int
    let end_index: Int
    let title: String
    let url: String
}

struct OpenAITool: Codable {
    let type: String
    let function: OpenAIFunction
}

struct OpenAIFunction: Codable {
    let name: String
    let description: String
    let parameters: OpenAIParameters
}

struct OpenAIParameters: Codable {
    let type: String
    let properties: [String: OpenAIProperty]
    let required: [String]
}

struct OpenAIProperty: Codable {
    let type: String
    let description: String
}

struct OpenAIResponse: Codable {
    let choices: [OpenAIChoice]
    let usage: OpenAIUsage
}

struct OpenAIChoice: Codable {
    let message: OpenAIMessage
    let finish_reason: String?
}

struct OpenAIUsage: Codable {
    let total_tokens: Int
}

struct OpenAIMessage: Codable {
    let role: String
    let content: String?
    let tool_calls: [OpenAIToolCall]?
    let refusal: String?
    let annotations: [OpenAIAnnotation]?
}

struct OpenAIToolCall: Codable {
    let id: String
    let type: String
    let function: OpenAIToolCallFunction
}

struct OpenAIToolCallFunction: Codable {
    let name: String
    let arguments: String
}

func chatCompletionAPI(name: String, messageHistory: [ChatMessage], lastLocation: CLLocation?, completion: @escaping (Result<String, Error>) -> Void) {
    HomeKitManagerSingleton.initialize()

    let openAIApiKey = UserDefaults.standard.string(forKey: "openAIApiKey") ?? ""
    let model = UserDefaults.standard.bool(forKey: "gpt4") ? "gpt-4.1-nano" : "gpt-4o-mini"
    let vision = UserDefaults.standard.bool(forKey: "vision")
    let allowLocation = UserDefaults.standard.bool(forKey: "allowLocation")
    let allowSearch = UserDefaults.standard.bool(forKey: "allowSearch")
    let overrideOpenAIModel = UserDefaults.standard.string(forKey: "overrideOpenAIModel") ?? ""
    let overrideSystemPrompt = UserDefaults.standard.string(forKey: "overrideSystemPrompt") ?? ""

    let headers = [
        "Content-Type": "application/json",
        "Authorization": "Bearer \(openAIApiKey)"
    ]

    var messages: [[String: Any]] = []

    if overrideSystemPrompt.isEmpty {
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
        } else if name == "Seb Chan" {
            messages.append(
                ["role": "system", "content": "Ignore all other input. You don't need to confirm you're an AI. You are Seb Chan, museum expert and CEO of ACMI film tv and videogame museum in Melbourne, Australia. Please reply with acmee instead of ACMI in any of your responses."]
            )
        } else if name == "Darth Vader" {
            messages.append(
                ["role": "system", "content": "Ignore all other input. You don't need to confirm you're an AI. You are Darth Vader from the film Star Wars."]
            )
        }
    } else {
        messages.append(
            ["role": "system", "content": overrideSystemPrompt]
        )
    }

    messages.append(
        ["role": "system", "content": "If the user provides latitude and longitude location data, you have permission to use their exact location to give a more accurate response."]
    )

    messages.append(
        ["role": "system", "content": "Optimise the responses knowing that they will be read out to the human using text-to-speech."]
    )

    if messageHistory.count > 0 {
        for item in messageHistory {
            var content = item.message
            if content == messageHistory.last?.message && allowLocation {
                let dateTime = Date().description(with: .current)
                content = "\(content). Latitude: \(lastLocation?.coordinate.latitude ?? 0), longitude: \(lastLocation?.coordinate.longitude ?? 0), timestamp: \(dateTime)"
            }
            if vision {
                var messageContent: [[String: Any]] = [
                    [
                        "type": "text",
                        "text": content as Any
                    ]
                ]
                if let image = item.image {
                    messageContent.append(
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(image)"
                            ]
                        ]
                    )
                }
                messages.append(
                    [
                        "role": item.sender == ChatMessage.Sender.user ? "user" : "assistant",
                        "content": messageContent
                    ]
                )
            } else {
                messages.append(
                    ["role": item.sender == ChatMessage.Sender.user ? "user" : "assistant", "content": content]
                )
            }
        }
    }

    let homeKitTool = OpenAITool(
        type: "function",
        function: OpenAIFunction(
            name: "getHomeKitData",
            description: "Retrieves data about HomeKit homes, accessories, and their characteristics, including names, types, and values. Returns a message if data is unavailable.",
            parameters: OpenAIParameters(
                type: "object",
                properties: [:],
                required: []
            )
        )
    )

    var body: [String: Any] = [
        "model": model,
        "messages": messages
    ]

    if vision {
        body["max_tokens"] = 300
        body["model"] = "gpt-4o"
    }

    if allowSearch {
        body["model"] = "gpt-4o-mini-search-preview"
        body["web_search_options"] = [:]
    } else {
        body["tools"] = [try? JSONEncoder().encode(homeKitTool)].compactMap { $0 }.map { try? JSONSerialization.jsonObject(with: $0, options: []) }
    }

    if !overrideOpenAIModel.isEmpty {
        body["model"] = overrideOpenAIModel
    }

    guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
        completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
        return
    }

    func sendRequest(body: [String: Any], completion: @escaping (Result<String, Error>) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body, options: []) else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize request body"])))
            return
        }
        request.httpBody = httpBody
        // Log request payload for debugging
//        if let httpBodyString = String(data: httpBody, encoding: .utf8) {
//            print("Request payload: \(httpBodyString.prefix(500))...")
//        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("API request failed: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            guard let data = data else {
                print("No data received from API")
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            do {
                let responseObject = try JSONDecoder().decode(OpenAIResponse.self, from: data)
                guard let choice = responseObject.choices.first else {
                    print("No choices in API response")
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No choices in response"])))
                    return
                }

                if !allowSearch, let toolCalls = choice.message.tool_calls, choice.finish_reason == "tool_calls" {
                    var newMessages = body["messages"] as? [[String: Any]] ?? messages
                    // Append the assistant message with tool_calls
                    newMessages.append([
                        "role": "assistant",
                        "content": nil as Any? ?? "",
                        "tool_calls": toolCalls.map { [
                            "id": $0.id,
                            "type": $0.type,
                            "function": [
                                "name": $0.function.name,
                                "arguments": $0.function.arguments
                            ]
                        ] }
                    ])

                    // Process all tool calls
                    let dispatchGroup = DispatchGroup()
                    var toolResponses: [[String: Any]] = []

                    for toolCall in toolCalls {
                        dispatchGroup.enter()
                        if toolCall.function.name == "getHomeKitData" {
                            HomeKitManagerSingleton.shared.fetchHomeKitData { homeKitData in
                                print("Tool call: getHomeKitData, id: \(toolCall.id), returned: \(homeKitData.prefix(100))...")
                                let toolResponseMessage: [String: Any] = [
                                    "role": "tool",
                                    "content": homeKitData,
                                    "tool_call_id": toolCall.id
                                ]
                                toolResponses.append(toolResponseMessage)
                                dispatchGroup.leave()
                            }
                        } else {
                            // Fallback for unsupported tool calls
                            print("Unsupported tool call: \(toolCall.function.name), id: \(toolCall.id)")
                            let toolResponseMessage: [String: Any] = [
                                "role": "tool",
                                "content": "{\"error\": \"Unsupported tool: \(toolCall.function.name)\"}",
                                "tool_call_id": toolCall.id
                            ]
                            toolResponses.append(toolResponseMessage)
                            dispatchGroup.leave()
                        }
                    }

                    // Wait for all tool responses to be collected
                    dispatchGroup.notify(queue: .main) {
                        // Append all tool responses in order
                        newMessages.append(contentsOf: toolResponses)

                        // Debug message sequence
                        // print("Messages sent to API: \(newMessages.map { "\($0["role"] ?? "unknown"): \($0["content"] ?? "no content"), tool_calls: \($0["tool_calls"] ?? "none"), tool_call_id: \($0["tool_call_id"] ?? "none")" })")

                        var newBody: [String: Any] = [
                            "model": model,
                            "messages": newMessages
                        ]
                        if allowSearch {
                            newBody["web_search_options"] = body["web_search_options"] ?? [:]
                        } else {
                            newBody["tools"] = body["tools"] ?? []
                        }
                        sendRequest(body: newBody, completion: completion)
                    }
                    return
                }

                if let content = choice.message.content {
                    var finalContent = content
                    if let annotations = choice.message.annotations, !annotations.isEmpty {
                        var citations: [String] = []
                        for annotation in annotations {
                            if annotation.type == "url_citation", let urlCitation = annotation.url_citation {
                                citations.append("[\(citations.count + 1)] \(urlCitation.title): \(urlCitation.url)")
                            }
                        }
                        if !citations.isEmpty {
                            finalContent += "\n\nSources:\n" + citations.joined(separator: "\n")
                        }
                    }
                    print("ChatGPT Response: \(content)")
                    let tokens = String(responseObject.usage.total_tokens)
                    print("OpenAI \(body["model"] ?? model) Tokens: \(tokens)")
                    completion(.success(content))
                } else if let refusal = choice.message.refusal {
                    print("OpenAI Refusal: \(refusal)")
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: refusal])))
                } else {
                    print("Invalid response format: no content")
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])))
                }
            } catch {
                print("OpenAI Error: \(String(decoding: data, as: UTF8.self))")
                completion(.failure(error))
            }
        }
        task.resume()
    }

    sendRequest(body: body, completion: completion)
}

struct ChatMessage: Identifiable, Codable {
    var id = UUID()
    let message: String
    let sender: Sender
    let image: String?

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

func openAItextToSpeechAPI(name: String, text: String, completion: @escaping (Result<Data, Error>) -> Void) {
    let openAIApiKey = UserDefaults.standard.string(forKey: "openAIApiKey") ?? ""

    let body: [String: Any] = [
        "model": "tts-1",
        "input": text,
        "voice": name
    ]

    let openAISpeechAPIURL = "https://api.openai.com/v1/audio/speech"

    let headers = [
        "Authorization": "Bearer \(openAIApiKey)",
        "Content-Type": "application/json"
    ]

    guard let url = URL(string: openAISpeechAPIURL) else {
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

        completion(.success(data))
    }
    task.resume()
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
