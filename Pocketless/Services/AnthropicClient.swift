import Foundation

struct AnthropicClient: LLMProvider {
    let baseURL: URL
    let apiKey: String

    func chatCompletion(
        model: String,
        systemPrompt: String,
        userMessage: String,
        maxTokens: Int
    ) async throws -> String {
        let url = baseURL.appendingPathComponent("v1/messages")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": userMessage],
            ],
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            try validateHTTPResponse(response, data: responseData)
            data = responseData
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }

        struct MessagesResponse: Decodable {
            struct ContentBlock: Decodable {
                let type: String
                let text: String?
            }
            let content: [ContentBlock]
        }

        do {
            let response = try JSONDecoder().decode(MessagesResponse.self, from: data)
            guard let text = response.content.first(where: { $0.type == "text" })?.text else {
                throw APIError.noContent
            }
            return text
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.decodingFailed(error)
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
