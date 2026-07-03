import SwiftUI

struct MessageBubble: View {
    let role: MessageRole
    let text: String
    var thinking: String = ""
    var modelName: String?

    @State private var showThinking = false

    var body: some View {
        HStack {
            if role == .user { Spacer(minLength: 40) }

            VStack(alignment: role == .user ? .trailing : .leading, spacing: 4) {
                if role == .assistant, let modelName {
                    Text(modelName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if role == .assistant, !thinking.isEmpty {
                    DisclosureGroup(isExpanded: $showThinking) {
                        Text(thinking)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } label: {
                        Label("Reasoning", systemImage: "brain")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                }

                Text(LocalizedStringKey(text)) // renders basic Markdown
                    .textSelection(.enabled)
                    .padding(12)
                    .background(bubbleBackground, in: RoundedRectangle(cornerRadius: 18))
                    .foregroundStyle(role == .user ? .white : .primary)

                if role == .assistant {
                    HStack(spacing: 16) {
                        Button {
                            UIPasteboard.general.string = text
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        Button {
                            SpeakerService.shared.speak(text)
                        } label: {
                            Image(systemName: "speaker.wave.2")
                        }
                        ShareLink(item: text) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
                }
            }

            if role == .assistant { Spacer(minLength: 40) }
        }
    }

    private var bubbleBackground: some ShapeStyle {
        role == .user
            ? AnyShapeStyle(LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
            : AnyShapeStyle(Color(.secondarySystemBackground))
    }
}
