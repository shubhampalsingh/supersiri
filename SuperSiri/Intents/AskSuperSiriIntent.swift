import AppIntents
import Foundation

/// "Hey Siri, ask SuperSiri ..." — one-shot question answered by the best
/// available model, usable from Siri, Spotlight, and the Shortcuts app.
struct AskSuperSiriIntent: AppIntent {
    static var title: LocalizedStringResource = "Ask SuperSiri"
    static var description = IntentDescription(
        "Ask SuperSiri anything and get an AI answer back.",
        categoryName: "AI"
    )

    @Parameter(title: "Question", requestValueDialog: "What would you like to ask?")
    var prompt: String

    static var parameterSummary: some ParameterSummary {
        Summary("Ask SuperSiri \(\.$prompt)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let router = AIRouter.shared
        let model = router.autoPick(for: prompt)
        let answer = try await router.complete(
            model: model,
            system: SuperSiriPersona.systemPrompt + "\nYou are answering via Siri: keep it under 80 words unless asked for detail.",
            turns: [AITurn(role: .user, text: prompt)]
        )
        return .result(value: answer, dialog: IntentDialog(stringLiteral: answer))
    }
}
