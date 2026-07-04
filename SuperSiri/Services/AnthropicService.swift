import Foundation

/// Client for the Anthropic Messages API (`POST /v1/messages`) with SSE streaming.
///
/// Notes on the request shape (current as of the Claude 5 / Opus 4.8 family):
/// - `thinking: {type: "adaptive", display: "summarized"}` enables adaptive
///   thinking and returns readable reasoning summaries we can show in the UI.
/// - Sampling params (`temperature`, `top_p`, `top_k`) are NOT sent — they are
///   rejected on Opus 4.7+.
final class AnthropicService: AIService {
    private let session: URLSession
    private let apiKeyProvider: () -> String?

    static let apiURL = URL(string: "https://api.anthropic.com/v1/messages")!
    static let apiVersion = "2023-06-01"
    static let maxTokens = 16000

    init(session: URLSession = .shared, apiKeyProvider: @escaping () -> String? = { KeychainService.shared.apiKey(for: .anthropic) }) {
        self.session = session
        self.apiKeyProvider = apiKeyProvider
    }

    func streamCompletion(
        model: AIModel,
        system: String?,
        turns: [AITurn]
    ) -> AsyncThrowingStream<AIStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let apiKey = self.apiKeyProvider(), !apiKey.isEmpty else {
                        throw AIServiceError.missingAPIKey(.anthropic)
                    }

                    let request = try Self.makeRequest(
                        apiKey: apiKey,
                        model: model,
                        system: system,
                        turns: turns
                    )

                    let (bytes, response) = try await self.session.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw AIServiceError.invalidResponse
                    }
                    guard http.statusCode == 200 else {
                        var body = ""
                        for try await line in bytes.lines {
                            body += line
                            if body.count > 2000 { break }
                        }
                        throw AIServiceError.httpError(status: http.statusCode, body: Self.errorMessage(fromBody: body))
                    }

                    var stopReason: String?
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        guard payload != "[DONE]",
                              let data = payload.data(using: .utf8),
                              let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let type = event["type"] as? String
                        else { continue }

                        switch type {
                        case "content_block_delta":
                            if let delta = event["delta"] as? [String: Any],
                               let deltaType = delta["type"] as? String {
                                if deltaType == "text_delta", let text = delta["text"] as? String {
                                    continuation.yield(.text(text))
                                } else if deltaType == "thinking_delta", let thinking = delta["thinking"] as? String {
                                    continuation.yield(.thinking(thinking))
                                }
                            }
                        case "message_delta":
                            if let delta = event["delta"] as? [String: Any],
                               let reason = delta["stop_reason"] as? String {
                                stopReason = reason
                            }
                        case "message_stop":
                            break
                        case "error":
                            let message = (event["error"] as? [String: Any])?["message"] as? String ?? "Unknown streaming error."
                            throw AIServiceError.httpError(status: 200, body: message)
                        default:
                            break
                        }
                    }

                    if stopReason == "refusal" {
                        throw AIServiceError.refused("Try rephrasing your request.")
                    }

                    continuation.yield(.done)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Request building

    /// Converts app content into Messages API content blocks.
    /// Images precede text, per API guidance.
    static func contentBlocks(for content: [AIContent]) -> [[String: Any]] {
        var blocks: [[String: Any]] = []
        for item in content {
            if case .image(let data, let mediaType) = item {
                blocks.append([
                    "type": "image",
                    "source": [
                        "type": "base64",
                        "media_type": mediaType,
                        "data": data.base64EncodedString(),
                    ],
                ])
            }
        }
        for item in content {
            if case .text(let text) = item, !text.isEmpty {
                blocks.append(["type": "text", "text": text])
            }
        }
        return blocks
    }

    static func makeRequest(apiKey: String, model: AIModel, system: String?, turns: [AITurn]) throws -> URLRequest {
        var body: [String: Any] = [
            "model": model.id,
            "max_tokens": maxTokens,
            "stream": true,
            "thinking": ["type": "adaptive", "display": "summarized"],
            "messages": turns.map { ["role": $0.role.rawValue, "content": contentBlocks(for: $0.content)] },
        ]
        if let system, !system.isEmpty {
            body["system"] = system
        }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 300 // long generations can take minutes
        return request
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
