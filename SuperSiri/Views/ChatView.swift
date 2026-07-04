import SwiftUI
import SwiftData
import PhotosUI

struct ChatView: View {
    @Bindable var conversation: Conversation
    @Environment(\.modelContext) private var context
    @StateObject private var viewModel = ChatViewModel()
    @StateObject private var speech = SpeechRecognizerService()
    @State private var draft = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var attachedImage: Data?
    @State private var showVoiceMode = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            messageList
            if let statusText = viewModel.statusText {
                statusPill(statusText)
            }
            inputBar
        }
        .navigationTitle(conversation.model.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showVoiceMode = true
                } label: {
                    Image(systemName: "waveform")
                }
                Menu {
                    Toggle(isOn: $conversation.superpowersEnabled) {
                        Label("Superpowers", systemImage: "wand.and.stars")
                    }
                    Text("Lets the AI use your Calendar, Reminders, Memory, and web search. Claude models only.")
                } label: {
                    Image(systemName: conversation.superpowersEnabled ? "wand.and.stars" : "wand.and.stars.inverse")
                }
                ModelPickerView(selectedModelID: $conversation.modelID)
            }
        }
        .fullScreenCover(isPresented: $showVoiceMode) {
            VoiceModeView(conversation: conversation)
        }
        .onChange(of: speech.transcript) { _, transcript in
            if !transcript.isEmpty { draft = transcript }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let compressed = UIImage(data: data)?.jpegData(compressionQuality: 0.7) {
                    attachedImage = compressed
                }
                photoItem = nil
            }
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
                            imageData: message.imageData,
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

    private func statusPill(_ text: String) -> some View {
        HStack(spacing: 6) {
            ProgressView().controlSize(.mini)
            Text(text).font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
        .padding(.bottom, 4)
    }

    private var inputBar: some View {
        VStack(spacing: 6) {
            if let attachedImage, let uiImage = UIImage(data: attachedImage) {
                HStack {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(alignment: .topTrailing) {
                            Button {
                                self.attachedImage = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.white, .black.opacity(0.6))
                            }
                            .offset(x: 6, y: -6)
                        }
                    Spacer()
                }
                .padding(.horizontal)
            }

            HStack(alignment: .bottom, spacing: 8) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Image(systemName: "photo")
                        .font(.title3)
                        .foregroundStyle(.purple)
                }
                .padding(.bottom, 10)

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
                            .foregroundStyle(canSend ? .purple : .gray)
                    }
                    .disabled(!canSend)
                    .padding(.bottom, 4)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || attachedImage != nil
    }

    private func sendDraft() {
        if speech.isRecording { speech.stop() }
        let prompt = draft
        let image = attachedImage
        draft = ""
        attachedImage = nil
        viewModel.send(prompt: prompt, imageData: image, in: conversation, context: context)
    }
}
