import Foundation

final class CloudSTTService: TranscriptionService {
    private let config: STTConfig

    init(config: STTConfig) {
        self.config = config
    }

    func transcribe(audioURL: URL) async throws -> Transcript {
        guard let baseURLString = config.baseURL,
              let baseURL = URL(string: baseURLString),
              let apiKey = config.resolvedAPIKey else {
            throw APIError.unauthorized
        }

        let client = OpenAICompatibleClient(baseURL: baseURL, apiKey: apiKey)
        let audioData = try Data(contentsOf: audioURL)

        let response = try await client.transcribe(
            model: config.modelName ?? "whisper-1",
            audioData: audioData
        )

        let segments: [TranscriptSegment]
        if let responseSegments = response.segments {
            segments = responseSegments.map { segment in
                TranscriptSegment(
                    startTime: segment.start,
                    endTime: segment.end,
                    text: segment.text.trimmingCharacters(in: .whitespaces)
                )
            }
        } else {
            segments = [TranscriptSegment(startTime: 0, endTime: 0, text: response.text)]
        }

        return Transcript(
            source: .cloud,
            modelUsed: config.modelName ?? "whisper-1",
            segments: segments
        )
    }
}
