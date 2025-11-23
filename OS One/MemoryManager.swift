//
//  MemoryManager.swift
//  OS One
//
//  Auto-remember stuff about you - stored locally, encrypted
//

import Foundation
import CoreData
import Combine

// MARK: - Memory Item
struct MemoryItem: Identifiable, Codable {
    let id: UUID
    let key: String          // "name", "location", "job", etc.
    let value: String        // "Alex", "Helsinki", "iOS Developer"
    let category: MemoryCategory
    let confidence: Double   // 0.0-1.0 (how sure we are)
    let createdAt: Date
    var lastUsed: Date

    enum MemoryCategory: String, Codable {
        case personal       // name, age, etc.
        case location       // city, country
        case work           // job, company, projects
        case preferences    // likes, dislikes
        case technical      // device, skills, tools
        case context        // current tasks, goals
    }
}

// MARK: - Memory Manager
class MemoryManager: ObservableObject {

    // MARK: - Published Properties
    @Published var memories: [MemoryItem] = []
    @Published var pendingMemories: [(fact: String, item: MemoryItem)] = []

    // MARK: - Core Data
    private let container: NSPersistentContainer

    // MARK: - Fact Extraction Patterns
    private let patterns: [(regex: NSRegularExpression, key: String, category: MemoryItem.MemoryCategory)] = {
        var patterns: [(NSRegularExpression, String, MemoryItem.MemoryCategory)] = []

        // Name patterns
        if let regex = try? NSRegularExpression(pattern: "(?:my name is|i'm|i am|call me) ([A-Z][a-z]+)", options: .caseInsensitive) {
            patterns.append((regex, "name", .personal))
        }

        // Location patterns
        if let regex = try? NSRegularExpression(pattern: "(?:i live in|i'm in|i'm from|based in) ([A-Z][a-z]+(?:,? [A-Z][a-z]+)?)", options: .caseInsensitive) {
            patterns.append((regex, "location", .location))
        }

        // Job patterns
        if let regex = try? NSRegularExpression(pattern: "(?:i'm a|i am a|i work as|my job is) ([a-zA-Z ]+?)(?:\\.|,|$)", options: .caseInsensitive) {
            patterns.append((regex, "job", .work))
        }

        // Device patterns
        if let regex = try? NSRegularExpression(pattern: "(?:i have|i'm using|my device is|i own) (?:an? )?(iPhone [0-9]+ (?:Pro )?(?:Max)?|iPad [A-Za-z0-9 ]+)", options: .caseInsensitive) {
            patterns.append((regex, "device", .technical))
        }

        // Working on patterns
        if let regex = try? NSRegularExpression(pattern: "(?:i'm working on|building|creating) ([a-zA-Z ]+?)(?:\\.|,|$)", options: .caseInsensitive) {
            patterns.append((regex, "current_project", .context))
        }

        return patterns
    }()

    // MARK: - Initialization
    init() {
        // Core Data setup
        container = NSPersistentContainer(name: "MemoryModel")
        container.loadPersistentStores { description, error in
            if let error = error {
                print("❌ Core Data failed to load: \(error)")
            }
        }

        loadMemories()
    }

    // MARK: - Load/Save
    private func loadMemories() {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Memory")

        do {
            let results = try container.viewContext.fetch(request)
            memories = results.compactMap { object -> MemoryItem? in
                guard let id = object.value(forKey: "id") as? UUID,
                      let key = object.value(forKey: "key") as? String,
                      let value = object.value(forKey: "value") as? String,
                      let categoryRaw = object.value(forKey: "category") as? String,
                      let category = MemoryItem.MemoryCategory(rawValue: categoryRaw),
                      let confidence = object.value(forKey: "confidence") as? Double,
                      let createdAt = object.value(forKey: "createdAt") as? Date,
                      let lastUsed = object.value(forKey: "lastUsed") as? Date else {
                    return nil
                }

                return MemoryItem(
                    id: id,
                    key: key,
                    value: value,
                    category: category,
                    confidence: confidence,
                    createdAt: createdAt,
                    lastUsed: lastUsed
                )
            }

            print("📚 Loaded \(memories.count) memories")
        } catch {
            print("❌ Failed to load memories: \(error)")
        }
    }

    private func saveMemory(_ item: MemoryItem) {
        let entity = NSEntityDescription.entity(forEntityName: "Memory", in: container.viewContext)!
        let memory = NSManagedObject(entity: entity, insertInto: container.viewContext)

        memory.setValue(item.id, forKey: "id")
        memory.setValue(item.key, forKey: "key")
        memory.setValue(item.value, forKey: "value")
        memory.setValue(item.category.rawValue, forKey: "category")
        memory.setValue(item.confidence, forKey: "confidence")
        memory.setValue(item.createdAt, forKey: "createdAt")
        memory.setValue(item.lastUsed, forKey: "lastUsed")

        do {
            try container.viewContext.save()
            loadMemories()
            print("💾 Saved memory: \(item.key) = \(item.value)")
        } catch {
            print("❌ Failed to save memory: \(error)")
        }
    }

