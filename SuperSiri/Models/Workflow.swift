import Foundation
import SwiftData

/// A user-defined automation: an ordered chain of AI steps.
/// Each step's prompt can reference `{{input}}` (the workflow's input)
/// and `{{previous}}` (the previous step's output).
@Model
final class Workflow {
    var name: String
    var summary: String
    var icon: String // SF Symbol name
    var createdAt: Date
    var stepsData: Data // encoded [WorkflowStep]

    init(name: String, summary: String = "", icon: String = "bolt.fill", steps: [WorkflowStep] = []) {
        self.name = name
        self.summary = summary
        self.icon = icon
        self.createdAt = .now
        self.stepsData = (try? JSONEncoder().encode(steps)) ?? Data()
    }

    var steps: [WorkflowStep] {
        get { (try? JSONDecoder().decode([WorkflowStep].self, from: stepsData)) ?? [] }
        set { stepsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
}

struct WorkflowStep: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    /// Prompt template. Supports {{input}} and {{previous}} placeholders.
    var prompt: String
    var modelID: String

    init(id: UUID = UUID(), name: String, prompt: String, modelID: String = AIModel.default.id) {
        self.id = id
        self.name = name
        self.prompt = prompt
        self.modelID = modelID
    }

    var model: AIModel {
        AIModel.model(withID: modelID) ?? .default
    }
}

extension Workflow {
    /// Starter workflows seeded on first launch so the app is useful immediately.
    static func starterWorkflows() -> [Workflow] {
        [
            Workflow(
                name: "Summarize & Reply",
                summary: "Summarizes any text, then drafts a polished reply.",
                icon: "envelope.fill",
                steps: [
                    WorkflowStep(
                        name: "Summarize",
                        prompt: "Summarize the following message in 3 bullet points, capturing tone and any asks:\n\n{{input}}",
                        modelID: AIModel.claudeHaiku.id
                    ),
                    WorkflowStep(
                        name: "Draft reply",
                        prompt: "Using this summary of a message I received:\n\n{{previous}}\n\nDraft a friendly, professional reply on my behalf. Keep it under 150 words.",
                        modelID: AIModel.claudeOpus.id
                    ),
                ]
            ),
            Workflow(
                name: "Daily Briefing",
                summary: "Turns your raw notes into a prioritized plan for the day.",
                icon: "sun.max.fill",
                steps: [
                    WorkflowStep(
                        name: "Organize",
                        prompt: "Here are my raw notes and tasks for today:\n\n{{input}}\n\nGroup them into themes and flag anything time-sensitive.",
                        modelID: AIModel.claudeSonnet.id
                    ),
                    WorkflowStep(
                        name: "Prioritize",
                        prompt: "Turn this organized list into a prioritized day plan with a top-3 focus section and time estimates:\n\n{{previous}}",
                        modelID: AIModel.claudeOpus.id
                    ),
                ]
            ),
            Workflow(
                name: "Idea → Action Plan",
                summary: "Stress-tests an idea, then produces a concrete next-steps plan.",
                icon: "lightbulb.fill",
                steps: [
                    WorkflowStep(
                        name: "Critique",
                        prompt: "Critique this idea honestly. List the 3 biggest risks and 3 strongest points:\n\n{{input}}",
                        modelID: AIModel.claudeOpus.id
                    ),
                    WorkflowStep(
                        name: "Plan",
                        prompt: "Given the original idea:\n\n{{input}}\n\nand this critique:\n\n{{previous}}\n\nWrite a concrete 5-step action plan that addresses the risks.",
                        modelID: AIModel.claudeOpus.id
                    ),
                ]
            ),
        ]
    }
}
