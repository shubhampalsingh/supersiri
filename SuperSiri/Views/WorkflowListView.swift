import SwiftUI
import SwiftData

struct WorkflowListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Workflow.createdAt) private var workflows: [Workflow]
    @State private var editingWorkflow: Workflow?
    @State private var showingNewWorkflow = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backdrop

                if workflows.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(workflows) { workflow in
                                NavigationLink(value: workflow) {
                                    workflowRow(workflow)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button {
                                        editingWorkflow = workflow
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        context.delete(workflow)
                                        try? context.save()
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }

                            Text("Run any workflow from Siri — \"Run a SuperSiri workflow\" — or the Shortcuts app. Long-press a card to edit.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.top, 12)
                                .padding(.horizontal, 24)
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 80)
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
                            .fontWeight(.semibold)
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

    private var emptyState: some View {
        VStack(spacing: 20) {
            IconTile(systemName: "bolt.fill", size: 84)

            VStack(spacing: 6) {
                Text("Automate anything")
                    .font(Theme.display(26))
                Text("Chain AI steps together — summarize, then draft;\ncritique, then plan. Each step can use a different model.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showingNewWorkflow = true
            } label: {
                Label("New workflow", systemImage: "plus")
            }
            .buttonStyle(EmberButtonStyle())
            .padding(.horizontal, 48)
        }
        .padding()
    }

    private func workflowRow(_ workflow: Workflow) -> some View {
        HStack(spacing: 14) {
            IconTile(systemName: workflow.icon)

            VStack(alignment: .leading, spacing: 3) {
                Text(workflow.name)
                    .font(Theme.display(16, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(workflow.summary.isEmpty ? "\(workflow.steps.count) steps" : workflow.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            HStack(spacing: 3) {
                Text("\(workflow.steps.count)")
                    .font(Theme.display(14, weight: .semibold))
                Image(systemName: "bolt.fill")
                    .font(.caption2)
            }
            .foregroundStyle(Theme.ember)
        }
        .cardStyle()
    }
}
