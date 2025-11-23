//
//  ClaudeImporter.swift
//  OS One
//
//  Import your Claude chat history - bring your context with you
//

import Foundation
import UniformTypeIdentifiers

// MARK: - Claude Data Models
struct ClaudeExport: Codable {
    let conversations: [ClaudeConversation]?
    let version: String?
}

struct ClaudeConversation: Codable, Identifiable {
    let uuid: String
    let name: String
    let created_at: String
    let updated_at: String
    let chat_messages: [ClaudeMessage]?

    var id: String { uuid }
}

struct ClaudeMessage: Codable {
    let uuid: String
    let text: String
    let sender: String  // "human" or "assistant"
    let created_at: String
}

// MARK: - Import Result
struct ImportResult {
    let conversationCount: Int
    let messageCount: Int
    let extractedFacts: [String]
    let suggestedInstructions: String?
}

// MARK: - Claude Importer
class ClaudeImporter: ObservableObject {

    // MARK: - Published Properties
    @Published var isImporting: Bool = false
    @Published var importProgress: Double = 0.0
    @Published var lastImportResult: ImportResult?
    @Published var importError: String?

    // MARK: - Dependencies
    private let memoryManager: MemoryManager
    private let customInstructionsManager: CustomInstructionsManager

    // MARK: - Initialization
    init(
        memoryManager: MemoryManager,
        customInstructionsManager: CustomInstructionsManager
    ) {
        self.memoryManager = memoryManager
        self.customInstructionsManager = customInstructionsManager
    }

    // MARK: - Import from File
    func importFromFile(_ url: URL) async -> ImportResult? {
        await MainActor.run {
            isImporting = true
            importProgress = 0.0
            importError = nil
        }

        defer {
            Task { @MainActor in
                isImporting = false
                importProgress = 1.0
            }
        }

        do {
            // Read file
            let data: Data

            if url.pathExtension == "zip" {
                // Extract ZIP
                data = try await extractFromZIP(url)
            } else {
                // Read JSON directly
                data = try Data(contentsOf: url)
            }

            await MainActor.run {
                importProgress = 0.2
            }

            // Parse JSON
            let decoder = JSONDecoder()

            // Try parsing as full export
            if let export = try? decoder.decode(ClaudeExport.self, from: data),
               let conversations = export.conversations {
                return await processConversations(conversations)
            }

            // Try parsing as array of conversations
            if let conversations = try? decoder.decode([ClaudeConversation].self, from: data) {
                return await processConversations(conversations)
            }

            // Try parsing as single conversation
            if let conversation = try? decoder.decode(ClaudeConversation.self, from: data) {
                return await processConversations([conversation])
            }

            await MainActor.run {
                importError = "couldn't parse file - make sure it's a claude export"
            }
            return nil

        } catch {
            await MainActor.run {
                importError = "import failed: \(error.localizedDescription)"
            }
            print("❌ Import error: \(error)")
            return nil
        }
    }

    // MARK: - Extract from ZIP
    private func extractFromZIP(_ url: URL) async throws -> Data {
        // For iOS, we'd use ZipFoundation or similar
        // For now, assume user extracts manually
        throw ImportError.zipNotSupported
    }

    // MARK: - Process Conversations
    private func processConversations(_ conversations: [ClaudeConversation]) async -> ImportResult {
        var totalMessages = 0
        var extractedFacts: Set<String> = []
        var userMessages: [String] = []

        await MainActor.run {
            importProgress = 0.3
        }

        // Process each conversation
        for (index, conversation) in conversations.enumerated() {
            guard let messages = conversation.chat_messages else { continue }

            for message in messages {
                totalMessages += 1

                if message.sender == "human" {
                    userMessages.append(message.text)

                    // Extract facts from user messages
                    let facts = memoryManager.extractFacts(from: message.text)
                    for (fact, _) in facts {
                        extractedFacts.insert(fact)
                    }
                }
            }

            // Update progress
            let progress = 0.3 + (Double(index + 1) / Double(conversations.count)) * 0.5
            await MainActor.run {
                importProgress = progress
            }
        }

        await MainActor.run {
            importProgress = 0.8
        }

        // Analyze user's conversation style
        let suggestedInstructions = analyzeConversationStyle(userMessages)

        await MainActor.run {
            importProgress = 1.0
        }

        return ImportResult(
            conversationCount: conversations.count,
            messageCount: totalMessages,
            extractedFacts: Array(extractedFacts),
            suggestedInstructions: suggestedInstructions
        )
    }

