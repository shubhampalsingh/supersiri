import AppIntents
import Foundation
import SwiftData

/// Runs a saved SuperSiri workflow from Siri or the Shortcuts app,
/// so workflows compose with the rest of a user's iOS automations.
struct RunWorkflowIntent: AppIntent {
    static var title: LocalizedStringResource = "Run SuperSiri Workflow"
    static var description = IntentDescription(
        "Runs one of your saved AI workflows with the text you provide.",
        categoryName: "AI"
    )

    @Parameter(title: "Workflow", optionsProvider: WorkflowOptionsProvider())
    var workflowName: String

    @Parameter(title: "Input", requestValueDialog: "What should the workflow run on?")
    var input: String

    static var parameterSummary: some ParameterSummary {
        Summary("Run \(\.$workflowName) on \(\.$input)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let context = ModelContext(PersistenceController.sharedContainer)
        let descriptor = FetchDescriptor<Workflow>()
        let workflows = try context.fetch(descriptor)

        guard let workflow = workflows.first(where: { $0.name.localizedCaseInsensitiveCompare(workflowName) == .orderedSame }) else {
            throw IntentError.workflowNotFound(workflowName)
        }

        let output = try await WorkflowEngine.runToCompletion(steps: workflow.steps, input: input)
        return .result(value: output, dialog: IntentDialog(stringLiteral: output))
    }

    enum IntentError: LocalizedError {
        case workflowNotFound(String)

        var errorDescription: String? {
            switch self {
            case .workflowNotFound(let name):
                return "No workflow named \"\(name)\" was found in SuperSiri."
            }
        }
    }
}

struct WorkflowOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [String] {
        let context = ModelContext(PersistenceController.sharedContainer)
        let workflows = try context.fetch(FetchDescriptor<Workflow>())
        return workflows.map(\.name)
    }
}
