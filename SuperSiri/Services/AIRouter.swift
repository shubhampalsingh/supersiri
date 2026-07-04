import Foundation

/// Routes requests to the right provider client, and can auto-pick a model.
final class AIRouter {
    static let shared = AIRouter()

    private let anthropic: AIService
    private let openai: AIService

    init(anthropic: AIService = AnthropicService(), openai: AIService = OpenAIService()) {
        self.anthropic = anthropic
        self.openai = openai
    }

    func service(for provider: AIProvider) -> AIService {
        switch provider {
        case .anthropic: return anthropic
        case .openai: return openai
        }
    }

    func streamCompletion(
        model: AIModel,
        system: String? = SuperSiriPersona.systemPrompt,
        turns: [AITurn]
    ) -> AsyncThrowingStream<AIStreamEvent, Error> {
        service(for: model.provider).streamCompletion(model: model, system: system, turns: turns)
    }

    /// Agentic completion with device tools (Calendar, Reminders, Memory) and
    /// web search. Tool use runs on Anthropic models; if an OpenAI model is
    /// selected, this transparently falls back to plain streaming.
    func streamAgentCompletion(
        model: AIModel,
        system: String? = nil,
        turns: [AITurn]
    ) -> AsyncThrowingStream<AIStreamEvent, Error> {
        let effectiveSystem = (system ?? SuperSiriPersona.systemPrompt) + """
        \n\nYou can act on the user's iPhone through your tools: calendar, \
        reminders, contacts, place search, HomeKit devices, long-term memory, \
        and web search. Use them proactively when the request implies an \
        action or needs current information — don't just describe what the \
        user could do. Chain tools when needed (e.g. search_contacts before \
        drafting a message to someone). After acting, confirm what you did in \
        one line.
        """
        guard model.provider == .anthropic else {
            return streamCompletion(model: model, system: effectiveSystem, turns: turns)
        }
        return AnthropicAgent().run(model: model, system: effectiveSystem, turns: turns)
    }

    func complete(
        model: AIModel,
        system: String? = SuperSiriPersona.systemPrompt,
        turns: [AITurn]
    ) async throws -> String {
        try await service(for: model.provider).complete(model: model, system: system, turns: turns)
    }

    /// Picks a sensible model for a prompt without asking the user:
    /// short/simple prompts go to a fast model, everything else to the
    /// most capable model with a configured key.
    func autoPick(for prompt: String) -> AIModel {
        let usable = AIModel.all.filter { KeychainService.shared.hasKey(for: $0.provider) }
        guard !usable.isEmpty else { return .default }

        let isQuick = prompt.count < 120 && !prompt.contains("\n")
        let ranked = usable.sorted {
            isQuick ? ($0.speed, $0.capability) > ($1.speed, $1.capability)
                    : ($0.capability, $0.speed) > ($1.capability, $1.speed)
        }
        return ranked[0]
    }
}
