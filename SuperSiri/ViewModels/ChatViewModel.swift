import Foundation
import SwiftData

/// Drives a single chat: sends the conversation to the selected model and
/// streams the reply into the UI token by token.
@MainActor
final class ChatViewModel: ObservableObject {
    @Published var streamingText: String = ""
    @Published var streamingThinking: String = ""
    @Published var isStreaming = false
    @Published var errorMessage: String?

    private let router: AIRouter
    private var streamTask: Task<Void, Never>?

    init(router: AIRouter = .shared) {
        self.router = router
    }

    func send(prompt: String, in conversation: Conversation, context: ModelContext) {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isStreaming else { return }

        errorMessage = nil
        let userMessage = ChatMessage(role: .user, text: trimmed)
        conversation.messages.append(userMessage)
        conversation.updatedAt = .now
        if conversation.messages.count == 1 {
            conversation.title = String(trimmed.prefix(50))
        }
        try? context.save()

        let model = conversation.model
        let turns = conversation.sortedMessages.map {
            AITurn(role: $0.messageRole, text: $0.text)
        }

        streamingText = ""
        streamingThinking = ""
        isStreaming = true

        streamTask = Task {
            do {
                let stream = router.streamCompletion(model: model, turns: turns)
                for try await event in stream {
                    switch event {
                    case .text(let chunk):
                        streamingText += chunk
                    case .thinking(let chunk):
                        streamingThinking += chunk
                    case .done:
                        break
                    }
                }
                finishStreaming(into: conversation, model: model, context: context)
            } catch is CancellationError {
                finishStreaming(into: conversation, model: model, context: context)
            } catch {
                if !streamingText.isEmpty {
                    finishStreaming(into: conversation, model: model, context: context)
                } else {
                    isStreaming = false
                }
                errorMessage = error.localizedDescription
            }
        }
    }

    func stop() {
        streamTask?.cancel()
        streamTask = nil
    }

    private func finishStreaming(into conversation: Conversation, model: AIModel, context: ModelContext) {
        if !streamingText.isEmpty {
            let assistantMessage = ChatMessage(
                role: .assistant,
                text: streamingText,
                thinking: streamingThinking,
                modelID: model.id
            )
            conversation.messages.append(assistantMessage)
            conversation.updatedAt = .now
            try? context.save()
        }
        streamingText = ""
        streamingThinking = ""
        isStreaming = false
    }
}
