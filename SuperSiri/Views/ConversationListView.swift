import SwiftUI
import SwiftData

struct ConversationListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]
    @State private var newConversation: Conversation?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backdrop

                if conversations.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(conversations) { conversation in
                                NavigationLink(value: conversation) {
                                    conversationRow(conversation)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        context.delete(conversation)
                                        try? context.save()
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 80)
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
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            BrandOrb(size: 96, animated: true)

            VStack(spacing: 6) {
                Text("Your AI, supercharged")
                    .font(Theme.display(26))
                Text("The best models. Real actions on your phone.\nOne conversation away.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                startNewChat()
            } label: {
                Label("Start chatting", systemImage: "sparkles")
            }
            .buttonStyle(EmberButtonStyle())
            .padding(.horizontal, 48)
        }
        .padding()
    }

    private func conversationRow(_ conversation: Conversation) -> some View {
        HStack(spacing: 14) {
            BrandOrb(size: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(conversation.title)
                    .font(Theme.display(16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if conversation.superpowersEnabled {
                        Image(systemName: "wand.and.stars")
                            .font(.caption2)
                            .foregroundStyle(Theme.ember)
                    }
                    Text(conversation.model.displayName)
                        .font(.caption)
                        .foregroundStyle(Theme.ember)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(conversation.updatedAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .cardStyle()
    }

    private func startNewChat() {
        let conversation = Conversation()
        context.insert(conversation)
        try? context.save()
        newConversation = conversation
    }
}
