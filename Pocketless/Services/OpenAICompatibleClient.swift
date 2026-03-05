import Foundation

enum APIError: LocalizedError {
    case unauthorized
    case rateLimited
    case serverError(Int, String?)
    case decodingFailed(Error)
    case networkError(Error)
    case invalidURL
    case noContent

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Invalid API key. Check your key in Settings."
        case .rateLimited:
            return "Rate limited. Please wait and try again."
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message ?? "Unknown")"
        case .decodingFailed(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidURL:
            return "Invalid API URL."
        case .noContent:
            return "No content in response."
        }
    }
}

struct OpenAICompatibleClient {
    let baseURL: URL
    let apiKey: String

    // MARK: - Chat Completion

    func chatCompletion(
        model: String,
        systemPrompt: String,
        userMessage: String,
        maxTokens: Int = 8192,
        temperature: Double = 0.3
    ) async throws -> String {
        let url = baseURL.appendingPathComponent("chat/completions")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "temperature": temperature,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userMessage],
            ],
        ]

        let data = try await performRequest(url: url, body: body)

        struct ChatResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable {
                    let content: String?
                }
                let message: Message
            }
            let choices: [Choice]
        }

        do {
            let response = try JSONDecoder().decode(ChatResponse.self, from: data)
            guard let content = response.choices.first?.message.content else {
                throw APIError.noContent
            }
            return content
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.decodingFailed(error)
        }
    }

    // MARK: - Transcription

    struct TranscriptionResponse: Decodable {
        struct Segment: Decodable {
            let start: Double
            let end: Double
            let text: String
        }
        let text: String
        let segments: [Segment]?
    }

    func transcribe(
        model: String = "whisper-1",
        audioData: Data,
        language: String? = nil
    ) async throws -> TranscriptionResponse {
        let url = baseURL.appendingPathComponent("audio/transcriptions")

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        func appendField(name: String, value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        appendField(name: "model", value: model)
        appendField(name: "response_format", value: "verbose_json")

        if let language {
            appendField(name: "language", value: language)
        }

        // Audio file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/mp4\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            try validateHTTPResponse(response, data: data)
            return try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingFailed(error)
        } catch {
            throw APIError.networkError(error)
        }
    }

    // MARK: - Helpers

    private func performRequest(url: URL, body: [String: Any]) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            try validateHTTPResponse(response, data: data)
            return data
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }

    private func validateHTTPResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }

        switch httpResponse.statusCode {
        case 200..<300:
            return
        case 401:
            throw APIError.unauthorized
        case 429:
            throw APIError.rateLimited
        default:
            let message = String(data: data, encoding: .utf8)
            throw APIError.serverError(httpResponse.statusCode, message)
        }
    }
}

// MARK: - Config Types

struct STTConfig: Codable {
    enum Provider: String, Codable, CaseIterable {
        case onDevice
        case openaiCompatible
    }

    var provider: Provider = .onDevice
    var baseURL: String?
    var apiKeyKeychainKey: String?
    var modelName: String?

    static let keychainKey = "stt_api_key"

    var resolvedAPIKey: String? {
        guard let key = apiKeyKeychainKey else { return nil }
        return KeychainService.load(key: key)
    }
}

enum LLMProviderType: String, Codable, CaseIterable, Identifiable {
    case openRouter
    case openAI
    case anthropic
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openRouter: return "OpenRouter"
        case .openAI: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .custom: return "Custom"
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .openRouter: return "https://openrouter.ai/api/v1"
        case .openAI: return "https://api.openai.com/v1"
        case .anthropic: return "https://api.anthropic.com"
        case .custom: return ""
        }
    }

    var defaultModel: String {
        switch self {
        case .openRouter: return "google/gemini-3.1-flash-lite-preview"
        case .openAI: return "gpt-5.2-2025-12-11"
        case .anthropic: return "claude-sonnet-4-6-20260219"
        case .custom: return ""
        }
    }

    var keyURL: String? {
        switch self {
        case .openRouter: return "https://openrouter.ai/keys"
        case .openAI: return "https://platform.openai.com/api-keys"
        case .anthropic: return "https://console.anthropic.com/settings/keys"
        case .custom: return nil
        }
    }
}

struct LLMConfig: Codable {
    var providerType: LLMProviderType = .openRouter
    var baseURL: String = LLMProviderType.openRouter.defaultBaseURL
    var apiKeyKeychainKey: String = LLMConfig.keychainKey
    var modelName: String = "google/gemini-3.1-flash-lite-preview"
    var maxTokens: Int = 8192

    static let keychainKey = "llm_api_key"

    var resolvedAPIKey: String? {
        KeychainService.load(key: apiKeyKeychainKey)
    }

    func makeClient() -> OpenAICompatibleClient? {
        guard let url = URL(string: baseURL),
              let apiKey = resolvedAPIKey else { return nil }
        return OpenAICompatibleClient(baseURL: url, apiKey: apiKey)
    }

    func makeProvider() -> (any LLMProvider)? {
        guard let apiKey = resolvedAPIKey else { return nil }
        switch providerType {
        case .anthropic:
            guard let url = URL(string: baseURL) else { return nil }
            return AnthropicClient(baseURL: url, apiKey: apiKey)
        case .openRouter, .openAI, .custom:
            guard let url = URL(string: baseURL) else { return nil }
            return OpenAICompatibleClient(baseURL: url, apiKey: apiKey)
        }
    }
}
