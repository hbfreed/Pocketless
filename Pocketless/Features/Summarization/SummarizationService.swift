import Foundation

final class SummarizationService {
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

        // Use preset's model on OpenRouter, otherwise fall back to configured model
        let model: String
        if config.providerType == .openRouter, let presetModel = preset.openRouterModel {
            model = presetModel
        } else {
            model = config.modelName
        }

        let content = try await provider.chatCompletion(
            model: model,
            systemPrompt: systemPrompt,
            userMessage: transcript.fullText,
            maxTokens: config.maxTokens,
            temperature: 0.3
        )

        return Summary(
            presetUsed: preset.rawValue,
            customPrompt: preset == .custom ? customPrompt : nil,
            modelUsed: model,
            content: content
        )
    }
}
