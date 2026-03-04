import Foundation
import SwiftData

enum TranscriptSource: String, Codable {
    case onDevice
    case cloud
}

struct TranscriptSegment: Codable, Identifiable {
    var id: UUID = UUID()
    var startTime: TimeInterval
    var endTime: TimeInterval
    var text: String
    var speaker: String?
}

@Model
final class Transcript {
    var id: UUID
    var createdAt: Date
    var source: TranscriptSource
    var modelUsed: String
    var isCleanedUp: Bool
    var segmentsData: Data

    var recordingAsRaw: Recording?
    var recordingAsClean: Recording?

    var segments: [TranscriptSegment] {
        get {
            (try? JSONDecoder().decode([TranscriptSegment].self, from: segmentsData)) ?? []
        }
        set {
            segmentsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    var fullText: String {
        segments.map(\.text).joined(separator: " ")
    }

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        source: TranscriptSource,
        modelUsed: String,
        isCleanedUp: Bool = false,
        segments: [TranscriptSegment] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.source = source
        self.modelUsed = modelUsed
        self.isCleanedUp = isCleanedUp
        self.segmentsData = (try? JSONEncoder().encode(segments)) ?? Data()
    }
}
