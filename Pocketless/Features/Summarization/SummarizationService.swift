import Foundation

final class SummarizationService {
    private static let rules = """
    Rules:
    - Use only information present in the transcript. Do not infer or fabricate.
    - If speaker labels are available, attribute statements to speakers.
    - Flag anything that seems ambiguous or unclear in the transcript.
    - Use the user's language (match the transcript language).
    """

    func summarize(
        transcript: Transcript,
        preset: SummaryPreset,
        customPrompt: String? = nil
    ) async throws -> Summary {
        let configData = UserDefaults.standard.data(forKey: "llmConfig")
        let config = configData.flatMap { try? JSONDecoder().decode(LLMConfig.self, from: $0) } ?? LLMConfig()

        guard let provider = config.makeProvider() else {
            throw APIError.unauthorized
        }

        let systemPrompt: String
        if preset == .custom, let custom = customPrompt, !custom.isEmpty {
            systemPrompt = custom
        } else {
            systemPrompt = preset.systemPrompt
        }

        let fullPrompt = """
        \(systemPrompt)

        \(Self.rules)

        Transcript:
        ---
        \(transcript.fullText)
        ---
        """

        let content = try await provider.chatCompletion(
            model: config.modelName,
            systemPrompt: fullPrompt,
            userMessage: "Please summarize the transcript above.",
            maxTokens: config.maxTokens
        )

        return Summary(
            presetUsed: preset.rawValue,
            customPrompt: preset == .custom ? customPrompt : nil,
            modelUsed: config.modelName,
            content: content
        )
    }
}
