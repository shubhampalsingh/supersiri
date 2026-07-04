import AppIntents

/// Registers zero-setup Siri phrases so the app's AI is reachable by voice
/// immediately after install.
struct SuperSiriShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AskSuperSiriIntent(),
            phrases: [
                "Ask \(.applicationName)",
                "Ask \(.applicationName) a question",
                "Hey \(.applicationName)",
            ],
            shortTitle: "Ask SuperSiri",
            systemImageName: "sparkles"
        )
        AppShortcut(
            intent: RunWorkflowIntent(),
            phrases: [
                "Run a \(.applicationName) workflow",
                "Run my \(.applicationName) automation",
            ],
            shortTitle: "Run Workflow",
            systemImageName: "bolt.fill"
        )
    }
}
