import Foundation

/// A single turn passed to an AI provider.
struct AITurn {
    let role: MessageRole
    let text: String
}

/// Incremental events emitted while a model streams its answer.
enum AIStreamEvent {
    /// A chunk of the model's visible answer.
    case text(String)
    /// A chunk of summarized reasoning (Claude adaptive thinking).
    case thinking(String)
    /// The stream finished successfully.
    case done
}

enum AIServiceError: LocalizedError {
    case missingAPIKey(AIProvider)
    case httpError(status: Int, body: String)
    case invalidResponse
    case refused(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            return "No API key set for \(provider.displayName). Add one in Settings."
        case .httpError(let status, let body):
            return "The AI service returned an error (HTTP \(status)). \(body)"
        case .invalidResponse:
            return "The AI service returned an unexpected response."
        case .refused(let reason):
            return "The model declined this request. \(reason)"
        }
    }
}

/// Common interface for all AI providers.
protocol AIService {
    /// Streams a completion for the given conversation history.
    func streamCompletion(
        model: AIModel,
        system: String?,
        turns: [AITurn]
    ) -> AsyncThrowingStream<AIStreamEvent, Error>
}

extension AIService {
    /// Convenience: runs a completion to completion and returns the full text.
    /// Used by App Intents and the workflow engine where streaming UI isn't needed.
    func complete(model: AIModel, system: String? = nil, turns: [AITurn]) async throws -> String {
        var output = ""
        for try await event in streamCompletion(model: model, system: system, turns: turns) {
            if case .text(let chunk) = event {
                output += chunk
            }
        }
        return output
    }
}

/// Default system prompt that gives SuperSiri its personality.
enum SuperSiriPersona {
    static let systemPrompt = """
    You are SuperSiri, a personal AI assistant living on the user's iPhone. \
    Be genuinely useful: give direct answers first, keep responses concise and \
    scannable on a phone screen, and use short paragraphs or tight lists. \
    When asked to draft content (messages, emails, plans), produce it ready to \
    copy — no meta-commentary. If a request is ambiguous, make a sensible \
    assumption and note it in one line rather than asking questions.
    """
}
