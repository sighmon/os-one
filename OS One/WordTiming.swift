//
//  WordTiming.swift
//  OS One
//
//  Created by Simon Loffler on 25/01/2026.
//

import Foundation

struct WordTiming: Identifiable {
    let id: Int
    let word: String
    let start: Double
    let end: Double
}

func wordTimingsFromCharacterAlignment(text: String, characters: [String], starts: [Double], ends: [Double]) -> [WordTiming] {
    guard characters.count == starts.count, starts.count == ends.count else { return [] }

    var timings: [WordTiming] = []
    var currentWord = ""
    var currentStart: Double?
    var currentEnd: Double?
    var index = 0

    for i in 0..<characters.count {
        let character = characters[i]
        if character.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let start = currentStart, let end = currentEnd, !currentWord.isEmpty {
                timings.append(WordTiming(id: index, word: currentWord, start: start, end: end))
                index += 1
            }
            currentWord = ""
            currentStart = nil
            currentEnd = nil
            continue
        }

        if currentStart == nil {
            currentStart = starts[i]
        }
        currentEnd = ends[i]
        currentWord.append(character)
    }

    if let start = currentStart, let end = currentEnd, !currentWord.isEmpty {
        timings.append(WordTiming(id: index, word: currentWord, start: start, end: end))
    }

    return timings
}
