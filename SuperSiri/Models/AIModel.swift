import Foundation

/// The AI provider backing a model.
enum AIProvider: String, Codable, CaseIterable, Identifiable {
    case anthropic
    case openai

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .anthropic: return "Anthropic (Claude)"
        case .openai: return "OpenAI (GPT)"
        }
    }
}

/// A selectable AI model. IDs are the exact strings each API expects.
struct AIModel: Identifiable, Codable, Hashable {
    let id: String
    let displayName: String
    let provider: AIProvider
    let tagline: String
    /// Rough capability rank used by the smart router (higher = smarter).
    let capability: Int
    /// Rough speed rank used by the smart router (higher = faster).
    let speed: Int

    static let claudeOpus = AIModel(
        id: "claude-opus-4-8",
        displayName: "Claude Opus 4.8",
        provider: .anthropic,
        tagline: "Best for complex reasoning, coding, and long tasks",
        capability: 9,
        speed: 5
    )

    static let claudeSonnet = AIModel(
        id: "claude-sonnet-5",
        displayName: "Claude Sonnet 5",
        provider: .anthropic,
        tagline: "Great balance of intelligence and speed",
        capability: 8,
        speed: 7
    )

    static let claudeHaiku = AIModel(
        id: "claude-haiku-4-5",
        displayName: "Claude Haiku 4.5",
        provider: .anthropic,
        tagline: "Fastest Claude — quick answers and classification",
        capability: 6,
        speed: 9
    )

    static let gpt51 = AIModel(
        id: "gpt-5.1",
        displayName: "GPT-5.1",
        provider: .openai,
        tagline: "OpenAI's flagship model",
        capability: 9,
        speed: 5
    )

    static let gpt51Mini = AIModel(
        id: "gpt-5.1-mini",
        displayName: "GPT-5.1 mini",
        provider: .openai,
        tagline: "Fast and inexpensive OpenAI model",
        capability: 6,
        speed: 9
    )

    /// Every model the app ships with.
    static let all: [AIModel] = [.claudeOpus, .claudeSonnet, .claudeHaiku, .gpt51, .gpt51Mini]

    /// The default model for new conversations.
    static let `default`: AIModel = .claudeOpus

    static func model(withID id: String) -> AIModel? {
        all.first { $0.id == id }
    }
}
