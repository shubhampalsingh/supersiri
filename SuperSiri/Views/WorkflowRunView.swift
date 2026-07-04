import SwiftUI

/// Runs a workflow with live per-step progress, laid out as a timeline.
struct WorkflowRunView: View {
    let workflow: Workflow

    @StateObject private var engine = WorkflowEngine()
    @State private var input = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        ZStack {
            Theme.backdrop

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    if !engine.results.isEmpty {
                        timeline
                    }

                    if !engine.finalOutput.isEmpty {
                        resultActions
                    }
                }
                .padding()
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(workflow.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                IconTile(systemName: workflow.icon, size: 40)
                Text(workflow.summary.isEmpty ? "Give this workflow some text to work on." : workflow.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            TextField("Input for this workflow…", text: $input, axis: .vertical)
                .lineLimit(3...10)
                .padding(12)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                )
                .focused($inputFocused)

            HStack(spacing: 10) {
                Button {
                    inputFocused = false
                    engine.run(steps: workflow.steps, input: input)
                } label: {
                    Label(engine.isRunning ? "Running…" : "Run Workflow", systemImage: "play.fill")
                }
                .buttonStyle(EmberButtonStyle())
                .disabled(engine.isRunning || input.trimmingCharacters(in: .whitespaces).isEmpty)

                if engine.isRunning {
                    Button {
                        engine.cancel()
                    } label: {
                        Image(systemName: "stop.fill")
                            .padding(.vertical, 14)
                            .padding(.horizontal, 18)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .cardStyle()
    }

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(engine.results.enumerated()), id: \.element.id) { index, result in
                HStack(alignment: .top, spacing: 12) {
                    // Timeline rail
                    VStack(spacing: 0) {
                        stateIcon(result.state)
                            .frame(width: 26, height: 26)
                        if index < engine.results.count - 1 {
                            Rectangle()
                                .fill(Theme.hairline)
                                .frame(width: 2)
                                .frame(maxHeight: .infinity)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(result.stepName)
                                .font(Theme.display(15, weight: .semibold))
                            Spacer()
                            Text(result.modelName)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
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
                    .padding(.bottom, 20)
                }
            }
        }
        .cardStyle()
    }

    private var resultActions: some View {
        HStack(spacing: 10) {
            Button {
                UIPasteboard.general.string = engine.finalOutput
            } label: {
                Label("Copy Result", systemImage: "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            ShareLink(item: engine.finalOutput) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.bordered)
        .tint(Theme.ember)
    }

    @ViewBuilder
    private func stateIcon(_ state: WorkflowStepResult.State) -> some View {
        switch state {
        case .pending:
            Image(systemName: "circle.dotted")
                .foregroundStyle(.secondary)
        case .running:
            ProgressView()
                .controlSize(.small)
        case .finished:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.ember)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }
}
