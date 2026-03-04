import SwiftUI
import SwiftData

struct RecordingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var recorder = AudioRecorder()
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                if recorder.isRecording {
                    WaveformView(samples: recorder.powerSamples)
                        .frame(height: 100)
                        .padding(.horizontal)

                    Text(recorder.formattedElapsedTime)
                        .font(.system(size: 48, weight: .light, design: .monospaced))
                        .foregroundStyle(.primary)

                    Text(recorder.formattedFileSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Tap to Record")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    if recorder.isRecording {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(recorder.isRecording ? Color.red.opacity(0.2) : Color.red.opacity(0.1))
                            .frame(width: 96, height: 96)

                        Circle()
                            .fill(Color.red)
                            .frame(width: recorder.isRecording ? 36 : 72, height: recorder.isRecording ? 36 : 72)
                            .clipShape(RoundedRectangle(cornerRadius: recorder.isRecording ? 8 : 36))
                    }
                    .animation(.easeInOut(duration: 0.2), value: recorder.isRecording)
                }

                Spacer()
                    .frame(height: 60)
            }
            .navigationTitle("Record")
            .alert("Recording Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func startRecording() {
        do {
            try recorder.startRecording()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func stopRecording() {
        guard let result = recorder.stopRecording() else { return }

        let recording = Recording(
            duration: result.duration,
            audioFileName: result.url.lastPathComponent
        )
        modelContext.insert(recording)
    }
}
