import SwiftUI
import SwiftData
import AVFoundation

struct RecordingDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var recording: Recording
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var playbackProgress: Double = 0
    @State private var playbackTimer: Timer?

    @State private var isTranscribing = false
    @State private var isCleaning = false
    @State private var isSummarizing = false
    @State private var showPresetPicker = false
    @State private var showRawTranscript = false
    @State private var editableCleanText = ""
    @State private var isEditingTranscript = false
    @State private var showExportSheet = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Metadata
                metadataSection

                // Playback
                playbackSection

                Divider()

                // Transcript
                transcriptSection

                Divider()

                // Summary
                summarySection
            }
            .padding()
        }
        .navigationTitle("Recording")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showExportSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showExportSheet) {
            ExportView(recording: recording)
        }
        .sheet(isPresented: $showPresetPicker) {
            PresetPickerView { preset, customPrompt in
                showPresetPicker = false
                Task { await summarize(preset: preset, customPrompt: customPrompt) }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
        .onDisappear {
            stopPlayback()
        }
    }

    // MARK: - Metadata

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(recording.createdAt.formatted(date: .long, time: .shortened), systemImage: "calendar")
                Spacer()
                Label(recording.formattedDuration, systemImage: "clock")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Playback

    private var playbackSection: some View {
        VStack(spacing: 12) {
            ProgressView(value: playbackProgress)
                .tint(.blue)

            HStack {
                Button {
                    togglePlayback()
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.blue)
                }

                Spacer()

                if let player = audioPlayer {
                    Text(formatTime(player.currentTime))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    Text("/")
                        .foregroundStyle(.secondary)
                    Text(formatTime(player.duration))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Transcript

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Transcript")
                    .font(.headline)

                Spacer()

                if recording.cleanTranscript != nil && recording.rawTranscript != nil {
                    Picker("View", selection: $showRawTranscript) {
                        Text("Clean").tag(false)
                        Text("Raw").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                }
            }

            if let transcript = showRawTranscript ? recording.rawTranscript : (recording.cleanTranscript ?? recording.rawTranscript) {
                if isEditingTranscript && !showRawTranscript && recording.cleanTranscript != nil {
                    TextEditor(text: $editableCleanText)
                        .frame(minHeight: 200)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.3)))

                    HStack {
                        Button("Cancel") {
                            isEditingTranscript = false
                        }
                        Spacer()
                        Button("Save") {
                            saveTranscriptEdits()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    TranscriptTextView(
                        segments: transcript.segments,
                        onTapTimestamp: { time in
                            seekTo(time: time)
                        }
                    )

                    if !showRawTranscript && recording.cleanTranscript != nil {
                        Button("Edit Transcript") {
                            editableCleanText = recording.cleanTranscript?.fullText ?? ""
                            isEditingTranscript = true
                        }
                        .font(.caption)
                    }
                }
            } else {
                Button {
                    Task { await transcribe() }
                } label: {
                    HStack {
                        if isTranscribing {
                            ProgressView()
                                .controlSize(.small)
                            Text("Transcribing...")
                        } else {
                            Image(systemName: "waveform")
                            Text("Transcribe")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isTranscribing)
            }

            if recording.rawTranscript != nil && recording.cleanTranscript == nil {
                Button {
                    Task { await cleanup() }
                } label: {
                    HStack {
                        if isCleaning {
                            ProgressView()
                                .controlSize(.small)
                            Text("Cleaning up...")
                        } else {
                            Image(systemName: "sparkles")
                            Text("Clean Up Transcript")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isCleaning)
            }
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Summary")
                .font(.headline)

            if recording.summaries.isEmpty {
                let hasTranscript = recording.cleanTranscript != nil || recording.rawTranscript != nil
                Button {
                    showPresetPicker = true
                } label: {
                    HStack {
                        if isSummarizing {
                            ProgressView()
                                .controlSize(.small)
                            Text("Summarizing...")
                        } else {
                            Image(systemName: "doc.text")
                            Text("Summarize")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!hasTranscript || isSummarizing)
            } else {
                ForEach(recording.summaries) { summary in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(summary.presetUsed.capitalized)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(.blue.opacity(0.1))
                                .clipShape(Capsule())

                            Text(summary.modelUsed)
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Text(summary.createdAt, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Text(summary.content)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                    .padding()
                    .background(.fill.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    showPresetPicker = true
                } label: {
                    Label("New Summary", systemImage: "plus")
                }
                .font(.caption)
            }
        }
    }

    // MARK: - Actions

    private func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }

    private func startPlayback() {
        do {
            if audioPlayer == nil {
                audioPlayer = try AVAudioPlayer(contentsOf: recording.audioFileURL)
                audioPlayer?.prepareToPlay()
            }
            audioPlayer?.play()
            isPlaying = true
            playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                guard let player = audioPlayer else { return }
                playbackProgress = player.duration > 0 ? player.currentTime / player.duration : 0
                if !player.isPlaying {
                    stopPlayback()
                }
            }
        } catch {
            errorMessage = "Playback failed: \(error.localizedDescription)"
            showError = true
        }
    }

    private func stopPlayback() {
        audioPlayer?.stop()
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    private func seekTo(time: TimeInterval) {
        do {
            if audioPlayer == nil {
                audioPlayer = try AVAudioPlayer(contentsOf: recording.audioFileURL)
                audioPlayer?.prepareToPlay()
            }
            audioPlayer?.currentTime = time
            audioPlayer?.play()
            isPlaying = true
            if playbackTimer == nil {
                playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                    guard let player = audioPlayer else { return }
                    playbackProgress = player.duration > 0 ? player.currentTime / player.duration : 0
                    if !player.isPlaying {
                        stopPlayback()
                    }
                }
            }
        } catch {
            errorMessage = "Playback failed: \(error.localizedDescription)"
            showError = true
        }
    }

    private func transcribe() async {
        isTranscribing = true
        defer { isTranscribing = false }

        do {
            let service = TranscriptionServiceFactory.create()
            let transcript = try await service.transcribe(audioURL: recording.audioFileURL)
            recording.rawTranscript = transcript

            // Auto-cleanup if enabled
            if UserDefaults.standard.bool(forKey: "cleanupEnabled") {
                await cleanup()
            }
        } catch {
            errorMessage = "Transcription failed: \(error.localizedDescription)"
            showError = true
        }
    }

    private func cleanup() async {
        guard let rawTranscript = recording.rawTranscript else { return }
        isCleaning = true
        defer { isCleaning = false }

        do {
            let cleanupService = TranscriptCleanup()
            let cleanTranscript = try await cleanupService.cleanup(transcript: rawTranscript)
            recording.cleanTranscript = cleanTranscript
        } catch {
            errorMessage = "Cleanup failed: \(error.localizedDescription)"
            showError = true
        }
    }

    private func summarize(preset: SummaryPreset, customPrompt: String?) async {
        let transcript = recording.cleanTranscript ?? recording.rawTranscript
        guard let transcript else { return }
        isSummarizing = true
        defer { isSummarizing = false }

        do {
            let service = SummarizationService()
            let summary = try await service.summarize(
                transcript: transcript,
                preset: preset,
                customPrompt: customPrompt
            )
            summary.recording = recording
            modelContext.insert(summary)
        } catch {
            errorMessage = "Summarization failed: \(error.localizedDescription)"
            showError = true
        }
    }

    private func saveTranscriptEdits() {
        guard let cleanTranscript = recording.cleanTranscript else { return }
        let segment = TranscriptSegment(startTime: 0, endTime: recording.duration, text: editableCleanText)
        cleanTranscript.segments = [segment]
        isEditingTranscript = false
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Timestamped Transcript View

struct TranscriptTextView: View {
    let segments: [TranscriptSegment]
    var onTapTimestamp: ((TimeInterval) -> Void)?

    var body: some View {
        if segments.count <= 1 {
            // Single segment — just show text without timestamp
            if let segment = segments.first {
                Text(segment.text)
                    .font(.body)
                    .textSelection(.enabled)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(segments) { segment in
                    HStack(alignment: .top, spacing: 8) {
                        Button {
                            onTapTimestamp?(segment.startTime)
                        } label: {
                            Text(formatTimestamp(segment.startTime))
                                .font(.caption.monospaced())
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)

                        Text(segment.text)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }

    private func formatTimestamp(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
