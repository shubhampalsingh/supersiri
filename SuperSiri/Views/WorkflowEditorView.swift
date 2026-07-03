import SwiftUI
import SwiftData

/// Create or edit a workflow and its ordered AI steps.
struct WorkflowEditorView: View {
    let workflow: Workflow?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var summary: String = ""
    @State private var steps: [WorkflowStep] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Workflow") {
                    TextField("Name", text: $name)
                    TextField("Description (optional)", text: $summary)
                }

                Section {
                    ForEach($steps) { $step in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Step name", text: $step.name)
                                .font(.headline)
                            Picker("Model", selection: $step.modelID) {
                                ForEach(AIModel.all) { model in
                                    Text(model.displayName).tag(model.id)
                                }
                            }
                            TextField("Prompt — use {{input}} and {{previous}}", text: $step.prompt, axis: .vertical)
                                .lineLimit(3...8)
                                .font(.callout)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { steps.remove(atOffsets: $0) }
                    .onMove { steps.move(fromOffsets: $0, toOffset: $1) }

                    Button {
                        steps.append(WorkflowStep(name: "Step \(steps.count + 1)", prompt: "{{previous}}"))
                    } label: {
                        Label("Add Step", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Steps")
                } footer: {
                    Text("Steps run in order. {{input}} is the text you give the workflow; {{previous}} is the output of the step before.")
                }
            }
            .navigationTitle(workflow == nil ? "New Workflow" : "Edit Workflow")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || steps.isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let workflow else {
            steps = [WorkflowStep(name: "Step 1", prompt: "{{input}}")]
            return
        }
        name = workflow.name
        summary = workflow.summary
        steps = workflow.steps
    }

    private func save() {
        if let workflow {
            workflow.name = name
            workflow.summary = summary
            workflow.steps = steps
        } else {
            let newWorkflow = Workflow(name: name, summary: summary, steps: steps)
            context.insert(newWorkflow)
        }
        try? context.save()
        dismiss()
    }
}
