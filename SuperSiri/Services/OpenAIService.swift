import Foundation

/// Client for the OpenAI Chat Completions API with SSE streaming.
final class OpenAIService: AIService {
    private let session: URLSession
    private let apiKeyProvider: () -> String?

    static let apiURL = URL(string: "https://api.openai.com/v1/chat/completions")!

    init(session: URLSession = .shared, apiKeyProvider: @escaping () -> String? = { KeychainService.shared.apiKey(for: .openai) }) {
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
                        throw AIServiceError.missingAPIKey(.openai)
                    }

                    var messages: [[String: String]] = []
                    if let system, !system.isEmpty {
                        messages.append(["role": "system", "content": system])
                    }
                    messages.append(contentsOf: turns.map { ["role": $0.role.rawValue, "content": $0.text] })

                    let body: [String: Any] = [
                        "model": model.id,
                        "stream": true,
                        "messages": messages,
                    ]

                    var request = URLRequest(url: Self.apiURL)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)
                    request.timeoutInterval = 300

                    let (bytes, response) = try await self.session.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw AIServiceError.invalidResponse
                    }
                    guard http.statusCode == 200 else {
                        var errorBody = ""
                        for try await line in bytes.lines {
                            errorBody += line
                            if errorBody.count > 2000 { break }
                        }
                        throw AIServiceError.httpError(status: http.statusCode, body: errorBody)
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        if payload == "[DONE]" { break }
                        guard let data = payload.data(using: .utf8),
                              let chunk = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let choices = chunk["choices"] as? [[String: Any]],
                              let first = choices.first,
                              let delta = first["delta"] as? [String: Any],
                              let content = delta["content"] as? String
                        else { continue }
                        continuation.yield(.text(content))
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
}
