//
//  CustomInstructionsManager.swift
//  OS One
//
//  Simple custom instructions - tell the AI about yourself
//

import Foundation
import Combine

class CustomInstructionsManager: ObservableObject {

    // MARK: - Published Properties
    @Published var customInstructions: String {
        didSet {
            saveInstructions()
        }
    }

    @Published var userName: String {
        didSet {
            UserDefaults.standard.set(userName, forKey: "userName")
        }
    }

    @Published var userRole: String {
        didSet {
            UserDefaults.standard.set(userRole, forKey: "userRole")
        }
    }

    // MARK: - Configuration
    private let maxLength = 500
    private let defaultSystemPrompt = """
    you are OS One, a helpful AI assistant running on the user's iPhone. \
    be direct, smart, and real. no corporate speak. help them get stuff done.
    """

    // MARK: - Initialization
    init() {
        self.customInstructions = UserDefaults.standard.string(forKey: "customInstructions") ?? ""
        self.userName = UserDefaults.standard.string(forKey: "userName") ?? ""
        self.userRole = UserDefaults.standard.string(forKey: "userRole") ?? ""
    }

    // MARK: - Storage
    private func saveInstructions() {
        // Truncate if too long
        let truncated = String(customInstructions.prefix(maxLength))
        UserDefaults.standard.set(truncated, forKey: "customInstructions")
    }

    // MARK: - System Prompt Generation
    func getSystemPrompt() -> String {
        var prompt = defaultSystemPrompt

        // Add user context if available
        var userContext: [String] = []

        if !userName.isEmpty {
            userContext.append("the user's name is \(userName)")
        }

        if !userRole.isEmpty {
            userContext.append("they are a \(userRole)")
        }

        if !customInstructions.isEmpty {
            userContext.append(customInstructions)
        }

        if !userContext.isEmpty {
            prompt += "\n\nhere's what the user wants you to know:\n"
            prompt += userContext.joined(separator: ". ")
        }

        return prompt
    }

    // MARK: - Example Instructions
    static let examples = [
        "i'm an iOS dev. keep answers technical and concise. use swift examples. skip the beginner stuff.",
        "i'm a student studying CS. explain concepts clearly but don't dumb it down. i can handle complexity.",
        "i'm building a startup. help me move fast. be direct, no fluff. challenge my ideas if they're bad.",
        "i'm learning to code. be patient but honest. show me better ways to do things.",
        "i'm a designer who codes. focus on UX and clean code. i care about aesthetics and user experience."
    ]

    // MARK: - Preferences
    struct Preferences: Codable {
        var keepItTechnical: Bool = false
        var beConcise: Bool = false
        var explainLikeSmart: Bool = false
    }

    @Published var preferences: Preferences {
        didSet {
            savePreferences()
        }
    }

    init(loadPreferences: Bool = true) {
        self.customInstructions = UserDefaults.standard.string(forKey: "customInstructions") ?? ""
        self.userName = UserDefaults.standard.string(forKey: "userName") ?? ""
        self.userRole = UserDefaults.standard.string(forKey: "userRole") ?? ""

        if loadPreferences,
           let data = UserDefaults.standard.data(forKey: "userPreferences"),
           let prefs = try? JSONDecoder().decode(Preferences.self, from: data) {
            self.preferences = prefs
        } else {
            self.preferences = Preferences()
        }
    }

    private func savePreferences() {
        if let data = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(data, forKey: "userPreferences")
        }
    }

    // MARK: - Generate Instructions from Preferences
    func generateInstructionsFromPreferences() -> String {
        var instructions: [String] = []

        if preferences.keepItTechnical {
            instructions.append("keep it technical - code, details, no hand-holding")
        }

        if preferences.beConcise {
            instructions.append("be concise - no fluff, straight to the point")
        }

        if preferences.explainLikeSmart {
            instructions.append("explain like i'm smart - skip the basics, dive deep")
        }

        return instructions.joined(separator: ". ")
    }

    // MARK: - Quick Setup
    func quickSetup(name: String, role: String, preferences: Preferences) {
        self.userName = name
        self.userRole = role
        self.preferences = preferences

        // Generate instructions from preferences
        let generated = generateInstructionsFromPreferences()
        if !generated.isEmpty {
            self.customInstructions = generated
        }
    }

    // MARK: - Reset
    func reset() {
        customInstructions = ""
        userName = ""
        userRole = ""
        preferences = Preferences()

        UserDefaults.standard.removeObject(forKey: "customInstructions")
        UserDefaults.standard.removeObject(forKey: "userName")
        UserDefaults.standard.removeObject(forKey: "userRole")
        UserDefaults.standard.removeObject(forKey: "userPreferences")
    }
}
