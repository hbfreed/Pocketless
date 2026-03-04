import AVFoundation
import Foundation
import WhisperKit

final class WhisperKitService: TranscriptionService {
    private var whisperKit: WhisperKit?

    func transcribe(audioURL: URL) async throws -> Transcript {
        if whisperKit == nil {
            let config = WhisperKitConfig(model: "openai_whisper-large-v3-v20240930_turbo")
            whisperKit = try await WhisperKit(config)
        }

        guard let whisperKit else {
            throw TranscriptionError.modelNotLoaded
        }

        // Get actual audio duration to filter out hallucinated segments
        let asset = AVURLAsset(url: audioURL)
        let audioDuration = try await asset.load(.duration).seconds

        let options = DecodingOptions(wordTimestamps: true)
        let results: [TranscriptionResult] = try await whisperKit.transcribe(
            audioPath: audioURL.path(),
            decodeOptions: options
        )

        // Build sentence-level segments from word timestamps when available
        var segments: [TranscriptSegment] = []
        for result in results {
            for segment in result.segments {
                if let words = segment.words, !words.isEmpty {
                    // Filter words that start beyond actual audio duration
                    let validWords = words.filter { TimeInterval($0.start) <= audioDuration + 1 }
                    guard !validWords.isEmpty else { continue }
                    segments.append(contentsOf: Self.sentenceSegments(from: validWords))
                } else {
                    guard TimeInterval(segment.start) <= audioDuration + 1 else { continue }
                    let cleaned = Self.stripSpecialTokens(segment.text)
                        .trimmingCharacters(in: .whitespaces)
                    guard !cleaned.isEmpty else { continue }
                    segments.append(TranscriptSegment(
                        startTime: TimeInterval(segment.start),
                        endTime: TimeInterval(segment.end),
                        text: cleaned
                    ))
                }
            }
        }

        return Transcript(
            source: .onDevice,
            modelUsed: "whisper-large-v3-v20240930-turbo",
            segments: segments
        )
    }

    /// Groups word timings into sentence-level segments by splitting on sentence-ending punctuation
    private static func sentenceSegments(from words: [WordTiming]) -> [TranscriptSegment] {
        var segments: [TranscriptSegment] = []
        var currentWords: [WordTiming] = []

        for word in words {
            currentWords.append(word)
            let trimmed = word.word.trimmingCharacters(in: .whitespaces)
            if trimmed.hasSuffix(".") || trimmed.hasSuffix("!") || trimmed.hasSuffix("?") {
                let text = currentWords.map(\.word).joined()
                    .trimmingCharacters(in: .whitespaces)
                let cleaned = stripSpecialTokens(text).trimmingCharacters(in: .whitespaces)
                if !cleaned.isEmpty {
                    segments.append(TranscriptSegment(
                        startTime: TimeInterval(currentWords.first!.start),
                        endTime: TimeInterval(currentWords.last!.end),
                        text: cleaned
                    ))
                }
                currentWords = []
            }
        }

        // Remaining words that didn't end with punctuation
        if !currentWords.isEmpty {
            let text = currentWords.map(\.word).joined()
                .trimmingCharacters(in: .whitespaces)
            let cleaned = stripSpecialTokens(text).trimmingCharacters(in: .whitespaces)
            if !cleaned.isEmpty {
                segments.append(TranscriptSegment(
                    startTime: TimeInterval(currentWords.first!.start),
                    endTime: TimeInterval(currentWords.last!.end),
                    text: cleaned
                ))
            }
        }

        return segments
    }

    private static func stripSpecialTokens(_ text: String) -> String {
        // Remove Whisper special tokens like <|startoftranscript|>, <|en|>, <|0.00|>, <|endoftext|>, etc.
        text.replacingOccurrences(
            of: #"<\|[^|]*\|>"#,
            with: "",
            options: .regularExpression
        )
    }
}

enum TranscriptionError: LocalizedError {
    case modelNotLoaded
    case audioFileNotFound
    case noTranscriptionResult

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Failed to load the transcription model."
        case .audioFileNotFound:
            return "Audio file not found."
        case .noTranscriptionResult:
            return "No transcription result was returned."
        }
    }
}