    // MARK: - Analyze Conversation Style
    private func analyzeConversationStyle(_ messages: [String]) -> String? {
        guard !messages.isEmpty else { return nil }

        var characteristics: [String] = []

        // Analyze message length
        let avgLength = messages.map { $0.count }.reduce(0, +) / messages.count

        if avgLength < 50 {
            characteristics.append("keep responses concise")
        } else if avgLength > 200 {
            characteristics.append("detailed explanations are fine")
        }

        // Check for technical content
        let technicalKeywords = ["code", "function", "class", "API", "database", "server", "swift", "python", "javascript"]
        let technicalCount = messages.filter { message in
            technicalKeywords.contains { message.lowercased().contains($0) }
        }.count

        if Double(technicalCount) / Double(messages.count) > 0.3 {
            characteristics.append("keep it technical - code examples welcome")
        }

        // Check for direct/casual style
        let casualIndicators = ["lol", "tbh", "btw", "yeah", "nah", "cool", "awesome"]
        let casualCount = messages.filter { message in
            casualIndicators.contains { message.lowercased().contains($0) }
        }.count

        if Double(casualCount) / Double(messages.count) > 0.2 {
            characteristics.append("casual tone is fine, skip formalities")
        }

        if characteristics.isEmpty {
            return nil
        }

        return characteristics.joined(separator: ". ")
    }

    // MARK: - Apply Import Results
    func applyImportResults(_ result: ImportResult, confirmFacts: Bool, applySuggestedInstructions: Bool) {
        // Apply facts to memory
        if confirmFacts {
            for fact in result.extractedFacts {
                // Parse fact and create memory
                // Format: "your [key] is [value]"
                let components = fact.components(separatedBy: " is ")
                if components.count == 2 {
                    let key = components[0].replacingOccurrences(of: "your ", with: "")
                    let value = components[1]

                    memoryManager.addMemory(
                        key: key,
                        value: value,
                        category: categorizeKey(key)
                    )
                }
            }

            print("📥 Imported \(result.extractedFacts.count) facts")
        }

        // Apply suggested instructions
        if applySuggestedInstructions, let instructions = result.suggestedInstructions {
            let current = customInstructionsManager.customInstructions

            if current.isEmpty {
                customInstructionsManager.customInstructions = instructions
            } else {
                customInstructionsManager.customInstructions = current + ". " + instructions
            }

            print("📝 Applied suggested instructions")
        }
    }

    private func categorizeKey(_ key: String) -> MemoryItem.MemoryCategory {
        switch key.lowercased() {
        case "name", "age":
            return .personal
        case "location", "city", "country":
            return .location
        case "job", "role", "company":
            return .work
        case "device", "phone":
            return .technical
        default:
            return .context
        }
    }

    // MARK: - Preview Import
    func previewImport(_ url: URL) async -> ImportResult? {
        // Same as importFromFile but doesn't apply changes
        return await importFromFile(url)
    }
}

// MARK: - Errors
enum ImportError: LocalizedError {
    case zipNotSupported
    case invalidFormat
    case noConversations

    var errorDescription: String? {
        switch self {
        case .zipNotSupported:
            return "ZIP extraction not supported yet - extract manually and import JSON"
        case .invalidFormat:
            return "File format not recognized"
        case .noConversations:
            return "No conversations found in export"
        }
    }
}

// MARK: - Import Summary View Helper
extension ImportResult {
    var summary: String {
        """
        found \(conversationCount) conversations 📚

        extracted \(extractedFacts.count) facts about you
        \(suggestedInstructions != nil ? "\nsuggested instructions based on your style" : "")
        """
    }

    var factsList: String {
        extractedFacts.joined(separator: "\n• ")
    }
}
