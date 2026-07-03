import SwiftUI
import SwiftData

struct ChatView: View {
    @Bindable var conversation: Conversation
    @Environment(\.modelContext) private var context
    @StateObject private var viewModel = ChatViewModel()
    @StateObject private var speech = SpeechRecognizerService()
    @State private var draft = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            messageList
            inputBar
        }
        .navigationTitle(conversation.model.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ModelPickerView(selectedModelID: $conversation.modelID)
            }
        }
        .onChange(of: speech.transcript) { _, transcript in
            if !transcript.isEmpty { draft = transcript }
        }
        .alert("Something went wrong", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(conversation.sortedMessages) { message in
                        MessageBubble(
                            role: message.messageRole,
                            text: message.text,
                            thinking: message.thinking,
                            modelName: message.modelID.flatMap { AIModel.model(withID: $0)?.displayName }
                        )
                        .id(message.persistentModelID)
                    }

                    if viewModel.isStreaming {
                        MessageBubble(
                            role: .assistant,
                            text: viewModel.streamingText.isEmpty ? "…" : viewModel.streamingText,
                            thinking: viewModel.streamingThinking,
                            modelName: conversation.model.displayName
                        )
                        .id("streaming")
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.streamingText) { _, _ in
                withAnimation { proxy.scrollTo("streaming", anchor: .bottom) }
            }
            .onChange(of: conversation.messages.count) { _, _ in
                if let last = conversation.sortedMessages.last {
                    proxy.scrollTo(last.persistentModelID, anchor: .bottom)
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Button {
                speech.toggleRecording()
            } label: {
                Image(systemName: speech.isRecording ? "mic.fill" : "mic")
                    .font(.title3)
                    .foregroundStyle(speech.isRecording ? .red : .purple)
                    .symbolEffect(.pulse, isActive: speech.isRecording)
            }
            .padding(.bottom, 10)

            TextField("Ask anything…", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .padding(10)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
                .focused($inputFocused)

            if viewModel.isStreaming {
                Button {
                    viewModel.stop()
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.title)
                        .foregroundStyle(.red)
                }
                .padding(.bottom, 4)
            } else {
                Button {
                    sendDraft()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                        .foregroundStyle(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .purple)
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.bottom, 4)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func sendDraft() {
        if speech.isRecording { speech.stop() }
        let prompt = draft
        draft = ""
        viewModel.send(prompt: prompt, in: conversation, context: context)
    }
}
