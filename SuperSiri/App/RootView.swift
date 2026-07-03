import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            ConversationListView()
                .tabItem {
                    Label("Chats", systemImage: "bubble.left.and.bubble.right.fill")
                }

            WorkflowListView()
                .tabItem {
                    Label("Workflows", systemImage: "bolt.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(.purple)
    }
}

#Preview {
    RootView()
        .modelContainer(PersistenceController.sharedContainer)
}
