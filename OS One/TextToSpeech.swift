//
//  TextToSpeech.swift
//  OS One
//
//  Created by Simon Loffler on 3/4/2023.
//

import Foundation
import AVFoundation

func elevenLabsTextToSpeech(name: String, text: String, completion: @escaping (Result<Data, Error>) -> Void) {
    let elevenLabsApiKey = UserDefaults.standard.string(forKey: "elevenLabsApiKey") ?? ""

    var body = [
        "text": text,
        "voice_settings": [
            "stability": 0.75,
            "similarity_boost": 0.75
        ]
    ] as [String: Any]

    var voice = "EXAVITQu4vr4xnSDxMaL"  // Bella (Sounds like Samantha from Her)
    if name == "KITT" {
        voice = "JyckQxHjQnwHbX2r0LJw"  // KITT from Knight Rider
    } else if name == "Mr.Robot" {
        voice = "eXLBstyxiNbZ4xNeaP6n"  // Mr.Robot from Mr.Robot
        body = [
            "text": text,
            "voice_settings": [
                "stability": 0.35,
                "similarity_boost": 0.75
            ]
        ] as [String: Any]
    } else if name == "Elliot" {
        voice = "HsecoGZh5BmrNsPYD72I"  // Elliot from Mr.Robot
        body = [
            "text": text,
            "voice_settings": [
                "stability": 0.27,
                "similarity_boost": 0.85
            ]
        ] as [String: Any]
    } else if name == "GLaDOS" {
        voice = "uyIpLktH39lMvQZgxr0s"  // GLaDOS from Portal
        body = [
            "text": text,
            "voice_settings": [
                "stability": 0.09,
                "similarity_boost": 0.12
            ]
        ] as [String: Any]
    } else if name == "Spock" {
        voice = "D2BIZ9JrDxLJfJy2bvS7"  // Spock from Star Trek
        body = [
            "text": text,
            "voice_settings": [
                "stability": 0.75,
                "similarity_boost": 0.75
            ]
        ] as [String: Any]
    } else if name == "The Oracle" {
        voice = "VKQUIjLDfJWnQZJBvTnz"  // The Oracle from The Matrix
        body = [
            "text": text,
            "voice_settings": [
                "stability": 0.20,
                "similarity_boost": 0.60
            ]
        ] as [String: Any]
    }
    let elevenLabsApi = "https://api.elevenlabs.io/v1/text-to-speech/\(voice)/stream"

    let headers = [
        "accept": "audio/mpeg",
        "xi-api-key": elevenLabsApiKey,
        "Content-Type": "application/json"
    ]

    guard let url = URL(string: elevenLabsApi) else {
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

func elevenLabsGetUsage(completion: @escaping (Result<Float, Error>) -> Void) {
    let elevenLabsApiKey = UserDefaults.standard.string(forKey: "elevenLabsApiKey") ?? ""
    let elevenLabsApi = "https://api.elevenlabs.io/v1/user/subscription"
    let headers = [
        "accept": "application/json",
        "xi-api-key": elevenLabsApiKey
    ]

    guard let url = URL(string: elevenLabsApi) else {
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
            let responseObject = try JSONDecoder().decode(ElevenLabsUsageResponse.self, from: data)
            let usage = Float(responseObject.character_count) / Float(responseObject.character_limit)
            print("ElevenLabs Usage: \(usage)")
            completion(.success(usage))
        } catch {
            completion(.failure(error))
        }
    }
    task.resume()
}

struct ElevenLabsUsageResponse: Codable {
    let character_count: Int
    let character_limit: Int
}

func elevenLabsGetAudioId(text: String, completion: @escaping (Result<String, Error>) -> Void) {
    let elevenLabsApiKey = UserDefaults.standard.string(forKey: "elevenLabsApiKey") ?? ""
    let elevenLabsApi = "https://api.elevenlabs.io/v1/history?page_size=666"
    let headers = [
        "accept": "application/json",
        "xi-api-key": elevenLabsApiKey
    ]

    guard let url = URL(string: elevenLabsApi) else {
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
            var matchedItemId = ""
            let responseObject = try JSONDecoder().decode(ElevenLabsHistoryResponse.self, from: data)
            for item in responseObject.history {
                if item.text == text {
                    matchedItemId = item.history_item_id
                }
            }
            completion(.success(matchedItemId))
        } catch {
            completion(.failure(error))
        }
    }
    task.resume()
}

struct ElevenLabsHistoryResponse: Codable {
    let history: Array<ElevenLabsHistoryItem>
}

struct ElevenLabsHistoryItem: Codable {
    let history_item_id: String
    let text: String
}

func elevenLabsGetHistoricAudio(audioId: String, completion: @escaping (Result<Data, Error>) -> Void) {
    let elevenLabsApiKey = UserDefaults.standard.string(forKey: "elevenLabsApiKey") ?? ""
    let elevenLabsApi = "https://api.elevenlabs.io/v1/history/\(audioId)/audio"

    let headers = [
        "accept": "audio/mpeg",
        "xi-api-key": elevenLabsApiKey,
        "Content-Type": "application/json"
    ]

    guard let url = URL(string: elevenLabsApi) else {
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

        completion(.success(data))
    }
    task.resume()
}
