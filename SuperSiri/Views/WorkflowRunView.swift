import SwiftUI

/// Runs a workflow with live per-step progress.
struct WorkflowRunView: View {
    let workflow: Workflow

    @StateObject private var engine = WorkflowEngine()
    @State private var input = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(workflow.summary.isEmpty ? "Give this workflow some text to work on." : workflow.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextField("Input for this workflow…", text: $input, axis: .vertical)
                        .lineLimit(3...10)
                        .padding(10)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .focused($inputFocused)

                    HStack {
                        Button {
                            inputFocused = false
                            engine.run(steps: workflow.steps, input: input)
                        } label: {
                            Label(engine.isRunning ? "Running…" : "Run Workflow", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                        .disabled(engine.isRunning || input.trimmingCharacters(in: .whitespaces).isEmpty)

                        if engine.isRunning {
                            Button(role: .cancel) {
                                engine.cancel()
                            } label: {
                                Image(systemName: "stop.fill")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                ForEach(engine.results) { result in
                    stepCard(result)
                }

                if !engine.finalOutput.isEmpty {
                    HStack(spacing: 16) {
                        Button {
                            UIPasteboard.general.string = engine.finalOutput
                        } label: {
                            Label("Copy Result", systemImage: "doc.on.doc")
                        }
                        ShareLink(item: engine.finalOutput) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .navigationTitle(workflow.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func stepCard(_ result: WorkflowStepResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                stateIcon(result.state)
                Text(result.stepName).font(.headline)
                Spacer()
                Text(result.modelName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if !result.output.isEmpty {
                Text(LocalizedStringKey(result.output))
                    .font(.callout)
                    .textSelection(.enabled)
            }
            if case .failed(let message) = result.state {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func stateIcon(_ state: WorkflowStepResult.State) -> some View {
        switch state {
        case .pending:
            Image(systemName: "circle.dotted").foregroundStyle(.secondary)
        case .running:
            ProgressView().controlSize(.small)
        case .finished:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        }
    }
}
