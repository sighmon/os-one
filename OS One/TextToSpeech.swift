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
    if name == "kitt" {
        voice = "JyckQxHjQnwHbX2r0LJw"  // KITT
    } else if name == "mrrobot" {
        voice = "eXLBstyxiNbZ4xNeaP6n"  // Mr.Robot
        body = [
            "text": text,
            "voice_settings": [
                "stability": 0.35,
                "similarity_boost": 0.75
            ]
        ] as [String: Any]
    } else if name == "elliot" {
        voice = "HsecoGZh5BmrNsPYD72I"  // Elliot from Mr.Robot
        body = [
            "text": text,
            "voice_settings": [
                "stability": 0.27,
                "similarity_boost": 0.85
            ]
        ] as [String: Any]
    } else if name == "glados" {
        voice = "uyIpLktH39lMvQZgxr0s"  // GLaDOS
        body = [
            "text": text,
            "voice_settings": [
                "stability": 0.09,
                "similarity_boost": 0.12
            ]
        ] as [String: Any]
    }
    let elevenLabsApi = "https://api.elevenlabs.io/v1/text-to-speech/\(voice)"

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
