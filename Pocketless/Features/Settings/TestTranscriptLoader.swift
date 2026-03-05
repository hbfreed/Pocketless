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
    // Raw-sounding Whisper output — lots of filler, false starts, bad punctuation.
    // Two friends catching up over coffee, ~3:30. Good for demoing raw vs cleaned.

    static let testSegments: [TranscriptSegment] = [
        seg(0, 5, "oh man so yeah I haven't seen you in like what has it been like three months or something"),
        seg(5, 9, "yeah yeah it's been it's been a while I think the last time was uh was it that dinner at Marcus's place"),
        seg(9, 14, "right right yeah that was that was a good time actually um so what have you been up to"),
        seg(14, 20, "so okay so the big thing is I uh I actually quit my job at Stripe like two weeks ago"),
        seg(20, 24, "wait what no way you you quit Stripe I thought you loved it there"),
        seg(24, 31, "I mean I did I did for a while but like the the thing is I'd been there for almost four years and I just felt like I was kind of like"),
        seg(31, 36, "you know just like going through the motions you know what I mean like the the work was fine but"),
        seg(36, 42, "I wasn't I wasn't really learning anything new and like the the team had gotten so big that like everything took forever"),
        seg(42, 47, "yeah no I I totally get that actually um so are you are you doing the startup thing then or"),
        seg(47, 53, "yeah so that's the that's the exciting part um so my buddy Jake from from college you remember Jake right"),
        seg(53, 56, "uh Jake the tall guy who was always talking about like crypto and stuff"),
        seg(56, 62, "no no no that's that's Tyler this is Jake he was in our uh our econ class he was the one who built that like"),
        seg(62, 67, "oh wait the the guy who built the like meal planning app thing that actually kind of blew up"),
        seg(67, 73, "yes yes exactly that guy so him and I have been like talking for like six months about this idea and we finally just said like screw it let's do it"),
        seg(73, 79, "okay okay so what's the what's the idea like give me give me the pitch"),
        seg(79, 86, "so basically it's um it's like a it's a tool for like small restaurants to manage their their whole like back of house operations"),
        seg(86, 93, "so like inventory ordering staff scheduling uh like food cost tracking all in one place because right now they're using like five different apps"),
        seg(93, 99, "huh that's actually that's actually really interesting because like my my sister she runs that that cafe in Portland"),
        seg(99, 105, "and she's always complaining about how like she has one app for scheduling and then a spreadsheet for inventory and then like"),
        seg(105, 109, "exactly exactly that's that's literally the problem like we've talked to like thirty restaurant owners"),
        seg(109, 115, "and every single one of them is like yeah I spend like two hours a day just like bouncing between different tools and spreadsheets"),
        seg(115, 121, "so are you guys like are you bootstrapping this or did you like raise money or how does that work"),
        seg(121, 128, "so we we did a um we did a small pre-seed round uh we raised like five fifty K from from a couple angels and then YC"),
        seg(128, 132, "wait you got into Y Combinator are you serious"),
        seg(132, 138, "yeah yeah we we got in for the uh the winter batch which starts in like in January so we've got like two months to like really get the MVP solid"),
        seg(138, 144, "dude that's that's incredible congratulations I mean that's like that's a huge deal um so are you are you moving to SF then"),
        seg(144, 150, "yeah so that's the other big thing um we're we're moving down there in in December so Sarah and I are like"),
        seg(150, 155, "packing up the apartment right now which is like a whole thing because you know we've been in that place for like three years"),
        seg(155, 161, "oh man yeah moving is the worst um but San Francisco though that's gonna be that's gonna be really cool actually"),
        seg(161, 167, "yeah I'm I'm excited about it I mean the the cost of living is like insane obviously but like the the network effect of being there"),
        seg(167, 172, "like especially during YC is just it's like you can't you can't replicate that anywhere else"),
        seg(172, 178, "totally totally um so what's the what's the tech stack like what are you guys building it in"),
        seg(178, 184, "so the the backend is uh is like a pretty standard like Node TypeScript setup with with Postgres"),
        seg(184, 190, "and then the the frontend we're doing React Native because like the restaurant managers they need a mobile app like that's the whole point"),
        seg(190, 196, "they're they're walking around the kitchen they're not sitting at a at a desktop you know so mobile first was was kind of a no-brainer"),
        seg(196, 202, "yeah that makes sense um and so like how far along is the the product like can I can I see it or"),
        seg(202, 208, "yeah totally I'll I'll send you a TestFlight link actually um we've got like the core inventory stuff working"),
        seg(208, 214, "and uh the ordering system is like about eighty percent done and then scheduling we haven't really started yet but that's that's the next sprint"),
    ]

    private static func seg(_ start: TimeInterval, _ end: TimeInterval, _ text: String) -> TranscriptSegment {
        TranscriptSegment(startTime: start, endTime: end, text: text)
    }
}
#endif
