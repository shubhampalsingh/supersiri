import Foundation

/// Live progress for a running workflow.
struct WorkflowStepResult: Identifiable {
    let id: UUID
    let stepName: String
    let modelName: String
    var output: String
    var state: State

    enum State {
        case pending
        case running
        case finished
        case failed(String)
    }
}

/// Executes a workflow: runs each step in order, substituting
/// `{{input}}` with the workflow input and `{{previous}}` with the
/// prior step's output.
@MainActor
final class WorkflowEngine: ObservableObject {
    @Published var results: [WorkflowStepResult] = []
    @Published var isRunning = false
    @Published var finalOutput: String = ""

    private let router: AIRouter
    private var runTask: Task<Void, Never>?

    init(router: AIRouter = .shared) {
        self.router = router
    }

    func run(steps: [WorkflowStep], input: String) {
        cancel()
        finalOutput = ""
        results = steps.map {
            WorkflowStepResult(id: $0.id, stepName: $0.name, modelName: $0.model.displayName, output: "", state: .pending)
        }
        isRunning = true

        runTask = Task {
            var previousOutput = ""
            for (index, step) in steps.enumerated() {
                guard !Task.isCancelled else { break }
                results[index].state = .running

                let prompt = Self.renderPrompt(step.prompt, input: input, previous: previousOutput)
                do {
                    let stream = router.streamCompletion(
                        model: step.model,
                        turns: [AITurn(role: .user, text: prompt)]
                    )
                    for try await event in stream {
                        if case .text(let chunk) = event {
                            results[index].output += chunk
                        }
                    }
                    previousOutput = results[index].output
                    results[index].state = .finished
                } catch {
                    results[index].state = .failed(error.localizedDescription)
                    isRunning = false
                    return
                }
            }
            finalOutput = previousOutput
            isRunning = false
        }
    }

    func cancel() {
        runTask?.cancel()
        runTask = nil
        isRunning = false
    }

    /// Non-streaming execution used by App Intents (Siri / Shortcuts).
    static func runToCompletion(steps: [WorkflowStep], input: String, router: AIRouter = .shared) async throws -> String {
        var previousOutput = ""
        for step in steps {
            let prompt = renderPrompt(step.prompt, input: input, previous: previousOutput)
            previousOutput = try await router.complete(
                model: step.model,
                turns: [AITurn(role: .user, text: prompt)]
            )
        }
        return previousOutput
    }

    static func renderPrompt(_ template: String, input: String, previous: String) -> String {
        template
            .replacingOccurrences(of: "{{input}}", with: input)
            .replacingOccurrences(of: "{{previous}}", with: previous)
    }
}
