import Foundation

struct MemoryFact: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var text: String
    var createdAt: Date = .now
}

/// Long-term memory: small facts about the user that get injected into every
/// system prompt. The AI writes to it via the `remember` tool; the user can
/// review and delete facts in Settings.
final class MemoryStore: ObservableObject {
    static let shared = MemoryStore()

    @Published private(set) var facts: [MemoryFact] = []

    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.supersiri.memorystore")

    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("memory.json")
        load()
    }

    /// System-prompt section describing what SuperSiri knows about the user.
    var promptSection: String {
        guard !facts.isEmpty else { return "" }
        let lines = facts.map { "- \($0.text)" }.joined(separator: "\n")
        return """
        Things you remember about this user from previous conversations \
        (use them to personalize answers; don't recite them unprompted):
        \(lines)
        """
    }

    func add(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // Avoid exact duplicates.
        guard !facts.contains(where: { $0.text.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return }
        DispatchQueue.main.async {
            self.facts.append(MemoryFact(text: trimmed))
            self.persist()
        }
    }

    func delete(_ fact: MemoryFact) {
        DispatchQueue.main.async {
            self.facts.removeAll { $0.id == fact.id }
            self.persist()
        }
    }

    func deleteAll() {
        DispatchQueue.main.async {
            self.facts.removeAll()
            self.persist()
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([MemoryFact].self, from: data)
        else { return }
        facts = decoded
    }

    private func persist() {
        let snapshot = facts
        let url = fileURL
        queue.async {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }
}
