import SwiftUI
import SwiftData

@main
struct SuperSiriApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(PersistenceController.sharedContainer)
    }
}

/// Single SwiftData container shared by the app UI and App Intents
/// (Siri/Shortcuts run intents in-process and need the same store).
enum PersistenceController {
    static let sharedContainer: ModelContainer = {
        let schema = Schema([Conversation.self, ChatMessage.self, Workflow.self])
        let configuration = ModelConfiguration(schema: schema)
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            seedStarterWorkflowsIfNeeded(in: container)
            return container
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }
    }()

    private static func seedStarterWorkflowsIfNeeded(in container: ModelContainer) {
        let context = ModelContext(container)
        let existing = (try? context.fetchCount(FetchDescriptor<Workflow>())) ?? 0
        guard existing == 0 else { return }
        for workflow in Workflow.starterWorkflows() {
            context.insert(workflow)
        }
        try? context.save()
    }
}
