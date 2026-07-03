import SwiftUI
import SwiftData

struct ConversationListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]
    @State private var newConversation: Conversation?

    var body: some View {
        NavigationStack {
            Group {
                if conversations.isEmpty {
                    ContentUnavailableView(
                        "No chats yet",
                        systemImage: "sparkles",
                        description: Text("Start a conversation with SuperSiri — it combines the best AI models in one place.")
                    )
                } else {
                    List {
                        ForEach(conversations) { conversation in
                            NavigationLink(value: conversation) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(conversation.title)
                                        .font(.headline)
                                        .lineLimit(1)
                                    HStack(spacing: 6) {
                                        Text(conversation.model.displayName)
                                            .font(.caption)
                                            .foregroundStyle(.purple)
                                        Text(conversation.updatedAt, style: .relative)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("SuperSiri")
            .navigationDestination(for: Conversation.self) { conversation in
                ChatView(conversation: conversation)
            }
            .navigationDestination(item: $newConversation) { conversation in
                ChatView(conversation: conversation)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        startNewChat()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
        }
    }

    private func startNewChat() {
        let conversation = Conversation()
        context.insert(conversation)
        try? context.save()
        newConversation = conversation
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(conversations[index])
        }
        try? context.save()
    }
}
