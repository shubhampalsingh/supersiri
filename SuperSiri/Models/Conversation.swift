import Foundation
import SwiftData

@Model
final class Conversation {
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var modelID: String
    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.conversation)
    var messages: [ChatMessage]

    init(title: String = "New Chat", modelID: String = AIModel.default.id) {
        self.title = title
        self.createdAt = .now
        self.updatedAt = .now
        self.modelID = modelID
        self.messages = []
    }

    var sortedMessages: [ChatMessage] {
        messages.sorted { $0.createdAt < $1.createdAt }
    }

    var model: AIModel {
        AIModel.model(withID: modelID) ?? .default
    }
}

@Model
final class ChatMessage {
    var role: String // "user" | "assistant"
    var text: String
    /// Summarized reasoning returned by models that expose it (Claude adaptive thinking).
    var thinking: String
    var modelID: String?
    var createdAt: Date
    var conversation: Conversation?

    init(role: MessageRole, text: String, thinking: String = "", modelID: String? = nil) {
        self.role = role.rawValue
        self.text = text
        self.thinking = thinking
        self.modelID = modelID
        self.createdAt = .now
    }

    var messageRole: MessageRole {
        MessageRole(rawValue: role) ?? .user
    }
}

enum MessageRole: String, Codable {
    case user
    case assistant
}
