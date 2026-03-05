import Foundation

protocol LLMProvider {
    func chatCompletion(
        model: String,
        systemPrompt: String,
        userMessage: String,
        maxTokens: Int,
        temperature: Double
    ) async throws -> String
}

extension LLMProvider {
    func chatCompletion(
        model: String,
        systemPrompt: String,
        userMessage: String,
        maxTokens: Int = 8192,
        temperature: Double = 0.3
    ) async throws -> String {
        try await chatCompletion(model: model, systemPrompt: systemPrompt, userMessage: userMessage, maxTokens: maxTokens, temperature: temperature)
    }
}

extension OpenAICompatibleClient: LLMProvider {}
