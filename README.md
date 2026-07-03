# SuperSiri 🪄

**The AI super-assistant for iPhone** — one app that combines Anthropic's Claude and OpenAI's GPT top models to chat, automate tasks, and run multi-step AI workflows, with deep Siri integration.

## Features

- **Multi-model chat** — talk to Claude Opus 4.8, Claude Sonnet 5, Claude Haiku 4.5, GPT-5.1, and GPT-5.1 mini. Switch models mid-conversation from the toolbar.
- **Live streaming** — responses stream in token by token, including Claude's summarized reasoning ("Reasoning" disclosure on each answer).
- **Workflows (automations)** — chain AI steps together with `{{input}}` / `{{previous}}` templating. Each step can use a different model (e.g. Haiku to summarize, Opus to draft). Ships with three starter workflows: *Summarize & Reply*, *Daily Briefing*, and *Idea → Action Plan*.
- **Siri & Shortcuts** — say **"Ask SuperSiri"** to get an AI answer by voice, or **"Run a SuperSiri workflow"** to trigger an automation. Both intents are also available as actions in the Shortcuts app, so SuperSiri composes with all your other iOS automations.
- **Voice in, voice out** — dictate prompts with on-device speech recognition; have answers read aloud with text-to-speech.
- **Smart model routing** — Siri questions are automatically routed to the best available model (fast models for quick lookups, top models for complex asks).
- **Private by design** — API keys live in the iOS Keychain and prompts go directly from your phone to the provider's API. No middleman server.

## Project structure

```
SuperSiri/
├── App/            App entry point, root tab view, shared SwiftData container
├── Models/         AIModel catalog, Conversation/ChatMessage, Workflow (SwiftData)
├── Services/       AnthropicService, OpenAIService (SSE streaming clients),
│                   AIRouter (provider routing + auto model pick),
│                   KeychainService, SpeechService (STT + TTS)
├── Workflows/      WorkflowEngine — runs step chains with live progress
├── Intents/        App Intents: AskSuperSiri, RunWorkflow, Siri shortcut phrases
├── ViewModels/     ChatViewModel — streaming chat state
└── Views/          Chat, conversation list, workflow editor/runner, settings
```

## Getting started

Requires **Xcode 15+** and **iOS 17+**.

1. Generate the Xcode project with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

   ```sh
   brew install xcodegen
   xcodegen generate
   open SuperSiri.xcodeproj
   ```

2. Select your signing team in *Signing & Capabilities*, then build & run on a device or simulator.

3. In the app, open **Settings** and paste your API keys:
   - Anthropic key from [console.anthropic.com](https://console.anthropic.com) (powers the Claude models)
   - OpenAI key from [platform.openai.com](https://platform.openai.com) (powers the GPT models)

   You only need one of the two to start chatting.

4. (Optional) Say *"Ask SuperSiri"* to Siri — App Shortcuts register automatically after first launch.

## How the AI integration works

- **Anthropic** — direct calls to the [Messages API](https://platform.claude.com/docs) (`POST /v1/messages`) with `stream: true`, parsing the SSE events (`content_block_delta` → `text_delta` / `thinking_delta`). Requests use adaptive thinking (`thinking: {type: "adaptive", display: "summarized"}`) so the app can show the model's reasoning summary. Default model: `claude-opus-4-8`.
- **OpenAI** — direct calls to the Chat Completions API with `stream: true`, parsing `choices[].delta.content` chunks.
- Both clients implement a shared `AIService` protocol that yields an `AsyncThrowingStream<AIStreamEvent>`, so the UI, workflow engine, and Siri intents are provider-agnostic.

## Model catalog

Model IDs live in `SuperSiri/Models/AIModel.swift`. To add or update a model (new releases, custom IDs), add an entry to `AIModel.all` — everything else (pickers, router, workflows) picks it up automatically.

## Roadmap ideas

- Tool use / function calling so workflows can touch Calendar, Reminders, and HomeKit
- Image input (camera + photo library → vision models)
- Web search-augmented answers
- iCloud sync for conversations and workflows
- Widgets and Lock Screen quick-ask
