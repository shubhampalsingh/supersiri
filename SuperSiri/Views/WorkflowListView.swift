import SwiftUI
import SwiftData

struct WorkflowListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Workflow.createdAt) private var workflows: [Workflow]
    @State private var editingWorkflow: Workflow?
    @State private var showingNewWorkflow = false

    var body: some View {
        NavigationStack {
            Group {
                if workflows.isEmpty {
                    ContentUnavailableView(
                        "No workflows",
                        systemImage: "bolt.fill",
                        description: Text("Workflows chain AI steps together to automate repetitive tasks. Create one to get started.")
                    )
                } else {
                    List {
                        Section {
                            ForEach(workflows) { workflow in
                                NavigationLink(value: workflow) {
                                    HStack(spacing: 12) {
                                        Image(systemName: workflow.icon)
                                            .font(.title3)
                                            .foregroundStyle(.purple)
                                            .frame(width: 32)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(workflow.name).font(.headline)
                                            Text(workflow.summary.isEmpty ? "\(workflow.steps.count) steps" : workflow.summary)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                                .swipeActions {
                                    Button(role: .destructive) {
                                        context.delete(workflow)
                                        try? context.save()
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    Button {
                                        editingWorkflow = workflow
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.orange)
                                }
                            }
                        } footer: {
                            Text("Tip: run any workflow from Siri — \"Run a SuperSiri workflow\" — or from the Shortcuts app.")
                        }
                    }
                }
            }
            .navigationTitle("Workflows")
            .navigationDestination(for: Workflow.self) { workflow in
                WorkflowRunView(workflow: workflow)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewWorkflow = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewWorkflow) {
                WorkflowEditorView(workflow: nil)
            }
            .sheet(item: $editingWorkflow) { workflow in
                WorkflowEditorView(workflow: workflow)
            }
        }
    }
}
