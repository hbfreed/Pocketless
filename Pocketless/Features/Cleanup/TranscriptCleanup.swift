import Foundation

final class TranscriptCleanup {
    private let chunkWordLimit = 3000

    func cleanup(transcript: Transcript) async throws -> Transcript {
        let configData = UserDefaults.standard.data(forKey: "llmConfig")
        let config = configData.flatMap { try? JSONDecoder().decode(LLMConfig.self, from: $0) } ?? LLMConfig()

        guard let client = config.makeClient() else {
            throw APIError.unauthorized
        }

        let fullText = transcript.fullText
        let chunks = splitIntoChunks(text: fullText, wordLimit: chunkWordLimit)
        var cleanedParts: [String] = []

        for chunk in chunks {
            let cleaned = try await client.chatCompletion(
                model: config.modelName,
                systemPrompt: CleanupPrompt.systemPrompt,
                userMessage: chunk
            )
            cleanedParts.append(cleaned)
        }

        let cleanedText = cleanedParts.joined(separator: " ")
        let segment = TranscriptSegment(
            startTime: transcript.segments.first?.startTime ?? 0,
            endTime: transcript.segments.last?.endTime ?? 0,
            text: cleanedText
        )

        return Transcript(
            source: transcript.source,
            modelUsed: transcript.modelUsed,
            isCleanedUp: true,
            segments: [segment]
        )
    }

    private func splitIntoChunks(text: String, wordLimit: Int) -> [String] {
        let words = text.split(separator: " ")
        if words.count <= wordLimit {
            return [text]
        }

        var chunks: [String] = []
        var currentChunk: [Substring] = []

        for word in words {
            currentChunk.append(word)
            if currentChunk.count >= wordLimit {
                // Try to split on sentence boundary
                let chunkText = currentChunk.joined(separator: " ")
                if let lastPeriod = chunkText.lastIndex(of: ".") {
                    let splitIndex = chunkText.index(after: lastPeriod)
                    chunks.append(String(chunkText[chunkText.startIndex..<splitIndex]))
                    let remainder = String(chunkText[splitIndex...]).trimmingCharacters(in: .whitespaces)
                    currentChunk = remainder.split(separator: " ")
                } else {
                    chunks.append(chunkText)
                    currentChunk = []
                }
            }
        }

        if !currentChunk.isEmpty {
            chunks.append(currentChunk.joined(separator: " "))
        }

        return chunks
    }
}
