import SwiftUI

/// Toolbar menu for switching the AI model behind a conversation.
struct ModelPickerView: View {
    @Binding var selectedModelID: String

    var body: some View {
        Menu {
            ForEach(AIProvider.allCases) { provider in
                Section(provider.displayName) {
                    ForEach(AIModel.all.filter { $0.provider == provider }) { model in
                        Button {
                            selectedModelID = model.id
                        } label: {
                            if model.id == selectedModelID {
                                Label(model.displayName, systemImage: "checkmark")
                            } else {
                                Text(model.displayName)
                            }
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "cpu")
        }
    }
}