    // MARK: - Extract Facts
    func extractFacts(from text: String) -> [(fact: String, item: MemoryItem)] {
        var extracted: [(String, MemoryItem)] = []

        for (regex, key, category) in patterns {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = regex.matches(in: text, range: range)

            for match in matches {
                if match.numberOfRanges >= 2 {
                    let valueRange = Range(match.range(at: 1), in: text)!
                    let value = String(text[valueRange]).trimmingCharacters(in: .whitespaces)

                    // Check if we already have this memory
                    if !memories.contains(where: { $0.key == key && $0.value == value }) {
                        let fact = "your \(key) is \(value)"
                        let item = MemoryItem(
                            id: UUID(),
                            key: key,
                            value: value,
                            category: category,
                            confidence: 0.8,
                            createdAt: Date(),
                            lastUsed: Date()
                        )

                        extracted.append((fact, item))
                    }
                }
            }
        }

        return extracted
    }

    // MARK: - Process Message (Auto-extract)
    func processMessage(_ text: String) {
        let facts = extractFacts(from: text)

        if !facts.isEmpty {
            pendingMemories.append(contentsOf: facts)
        }
    }

    // MARK: - Confirm Memory
    func confirmMemory(_ item: MemoryItem) {
        saveMemory(item)

        // Remove from pending
        pendingMemories.removeAll { $0.item.id == item.id }
    }

    func rejectMemory(_ item: MemoryItem) {
        pendingMemories.removeAll { $0.item.id == item.id }
    }

    func confirmAll() {
        for (_, item) in pendingMemories {
            saveMemory(item)
        }
        pendingMemories.removeAll()
    }

    func rejectAll() {
        pendingMemories.removeAll()
    }

    // MARK: - Get Context
    func getRelevantContext(for query: String) -> String {
        // Simple keyword matching for now
        let keywords = query.lowercased().split(separator: " ")

        let relevant = memories.filter { memory in
            let memoryText = "\(memory.key) \(memory.value)".lowercased()
            return keywords.contains { memoryText.contains($0) }
        }

        if relevant.isEmpty {
            return ""
        }

        var context = "[context: "
        let facts = relevant.map { "\(formatKey($0.key)): \($0.value)" }
        context += facts.joined(separator: ", ")
        context += "]"

        // Update last used
        for item in relevant {
            updateLastUsed(item.id)
        }

        return context
    }

    private func formatKey(_ key: String) -> String {
        key.replacingOccurrences(of: "_", with: " ")
    }

    private func updateLastUsed(_ id: UUID) {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Memory")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        do {
            let results = try container.viewContext.fetch(request)
            if let memory = results.first {
                memory.setValue(Date(), forKey: "lastUsed")
                try container.viewContext.save()
            }
        } catch {
            print("❌ Failed to update lastUsed: \(error)")
        }
    }

    // MARK: - Manual Add
    func addMemory(key: String, value: String, category: MemoryItem.MemoryCategory) {
        let item = MemoryItem(
            id: UUID(),
            key: key,
            value: value,
            category: category,
            confidence: 1.0,
            createdAt: Date(),
            lastUsed: Date()
        )

        saveMemory(item)
    }

    // MARK: - Delete
    func deleteMemory(_ item: MemoryItem) {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Memory")
        request.predicate = NSPredicate(format: "id == %@", item.id as CVarArg)

        do {
            let results = try container.viewContext.fetch(request)
            for object in results {
                container.viewContext.delete(object)
            }
            try container.viewContext.save()
            loadMemories()
            print("🗑️ Deleted memory: \(item.key)")
        } catch {
            print("❌ Failed to delete memory: \(error)")
        }
    }

    func clearAll() {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Memory")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)

        do {
            try container.viewContext.execute(deleteRequest)
            try container.viewContext.save()
            memories.removeAll()
            pendingMemories.removeAll()
            print("🗑️ Cleared all memories")
        } catch {
            print("❌ Failed to clear memories: \(error)")
        }
    }

    // MARK: - Export/Import
    func exportMemories() -> Data? {
        try? JSONEncoder().encode(memories)
    }

    func importMemories(from data: Data) {
        guard let imported = try? JSONDecoder().decode([MemoryItem].self, from: data) else {
            return
        }

        for item in imported {
            if !memories.contains(where: { $0.key == item.key && $0.value == item.value }) {
                saveMemory(item)
            }
        }

        print("📥 Imported \(imported.count) memories")
    }

    // MARK: - Statistics
    var memoryCount: Int {
        memories.count
    }

    func memoriesByCategory() -> [MemoryItem.MemoryCategory: Int] {
        var counts: [MemoryItem.MemoryCategory: Int] = [:]

        for memory in memories {
            counts[memory.category, default: 0] += 1
        }

        return counts
    }
}

// MARK: - Memory Model (Core Data would need to be set up in Xcode)
// For now, this is the schema - actual Core Data model needs to be created in Xcode

/*
 Entity: Memory
 Attributes:
 - id: UUID
 - key: String
 - value: String
 - category: String
 - confidence: Double
 - createdAt: Date
 - lastUsed: Date
 */
