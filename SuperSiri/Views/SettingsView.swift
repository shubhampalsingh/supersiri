import SwiftUI

struct SettingsView: View {
    @State private var anthropicKey = ""
    @State private var openaiKey = ""
    @State private var savedBanner: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("sk-ant-…", text: $anthropicKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Save Anthropic Key") {
                        KeychainService.shared.setAPIKey(anthropicKey, for: .anthropic)
                        savedBanner = "Anthropic key saved"
                    }
                    .disabled(anthropicKey.isEmpty)
                } header: {
                    Label("Anthropic (Claude)", systemImage: keyStatusIcon(for: .anthropic))
                } footer: {
                    Text("Get a key at console.anthropic.com. Powers Claude Opus, Sonnet, and Haiku.")
                }

                Section {
                    SecureField("sk-…", text: $openaiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Save OpenAI Key") {
                        KeychainService.shared.setAPIKey(openaiKey, for: .openai)
                        savedBanner = "OpenAI key saved"
                    }
                    .disabled(openaiKey.isEmpty)
                } header: {
                    Label("OpenAI (GPT)", systemImage: keyStatusIcon(for: .openai))
                } footer: {
                    Text("Get a key at platform.openai.com. Powers the GPT models.")
                }

                Section("Privacy") {
                    Label {
                        Text("Keys are stored only in your device's Keychain and sent only to the provider you chose.")
                    } icon: {
                        Image(systemName: "lock.shield")
                            .foregroundStyle(.green)
                    }
                    .font(.footnote)

                    Button("Remove All Keys", role: .destructive) {
                        KeychainService.shared.deleteAPIKey(for: .anthropic)
                        KeychainService.shared.deleteAPIKey(for: .openai)
                        anthropicKey = ""
                        openaiKey = ""
                        savedBanner = "All keys removed"
                    }
                }

                Section("Siri & Shortcuts") {
                    Text("Say **\"Ask SuperSiri\"** to ask a question by voice, or **\"Run a SuperSiri workflow\"** to trigger an automation. Both also appear as actions in the Shortcuts app for building bigger automations.")
                        .font(.footnote)
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                }
            }
            .navigationTitle("Settings")
            .overlay(alignment: .bottom) {
                if let savedBanner {
                    Text(savedBanner)
                        .font(.footnote.weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.thinMaterial, in: Capsule())
                        .padding(.bottom, 12)
                        .task {
                            try? await Task.sleep(for: .seconds(2))
                            self.savedBanner = nil
                        }
                }
            }
        }
    }

    private func keyStatusIcon(for provider: AIProvider) -> String {
        KeychainService.shared.hasKey(for: provider) ? "checkmark.seal.fill" : "key"
    }
}
