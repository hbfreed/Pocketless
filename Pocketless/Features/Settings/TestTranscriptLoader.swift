#if DEBUG
import AVFoundation
import SwiftData
import Foundation

struct TestTranscriptLoader {

    // MARK: - Public

    @MainActor
    static func loadTestRecording(context: ModelContext) throws {
        let fileName = "test_transcript_\(UUID().uuidString.prefix(8)).m4a"
        let duration: TimeInterval = 210 // 3:30

        try generateSilentAudio(fileName: fileName, duration: duration)

        let recording = Recording(
            duration: duration,
            audioFileName: fileName
        )

        let transcript = Transcript(
            source: .onDevice,
            modelUsed: "test-data",
            segments: Self.testSegments
        )

        recording.rawTranscript = transcript
        context.insert(recording)
        try context.save()
    }

    // MARK: - Silent Audio Generation

    private static func generateSilentAudio(fileName: String, duration: TimeInterval) throws {
        let url = Recording.recordingsDirectory.appendingPathComponent(fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.low.rawValue
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        // Write a minimal silent file by creating an audio file directly
        recorder.prepareToRecord()

        // Use AVAudioEngine to render silence to file
        let engine = AVAudioEngine()
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let frameCount = AVAudioFrameCount(44100 * duration)

        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        // Buffer is zero-initialized = silence

        let file = try AVAudioFile(forWriting: url, settings: [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.low.rawValue
        ])
        try file.write(from: buffer)
        _ = engine // suppress unused warning
    }

    // MARK: - Test Transcript Data
    // ~45 segments, two speakers discussing a product launch, 0:00–3:30

    static let testSegments: [TranscriptSegment] = [
        seg(0, 4, "Alright, thanks for jumping on this call, Sarah. I wanted to sync up on the product launch timeline."),
        seg(4, 8, "Of course. I've been going through the checklist and I think we're in pretty good shape overall."),
        seg(8, 13, "Good to hear. Let's start with the engineering side. Where are we on the API integration?"),
        seg(14, 19, "So the core API is done. We finished the authentication flow last week and load testing passed."),
        seg(19, 24, "The remaining piece is the webhook system. We need about three more days to get that solid."),
        seg(25, 30, "Three days puts us at Thursday. That's cutting it close if we want to launch next Monday."),
        seg(30, 36, "I know, but I'd rather ship it stable than rush it. The webhooks are critical for enterprise customers."),
        seg(36, 41, "Agreed. What about the mobile SDK? Last I heard there were some issues with the iOS build."),
        seg(42, 48, "Yeah, we had a code signing issue that was blocking the TestFlight builds. That's been resolved now."),
        seg(48, 53, "The Android SDK has been ready for about a week. Both platforms are feature complete."),
        seg(54, 59, "Perfect. And the documentation? I noticed the API reference was still showing placeholder content."),
        seg(60, 66, "That's on my list for today actually. The auto-generated docs from the OpenAPI spec are ready."),
        seg(66, 72, "I just need to add the getting started guide and the migration docs for users coming from v1."),
        seg(73, 78, "Make sure to include code examples in at least Python, JavaScript, and curl. Those are the big three."),
        seg(78, 83, "Already done. I also added Go and Ruby examples since we've been getting requests for those."),
        seg(84, 89, "Nice. Okay, let's talk about the marketing side. Where are we with the launch blog post?"),
        seg(90, 96, "The draft is written. I sent it to the content team for review yesterday. Should have edits back by tomorrow."),
        seg(96, 102, "We're also preparing a technical deep dive post that explains the architecture behind the new features."),
        seg(103, 108, "I like that. Engineers love reading about how things work under the hood. Good for credibility too."),
        seg(108, 114, "Exactly. And we're planning a Twitter thread that breaks down the key improvements in bite-sized pieces."),
        seg(115, 120, "What about the pricing page? Have we finalized the tier structure?"),
        seg(120, 126, "Yes. Free tier stays the same, ten thousand API calls per month. Pro moves to fifty thousand."),
        seg(126, 132, "Enterprise is custom pricing as before, but we're adding a new Team tier at two hundred per month."),
        seg(133, 138, "The Team tier is interesting. What's the limit there?"),
        seg(138, 144, "Two hundred thousand calls per month, up to ten seats, and priority support with four hour response time."),
        seg(145, 150, "That fills a nice gap. A lot of mid-size companies told us Pro wasn't enough but Enterprise was overkill."),
        seg(150, 156, "That was exactly the feedback we got from the beta program. About sixty percent of beta users said they'd pick Team."),
        seg(157, 162, "Speaking of beta users, how has the feedback been on the new features?"),
        seg(162, 168, "Overwhelmingly positive. The real-time streaming endpoint is the most requested feature we've ever shipped."),
        seg(168, 174, "Latency is down to under fifty milliseconds p99, which is a huge improvement over the polling approach."),
        seg(175, 180, "Any concerns or negative feedback we should address before launch?"),
        seg(180, 186, "Two things. First, some users want batch processing support. That's on the roadmap for v2.1."),
        seg(187, 192, "Second, the rate limiting error messages could be more descriptive. Easy fix, I'll push that today."),
        seg(192, 198, "Good. Better error messages make a huge difference in developer experience. Don't underestimate that."),
        seg(199, 204, "Totally agree. Oh, one more thing. We need to update the status page to reflect the new endpoints."),
        seg(204, 210, "Right. And make sure the uptime SLA language covers the streaming connections, not just REST calls."),
        seg(210, 216, "I'll loop in legal on that. The current SLA was written before we had persistent connections."),
        seg(217, 222, "Okay let's talk about the launch day plan. Walk me through the sequence."),
        seg(222, 228, "So we flip the feature flags at six AM Pacific. That gives us the full US business day for monitoring."),
        seg(228, 234, "Blog post goes live at seven AM. Social media posts start rolling out at seven thirty."),
        seg(234, 240, "Email to existing users goes out at eight AM. We stagger it over two hours to avoid overwhelming support."),
        seg(240, 246, "Product Hunt submission goes up at midnight the night before, so it catches the morning crowd."),
        seg(247, 252, "What's our rollback plan if something goes wrong?"),
        seg(252, 258, "Feature flags can be killed in under thirty seconds. The old API stays running in parallel for forty-eight hours."),
        seg(258, 264, "If we need to roll back, users won't even notice. They'll just get routed to the v1 endpoints transparently."),
        seg(265, 270, "That's solid. Alright, I think we're in great shape. Let's reconvene Wednesday for a final go or no-go."),
        seg(270, 276, "Sounds good. I'll have the webhook system done and docs polished by then. Talk to you Wednesday."),
    ]

    private static func seg(_ start: TimeInterval, _ end: TimeInterval, _ text: String) -> TranscriptSegment {
        TranscriptSegment(startTime: start, endTime: end, text: text)
    }
}
#endif
