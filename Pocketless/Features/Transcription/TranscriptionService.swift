import Foundation

protocol TranscriptionService {
    func transcribe(audioURL: URL) async throws -> Transcript
}

enum TranscriptionServiceFactory {
    static func create() -> TranscriptionService {
        let configData = UserDefaults.standard.data(forKey: "sttConfig")
        let config = configData.flatMap { try? JSONDecoder().decode(STTConfig.self, from: $0) } ?? STTConfig()

        switch config.provider {
        case .onDevice:
            return WhisperKitService()
        case .openaiCompatible:
            return CloudSTTService(config: config)
        }
    }
}
