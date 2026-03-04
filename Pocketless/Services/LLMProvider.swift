import Foundation

protocol LLMProvider {
    func chatCompletion(
        model: String,
        systemPrompt: String,
        userMessage: String,
        maxTokens: Int
    ) async throws -> String
}

extension LLMProvider {
    func chatCompletion(
        model: String,
        systemPrompt: String,
        userMessage: String
    ) async throws -> String {
        try await chatCompletion(model: model, systemPrompt: systemPrompt, userMessage: userMessage, maxTokens: 4096)
    }
}

extension OpenAICompatibleClient: LLMProvider {}
