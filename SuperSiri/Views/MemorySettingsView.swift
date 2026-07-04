import SwiftUI

/// Review and delete what SuperSiri remembers about you.
struct MemorySettingsView: View {
    @ObservedObject private var memory = MemoryStore.shared
    @State private var newFact = ""

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("Add something to remember…", text: $newFact)
                    Button {
                        memory.add(newFact)
                        newFact = ""
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(newFact.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } footer: {
                Text("SuperSiri also saves facts on its own when you tell it something worth remembering (with Superpowers enabled).")
            }

            Section("Memories") {
                if memory.facts.isEmpty {
                    Text("Nothing remembered yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(memory.facts) { fact in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(fact.text)
                            Text(fact.createdAt, style: .date)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            memory.delete(memory.facts[index])
                        }
                    }
                }
            }

            if !memory.facts.isEmpty {
                Section {
                    Button("Forget Everything", role: .destructive) {
                        memory.deleteAll()
                    }
                }
            }
        }
        .navigationTitle("Memory")
    }
}
