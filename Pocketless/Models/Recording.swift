import Foundation
import SwiftData

@Model
final class Recording {
    var id: UUID
    var createdAt: Date
    var duration: TimeInterval
    /// Filename only (e.g. "recording_123.m4a") — resolved against Documents/Recordings/ at runtime
    var audioFileName: String

    @Relationship(deleteRule: .cascade, inverse: \Transcript.recordingAsRaw)
    var rawTranscript: Transcript?

    @Relationship(deleteRule: .cascade, inverse: \Transcript.recordingAsClean)
    var cleanTranscript: Transcript?

    @Relationship(deleteRule: .cascade, inverse: \Summary.recording)
    var summaries: [Summary]

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        duration: TimeInterval = 0,
        audioFileName: String,
        rawTranscript: Transcript? = nil,
        cleanTranscript: Transcript? = nil,
        summaries: [Summary] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.duration = duration
        self.audioFileName = audioFileName
        self.rawTranscript = rawTranscript
        self.cleanTranscript = cleanTranscript
        self.summaries = summaries
    }

    /// Resolved absolute URL to the audio file
    var audioFileURL: URL {
        Self.recordingsDirectory.appendingPathComponent(audioFileName)
    }

    static var recordingsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    var statusText: String {
        if summaries.isEmpty == false {
            return "Summarized"
        } else if cleanTranscript != nil {
            return "Cleaned"
        } else if rawTranscript != nil {
            return "Transcribed"
        } else {
            return "Recorded"
        }
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
