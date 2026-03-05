import Foundation

final class TranscriptCleanup {
    private let chunkWordLimit = 3000
    private let overlapSentenceCount = 5

    func cleanup(transcript: Transcript) async throws -> Transcript {
        let configData = UserDefaults.standard.data(forKey: "llmConfig")
        let config = configData.flatMap { try? JSONDecoder().decode(LLMConfig.self, from: $0) } ?? LLMConfig()

        guard let provider = config.makeProvider() else {
            throw APIError.unauthorized
        }

        let fullText = transcript.fullText
        let chunks = splitIntoChunks(text: fullText, wordLimit: chunkWordLimit)
        var cleanedParts: [String] = []
        var previousContext: String? = nil

        for chunk in chunks {
            let userMessage: String
            if let context = previousContext {
                userMessage = "PREVIOUS CONTEXT (do not include in output):\n\(context)\n\nCURRENT CHUNK:\n\(chunk)"
            } else {
                userMessage = chunk
            }

            let cleaned = try await provider.chatCompletion(
                model: config.modelName,
                systemPrompt: CleanupPrompt.systemPrompt,
                userMessage: userMessage,
                maxTokens: 8192,
                temperature: 0.3
            )
            cleanedParts.append(cleaned)

            // Save last ~5 sentences as context for the next chunk
            previousContext = lastSentences(from: cleaned, count: overlapSentenceCount)
        }

        let cleanedText = cleanedParts.joined(separator: "\n\n")
        let segments = parseSegments(from: cleanedText, fallbackEnd: transcript.segments.last?.endTime ?? 0)

        return Transcript(
            source: transcript.source,
            modelUsed: transcript.modelUsed,
            isCleanedUp: true,
            segments: segments
        )
    }

    /// Parse "Speaker N [HH:MM:SS]: text" lines into TranscriptSegments
    private func parseSegments(from text: String, fallbackEnd: TimeInterval) -> [TranscriptSegment] {
        // Pattern: Speaker 1 [00:01:23]: some text...
        let pattern = #"(Speaker \d+)\s*\[(\d{1,2}):(\d{2}):(\d{2})\]:\s*"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [TranscriptSegment(startTime: 0, endTime: fallbackEnd, text: text)]
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        if matches.isEmpty {
            return [TranscriptSegment(startTime: 0, endTime: fallbackEnd, text: text)]
        }

        var segments: [TranscriptSegment] = []

        for (i, match) in matches.enumerated() {
            let speaker = nsText.substring(with: match.range(at: 1))
            let hours = Int(nsText.substring(with: match.range(at: 2))) ?? 0
            let minutes = Int(nsText.substring(with: match.range(at: 3))) ?? 0
            let seconds = Int(nsText.substring(with: match.range(at: 4))) ?? 0
            let startTime = TimeInterval(hours * 3600 + minutes * 60 + seconds)

            let textStart = match.range.location + match.range.length
            let textEnd: Int
            if i + 1 < matches.count {
                textEnd = matches[i + 1].range.location
            } else {
                textEnd = nsText.length
            }

            let segmentText = nsText.substring(with: NSRange(location: textStart, length: textEnd - textStart))
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let endTime: TimeInterval
            if i + 1 < matches.count {
                let nextHours = Int(nsText.substring(with: matches[i + 1].range(at: 2))) ?? 0
                let nextMinutes = Int(nsText.substring(with: matches[i + 1].range(at: 3))) ?? 0
                let nextSeconds = Int(nsText.substring(with: matches[i + 1].range(at: 4))) ?? 0
                endTime = TimeInterval(nextHours * 3600 + nextMinutes * 60 + nextSeconds)
            } else {
                endTime = fallbackEnd
            }

            segments.append(TranscriptSegment(
                startTime: startTime,
                endTime: endTime,
                text: "\(speaker): \(segmentText)",
                speaker: speaker
            ))
        }

        return segments
    }

    private func lastSentences(from text: String, count: Int) -> String {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let slice = sentences.suffix(count)
        return slice.joined(separator: ". ") + "."
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
