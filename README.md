# SuperSiri 🪄

**The AI super-assistant for iPhone** — one app that combines Anthropic's Claude and OpenAI's GPT top models to chat, automate tasks, and run multi-step AI workflows, with deep Siri integration.

## Features

- **Superpowers (agent mode)** — the AI doesn't just talk, it *acts*. With the wand toggle on, Claude can check and create **Calendar events**, list and create **Reminders**, look up **Contacts**, find **Places** near you (with Apple Maps links), switch **HomeKit** lights/outlets on and off, save facts to **Memory**, and **search the web** — deciding on its own when to use and chain each tool ("find Anna's number and remind me to call her at 6" just works). Live status pills show what it's doing.
- **Memory** — SuperSiri remembers durable facts about you across conversations (preferences, names, context) and personalizes every answer. Review or delete everything in Settings → Memory; stored only on-device.
- **Vision** — attach a photo from your library or snap one with the camera: whiteboards → notes, menus → recommendations, screenshots → answers.
- **Voice Mode** — a hands-free, Siri-style conversation screen: talk, pause, hear the answer, keep talking. Tap the orb to interrupt.
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
├── Services/       AnthropicService + AnthropicAgent (tool-use loop, web search),
│                   OpenAIService, AIRouter (provider routing + auto model pick),
│                   AgentTools (EventKit Calendar/Reminders + Memory tools),
│                   MemoryStore, KeychainService, SpeechService (STT + TTS)
├── Workflows/      WorkflowEngine — runs step chains with live progress
├── Intents/        App Intents: AskSuperSiri, RunWorkflow, Siri shortcut phrases
├── ViewModels/     ChatViewModel — streaming chat state
└── Views/          Chat, voice mode, workflow editor/runner, memory, settings
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
- **Agent mode** (`AnthropicAgent`) — when Superpowers is on, requests include tool definitions (Calendar, Reminders, Memory) plus Anthropic's server-side `web_search_20260209` tool. The client runs the standard tool-use loop: execute each `tool_use` block on-device via EventKit, return `tool_result` blocks, repeat until `end_turn` (with `pause_turn` handling for server tools). Assistant content — including thinking blocks — is echoed back verbatim each round.
- **Vision** — attached photos are sent as base64 `image` content blocks (Anthropic) or `image_url` data URIs (OpenAI).
- **OpenAI** — direct calls to the Chat Completions API with `stream: true`, parsing `choices[].delta.content` chunks.
- Both clients implement a shared `AIService` protocol that yields an `AsyncThrowingStream<AIStreamEvent>`, so the UI, workflow engine, and Siri intents are provider-agnostic.

## Model catalog

Model IDs live in `SuperSiri/Models/AIModel.swift`. To add or update a model (new releases, custom IDs), add an entry to `AIModel.all` — everything else (pickers, router, workflows) picks it up automatically.

## Roadmap ideas

- More device tools: Music, Messages drafts, Health
- Streaming inside agent mode (per-token instead of per-step)
- iCloud sync for conversations, workflows, and memory
- Widgets, Lock Screen quick-ask, Action Button integration, keyboard extension
