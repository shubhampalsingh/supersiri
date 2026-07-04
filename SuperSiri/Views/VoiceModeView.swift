import SwiftUI
import SwiftData
import AVFoundation

/// Hands-free conversation: listen → think → speak → listen again.
/// Detects end of speech with a short silence window, streams the model's
/// reply, speaks it aloud, then automatically resumes listening.
struct VoiceModeView: View {
    @Bindable var conversation: Conversation
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @StateObject private var controller = VoiceLoopController()

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.ink, Theme.ember.opacity(0.35)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    Button {
                        controller.shutdown()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding()

                Spacer()

                Text(controller.displayText)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .frame(maxHeight: 300)

                Spacer()

                orb

                Text(controller.phaseLabel)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.bottom, 32)
            }
        }
        .onAppear {
            controller.configure(conversation: conversation, context: context)
            controller.startListening()
        }
        .onDisappear {
            controller.shutdown()
        }
    }

    private var orb: some View {
        Button {
            controller.orbTapped()
        } label: {
            ZStack {
                // Soft outer glow rings
                Circle()
                    .fill(Theme.ember.opacity(0.16))
                    .frame(width: 210, height: 210)
                    .blur(radius: 24)
                Circle()
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                    .frame(width: 176, height: 176)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: orbColors,
                            center: .init(x: 0.38, y: 0.32),
                            startRadius: 10,
                            endRadius: 90
                        )
                    )
                    .frame(width: 140, height: 140)
                    .shadow(color: Theme.ember.opacity(0.5), radius: 30, y: 8)
                    .scaleEffect(controller.phase == .listening ? 1.08 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: controller.phase)

                Image(systemName: orbIcon)
                    .font(.system(size: 44))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
    }

    private var orbColors: [Color] {
        switch controller.phase {
        case .idle: return [.gray, .black]
        case .listening: return [Theme.amber, Theme.ember]
        case .thinking: return [.white.opacity(0.9), Theme.ember]
        case .speaking: return [Theme.ember, Theme.ink]
        }
    }

    private var orbIcon: String {
        switch controller.phase {
        case .idle: return "mic.slash"
        case .listening: return "mic.fill"
        case .thinking: return "sparkles"
        case .speaking: return "speaker.wave.3.fill"
        }
    }
}

// MARK: - Controller

@MainActor
final class VoiceLoopController: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    enum Phase {
        case idle, listening, thinking, speaking
    }

    @Published var phase: Phase = .idle
    @Published var displayText = "Tap the orb and start talking"

    private let speech = SpeechRecognizerService()
    private let synthesizer = AVSpeechSynthesizer()
    private let router = AIRouter.shared

    private var conversation: Conversation?
    private var context: ModelContext?
    private var silenceTimer: Timer?
    private var lastTranscript = ""
    private var observation: Task<Void, Never>?
    private var thinkTask: Task<Void, Never>?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func configure(conversation: Conversation, context: ModelContext) {
        self.conversation = conversation
        self.context = context
    }

    var phaseLabel: String {
        switch phase {
        case .idle: return "Paused — tap the orb to talk"
        case .listening: return "Listening… pause to send"
        case .thinking: return "Thinking…"
        case .speaking: return "Speaking — tap the orb to interrupt"
        }
    }

    func orbTapped() {
        switch phase {
        case .idle:
            startListening()
        case .listening:
            // Send immediately without waiting for silence.
            sendCurrentTranscript()
        case .speaking:
            synthesizer.stopSpeaking(at: .immediate)
            startListening()
        case .thinking:
            break
        }
    }

    func startListening() {
        guard phase != .listening else { return }
        phase = .listening
        displayText = "Listening…"
        lastTranscript = ""
        speech.start()
        watchTranscript()
    }

    private func watchTranscript() {
        observation?.cancel()
        observation = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled, self.phase == .listening {
                try? await Task.sleep(for: .milliseconds(300))
                let current = self.speech.transcript
                if !current.isEmpty {
                    self.displayText = current
                    if current == self.lastTranscript {
                        // No change for ~1.5s → user stopped talking.
                        self.silenceTicks += 1
                        if self.silenceTicks >= 5 {
                            self.sendCurrentTranscript()
                            return
                        }
                    } else {
                        self.silenceTicks = 0
                        self.lastTranscript = current
                    }
                }
            }
        }
    }

    private var silenceTicks = 0

    private func sendCurrentTranscript() {
        let prompt = speech.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        speech.stop()
        observation?.cancel()
        silenceTicks = 0
        guard !prompt.isEmpty, let conversation, let context else {
            phase = .idle
            return
        }

        phase = .thinking
        displayText = prompt

        let userMessage = ChatMessage(role: .user, text: prompt)
        conversation.messages.append(userMessage)
        conversation.updatedAt = .now
        try? context.save()

        let turns = conversation.sortedMessages.map {
            AITurn(role: $0.messageRole, content: $0.aiContent)
        }
        let model = conversation.model
        let useAgent = conversation.superpowersEnabled

        thinkTask = Task { [weak self] in
            guard let self else { return }
            var reply = ""
            do {
                let system = SuperSiriPersona.systemPrompt
                    + "\nYou are in a voice conversation: answer in natural spoken prose, no markdown or lists, under 120 words unless asked for detail."
                let stream = useAgent
                    ? self.router.streamAgentCompletion(model: model, system: system, turns: turns)
                    : self.router.streamCompletion(model: model, system: system, turns: turns)
                for try await event in stream {
                    if case .text(let chunk) = event {
                        reply += chunk
                    }
                    if case .status(let status) = event {
                        self.displayText = status
                    }
                }
            } catch {
                reply = "Sorry — \(error.localizedDescription)"
            }

            guard !Task.isCancelled else { return }
            let assistantMessage = ChatMessage(role: .assistant, text: reply, modelID: model.id)
            conversation.messages.append(assistantMessage)
            conversation.updatedAt = .now
            try? context.save()

            self.displayText = reply
            self.speak(reply)
        }
    }

    private func speak(_ text: String) {
        phase = .speaking
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
            try session.setActive(true)
        } catch {}
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.identifier)
            ?? AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }

    func shutdown() {
        observation?.cancel()
        thinkTask?.cancel()
        speech.stop()
        synthesizer.stopSpeaking(at: .immediate)
        phase = .idle
    }

    // MARK: AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            // Loop back to listening for a natural conversation.
            self.startListening()
        }
    }
}
