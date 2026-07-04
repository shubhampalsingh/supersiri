import Foundation

/// Agentic loop on the Anthropic Messages API: sends the conversation with
/// tool definitions, executes any `tool_use` blocks against device tools
/// (Calendar, Reminders, Memory), feeds `tool_result`s back, and repeats
/// until the model finishes. Also enables Anthropic's server-side web search.
///
/// Each iteration is a non-streaming request — tool orchestration needs the
/// complete content blocks — and text is yielded per iteration, so the UI
/// still updates progressively between steps.
final class AnthropicAgent {
    private let session: URLSession
    private let apiKeyProvider: () -> String?
    private let tools: [any AgentTool]
    private let enableWebSearch: Bool
    private let maxIterations = 8

    init(
        session: URLSession = .shared,
        apiKeyProvider: @escaping () -> String? = { KeychainService.shared.apiKey(for: .anthropic) },
        tools: [any AgentTool] = AgentToolbox.allTools(),
        enableWebSearch: Bool = true
    ) {
        self.session = session
        self.apiKeyProvider = apiKeyProvider
        self.tools = tools
        self.enableWebSearch = enableWebSearch
    }

    func run(
        model: AIModel,
        system: String?,
        turns: [AITurn]
    ) -> AsyncThrowingStream<AIStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await self.runLoop(model: model, system: system, turns: turns, continuation: continuation)
                    continuation.yield(.done)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func runLoop(
        model: AIModel,
        system: String?,
        turns: [AITurn],
        continuation: AsyncThrowingStream<AIStreamEvent, Error>.Continuation
    ) async throws {
        guard let apiKey = apiKeyProvider(), !apiKey.isEmpty else {
            throw AIServiceError.missingAPIKey(.anthropic)
        }

        // Mutable message list built from raw JSON dictionaries so that
        // assistant content (thinking blocks, tool_use blocks, server tool
        // results) can be echoed back exactly as received.
        var messages: [[String: Any]] = turns.map {
            ["role": $0.role.rawValue, "content": AnthropicService.contentBlocks(for: $0.content)]
        }

        var toolDefinitions: [[String: Any]] = tools.map {
            ["name": $0.name, "description": $0.description, "input_schema": $0.inputSchema]
        }
        if enableWebSearch {
            toolDefinitions.append(["type": "web_search_20260209", "name": "web_search"])
        }

        for _ in 0..<maxIterations {
            try Task.checkCancellation()

            var body: [String: Any] = [
                "model": model.id,
                "max_tokens": AnthropicService.maxTokens,
                "thinking": ["type": "adaptive", "display": "summarized"],
                "tools": toolDefinitions,
                "messages": messages,
            ]
            if let system, !system.isEmpty {
                body["system"] = system
            }

            var request = URLRequest(url: AnthropicService.apiURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue(AnthropicService.apiVersion, forHTTPHeaderField: "anthropic-version")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.timeoutInterval = 300

            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw AIServiceError.invalidResponse
            }
            guard http.statusCode == 200 else {
                let bodyText = String(data: data, encoding: .utf8) ?? ""
                throw AIServiceError.httpError(status: http.statusCode, body: Self.errorMessage(fromBody: bodyText))
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = json["content"] as? [[String: Any]]
            else {
                throw AIServiceError.invalidResponse
            }
            let stopReason = json["stop_reason"] as? String

            if stopReason == "refusal" {
                throw AIServiceError.refused("Try rephrasing your request.")
            }

            // Surface this iteration's visible output.
            for block in content {
                switch block["type"] as? String {
                case "text":
                    if let text = block["text"] as? String, !text.isEmpty {
                        continuation.yield(.text(text))
                    }
                case "thinking":
                    if let thinking = block["thinking"] as? String, !thinking.isEmpty {
                        continuation.yield(.thinking(thinking))
                    }
                case "server_tool_use":
                    continuation.yield(.status("Searching the web…"))
                default:
                    break
                }
            }

            // Echo the assistant turn back exactly as received.
            messages.append(["role": "assistant", "content": content])

            switch stopReason {
            case "tool_use":
                let toolUses = content.filter { ($0["type"] as? String) == "tool_use" }
                var results: [[String: Any]] = []
                for toolUse in toolUses {
                    guard let id = toolUse["id"] as? String,
                          let name = toolUse["name"] as? String
                    else { continue }
                    let input = toolUse["input"] as? [String: Any] ?? [:]

                    guard let tool = tools.first(where: { $0.name == name }) else {
                        results.append(Self.toolResult(id: id, content: "Unknown tool \(name).", isError: true))
                        continue
                    }

                    continuation.yield(.status(tool.statusLabel))
                    do {
                        let output = try await tool.execute(input: input)
                        results.append(Self.toolResult(id: id, content: output, isError: false))
                    } catch {
                        // Report the failure to the model so it can adapt.
                        results.append(Self.toolResult(id: id, content: error.localizedDescription, isError: true))
                    }
                }
                messages.append(["role": "user", "content": results])

            case "pause_turn":
                // Server-side tool (web search) needs another round — resend as-is.
                continue

            default:
                return // end_turn, max_tokens, etc. — we're done.
            }
        }

        continuation.yield(.text("\n\n_(Stopped after reaching the step limit for one request.)_"))
    }

    private static func toolResult(id: String, content: String, isError: Bool) -> [String: Any] {
        var result: [String: Any] = [
            "type": "tool_result",
            "tool_use_id": id,
            "content": content,
        ]
        if isError { result["is_error"] = true }
        return result
    }

    private static func errorMessage(fromBody body: String) -> String {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any],
              let message = error["message"] as? String
        else { return body }
        return message
    }
}
