import SwiftUI

struct MessageBubble: View {
    let role: MessageRole
    let text: String
    var thinking: String = ""
    var imageData: Data?
    var modelName: String?

    @State private var showThinking = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if role == .user {
                Spacer(minLength: 48)
            } else {
                BrandOrb(size: 26)
                    .padding(.bottom, 4)
            }

            VStack(alignment: role == .user ? .trailing : .leading, spacing: 6) {
                if let imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 220, maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                if role == .assistant, !thinking.isEmpty {
                    Button {
                        withAnimation(.spring(duration: 0.3)) { showThinking.toggle() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "brain")
                            Text(showThinking ? "Hide reasoning" : "Reasoning")
                            Image(systemName: "chevron.down")
                                .rotationEffect(.degrees(showThinking ? 180 : 0))
                        }
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    if showThinking {
                        Text(thinking)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(10)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Theme.hairline, lineWidth: 1)
                            )
                    }
                }

                if !text.isEmpty {
                    Text(LocalizedStringKey(text)) // renders basic Markdown
                        .textSelection(.enabled)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(bubbleBackground)
                        .foregroundStyle(role == .user ? .white : .primary)
                        .clipShape(bubbleShape)
                        .overlay {
                            if role == .assistant {
                                bubbleShape.strokeBorder(Theme.hairline, lineWidth: 1)
                            }
                        }
                }

                if role == .assistant {
                    HStack(spacing: 8) {
                        if let modelName {
                            Text(modelName)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
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
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 2)
                }
            }

            if role == .assistant { Spacer(minLength: 48) }
        }
    }

    private var bubbleShape: UnevenRoundedRectangle {
        // Squared-off corner on the "speaking" side, like a real chat tail.
        role == .user
            ? UnevenRoundedRectangle(
                topLeadingRadius: Theme.bubbleRadius,
                bottomLeadingRadius: Theme.bubbleRadius,
                bottomTrailingRadius: 6,
                topTrailingRadius: Theme.bubbleRadius,
                style: .continuous
            )
            : UnevenRoundedRectangle(
                topLeadingRadius: Theme.bubbleRadius,
                bottomLeadingRadius: 6,
                bottomTrailingRadius: Theme.bubbleRadius,
                topTrailingRadius: Theme.bubbleRadius,
                style: .continuous
            )
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        if role == .user {
            Theme.accent
        } else {
            Theme.card
        }
    }
}
