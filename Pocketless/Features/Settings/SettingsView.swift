import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage("cleanupEnabled") private var cleanupEnabled = true
    @AppStorage("autoSummarize") private var autoSummarize = false
    @AppStorage("defaultPreset") private var defaultPreset = "fast"
    @State private var storageUsage: String = "Calculating..."
    @Environment(\.modelContext) private var modelContext
    #if DEBUG
    @State private var testTranscriptLoaded = false
    @State private var testTranscriptError: String?
    #endif

    var body: some View {
        NavigationStack {
            Form {
                Section("Speech-to-Text") {
                    NavigationLink("STT Provider") {
                        STTConfigView()
                    }
                }

                Section("LLM Provider") {
                    NavigationLink("LLM Configuration") {
                        LLMConfigView()
                    }
                }

                Section("Processing") {
                    Toggle("Transcript Cleanup", isOn: $cleanupEnabled)
                    Toggle("Auto-Summarize", isOn: $autoSummarize)
                }

                Section("Storage") {
                    HStack {
                        Text("Recordings")
                        Spacer()
                        Text(storageUsage)
                            .foregroundStyle(.secondary)
                    }

                    Button("Clear All Recordings", role: .destructive) {
                        clearRecordings()
                    }
                }

                #if DEBUG
                Section("Debug") {
                    Button("Load Test Transcript") {
                        do {
                            try TestTranscriptLoader.loadTestRecording(context: modelContext)
                            testTranscriptLoaded = true
                        } catch {
                            testTranscriptError = error.localizedDescription
                        }
                    }
                    .disabled(testTranscriptLoaded)

                    if testTranscriptLoaded {
                        Text("Test transcript loaded!")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                    if let error = testTranscriptError {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
                #endif

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    Link("Source Code", destination: URL(string: "https://github.com/hbfreed/Pocketless")!)
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                calculateStorageUsage()
            }
        }
    }

    private func calculateStorageUsage() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsDir = docs.appendingPathComponent("Recordings")

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: recordingsDir, includingPropertiesForKeys: [.fileSizeKey]
        ) else {
            storageUsage = "0 bytes"
            return
        }

        var totalSize: Int64 = 0
        for file in files {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: file.path) {
                totalSize += attrs[.size] as? Int64 ?? 0
            }
        }

        storageUsage = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    private func clearRecordings() {
        // Delete SwiftData objects
        do {
            let recordings = try modelContext.fetch(FetchDescriptor<Recording>())
            for recording in recordings {
                modelContext.delete(recording)
            }
            try modelContext.save()
        } catch {
            // Continue to file cleanup even if DB delete fails
        }

        // Delete audio files from disk
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsDir = docs.appendingPathComponent("Recordings")
        try? FileManager.default.removeItem(at: recordingsDir)
        try? FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true)
        calculateStorageUsage()
    }
}
