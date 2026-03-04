import AVFoundation
import Foundation
import Observation

@Observable
final class AudioRecorder {
    var isRecording = false
    var elapsedTime: TimeInterval = 0
    var powerSamples: [Float] = []
    var currentFileSize: Int64 = 0

    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var timer: Timer?
    private var startTime: Date?
    private(set) var outputURL: URL?

    private static var recordingsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func startRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])
        try session.setActive(true)

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        let filename = "recording_\(Date().timeIntervalSince1970).m4a"
        let url = Self.recordingsDirectory.appendingPathComponent(filename)
        outputURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: inputFormat.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 128_000,
        ]

        let file = try AVAudioFile(forWriting: url, settings: settings)
        audioFile = file

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }

            try? file.write(from: buffer)

            // Calculate RMS power for waveform
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameLength = Int(buffer.frameLength)
            var rms: Float = 0
            for i in 0..<frameLength {
                rms += channelData[i] * channelData[i]
            }
            rms = sqrt(rms / Float(frameLength))
            let power = max(0, min(1, rms * 5)) // Normalize to 0-1

            DispatchQueue.main.async {
                self.powerSamples.append(power)
                if self.powerSamples.count > 200 {
                    self.powerSamples.removeFirst()
                }
            }
        }

        try engine.start()
        audioEngine = engine
        startTime = Date()
        isRecording = true
        powerSamples = []

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let startTime = self.startTime else { return }
            self.elapsedTime = Date().timeIntervalSince(startTime)
            if let url = self.outputURL,
               let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) {
                self.currentFileSize = attrs[.size] as? Int64 ?? 0
            }
        }
    }

    func stopRecording() -> (url: URL, duration: TimeInterval)? {
        timer?.invalidate()
        timer = nil

        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        audioFile = nil

        isRecording = false
        let duration = elapsedTime
        elapsedTime = 0

        guard let url = outputURL else { return nil }
        return (url, duration)
    }

    var formattedElapsedTime: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: currentFileSize, countStyle: .file)
    }
}
