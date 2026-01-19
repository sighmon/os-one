//
//  OpenAI.swift
//  OS One
//
//  Created by Simon Loffler on 17/1/2026.
//

import Foundation

final class GatewayChatClient {
    static let shared = GatewayChatClient()

    private let queue = DispatchQueue(label: "os-one.gateway-chat")

    private init() {}

    func sendChatMessage(
        message: String,
        sessionKey: String,
        gatewayURL: String,
        token: String?,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        queue.async {
            guard let url = self.normalizeGatewayURL(gatewayURL) else {
                completion(.failure(NSError(domain: "Gateway", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid gateway URL"])) )
                return
            }

            let task = URLSession.shared.webSocketTask(with: url)
            task.resume()

            let connectId = UUID().uuidString
            let connectFrame = self.connectFrame(id: connectId, token: token)
            self.sendFrame(task: task, frame: connectFrame) { error in
                if let error = error {
                    completion(.failure(error))
                    task.cancel(with: .goingAway, reason: nil)
                    return
                }

                self.receiveLoop(task: task, connectId: connectId) { result in
                    switch result {
                    case .success:
                        let runId = UUID().uuidString
                        let sendFrame = self.chatSendFrame(id: runId, sessionKey: sessionKey, message: message)
                        self.sendFrame(task: task, frame: sendFrame) { sendError in
                            if let sendError = sendError {
                                completion(.failure(sendError))
                                task.cancel(with: .goingAway, reason: nil)
                                return
                            }

                            self.receiveChatEvents(task: task, expectedRunId: runId, completion: completion)
                        }
                    case .failure(let error):
                        completion(.failure(error))
                        task.cancel(with: .goingAway, reason: nil)
                    }
                }
            }
        }
    }

    private func normalizeGatewayURL(_ urlString: String) -> URL? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if trimmed.hasPrefix("ws://") || trimmed.hasPrefix("wss://") {
            return URL(string: trimmed)
        }
        if trimmed.hasPrefix("http://") {
            return URL(string: "ws://" + trimmed.dropFirst("http://".count))
        }
        if trimmed.hasPrefix("https://") {
            return URL(string: "wss://" + trimmed.dropFirst("https://".count))
        }
        return URL(string: "ws://" + trimmed)
    }

    private func connectFrame(id: String, token: String?) -> [String: Any] {
        var params: [String: Any] = [
            "minProtocol": 3,
            "maxProtocol": 3,
            "client": [
                "id": "webchat",
                "displayName": "OS One",
                "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0",
                "platform": "iOS",
                "mode": "ui",
                "instanceId": UUID().uuidString
            ]
        ]

        if let token, !token.isEmpty {
            params["auth"] = ["token": token]
        }

        return [
            "type": "req",
            "id": id,
            "method": "connect",
            "params": params
        ]
    }

    private func chatSendFrame(id: String, sessionKey: String, message: String) -> [String: Any] {
        return [
            "type": "req",
            "id": id,
            "method": "chat.send",
            "params": [
                "sessionKey": sessionKey,
                "message": message,
                "deliver": false,
                "idempotencyKey": id
            ]
        ]
    }

    private func sendFrame(task: URLSessionWebSocketTask, frame: [String: Any], completion: @escaping (Error?) -> Void) {
        do {
            let data = try JSONSerialization.data(withJSONObject: frame)
            task.send(.data(data), completionHandler: completion)
        } catch {
            completion(error)
        }
    }

    private func receiveLoop(
        task: URLSessionWebSocketTask,
        connectId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        task.receive { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let message):
                guard let payload = self.messageToJSON(message) else {
                    self.receiveLoop(task: task, connectId: connectId, completion: completion)
                    return
                }

                if let type = payload["type"] as? String, type == "res", let id = payload["id"] as? String, id == connectId {
                    let ok = payload["ok"] as? Bool ?? false
                    if ok {
                        completion(.success(()))
                    } else {
                        completion(.failure(NSError(domain: "Gateway", code: -1, userInfo: [NSLocalizedDescriptionKey: "Gateway connect failed"])) )
                    }
                    return
                }

                self.receiveLoop(task: task, connectId: connectId, completion: completion)
            }
        }
    }

    private func receiveChatEvents(
        task: URLSessionWebSocketTask,
        expectedRunId: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        var latestText: String?
        var activeRunId: String?

        func loop() {
            task.receive { result in
                switch result {
                case .failure(let error):
                    completion(.failure(error))
                    task.cancel(with: .goingAway, reason: nil)
                case .success(let message):
                    guard let payload = self.messageToJSON(message) else {
                        loop()
                        return
                    }

                    if let type = payload["type"] as? String, type == "event", let event = payload["event"] as? String, event == "chat" {
                        let chatPayload = payload["payload"] as? [String: Any]
                        let state = chatPayload?["state"] as? String
                        let runId = chatPayload?["runId"] as? String
                        if activeRunId == nil {
                            activeRunId = runId
                        }
                        if let activeRunId, let runId, activeRunId != runId {
                            loop()
                            return
                        }

                        if let messageValue = chatPayload?["message"] {
                            if let text = self.extractText(messageValue) {
                                latestText = text
                            }
                        }

                        if state == "final" {
                            completion(.success(latestText ?? ""))
                            task.cancel(with: .goingAway, reason: nil)
                            return
                        }
                        if state == "error" {
                            let errorMessage = chatPayload?["errorMessage"] as? String ?? "Gateway chat error"
                            completion(.failure(NSError(domain: "Gateway", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                            task.cancel(with: .goingAway, reason: nil)
                            return
                        }
                    }

                    loop()
                }
            }
        }

        loop()
    }

    private func messageToJSON(_ message: URLSessionWebSocketTask.Message) -> [String: Any]? {
        switch message {
        case .data(let data):
            return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        case .string(let text):
            guard let data = text.data(using: .utf8) else { return nil }
            return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        @unknown default:
            return nil
        }
    }

    private func extractText(_ message: Any) -> String? {
        if let messageDict = message as? [String: Any] {
            if let content = messageDict["content"] as? String {
                return content
            }
            if let contentArray = messageDict["content"] as? [[String: Any]] {
                let parts = contentArray.compactMap { item -> String? in
                    if let type = item["type"] as? String, type == "text", let text = item["text"] as? String {
                        return text
                    }
                    return nil
                }
                if !parts.isEmpty {
                    return parts.joined(separator: "\n")
                }
            }
            if let text = messageDict["text"] as? String {
                return text
            }
        }
        return nil
    }
}
