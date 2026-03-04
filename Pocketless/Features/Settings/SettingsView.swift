import SwiftUI

struct SettingsView: View {
    @AppStorage("cleanupEnabled") private var cleanupEnabled = true
    @AppStorage("autoSummarize") private var autoSummarize = false
    @AppStorage("defaultPreset") private var defaultPreset = "quick"
    @State private var storageUsage: String = "Calculating..."

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

                    Picker("Default Preset", selection: $defaultPreset) {
                        ForEach(SummaryPreset.allCases.filter { $0 != .custom }) { preset in
                            Text(preset.displayName).tag(preset.rawValue)
                        }
                    }
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

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    Link("Source Code", destination: URL(string: "https://github.com")!)
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
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsDir = docs.appendingPathComponent("Recordings")
        try? FileManager.default.removeItem(at: recordingsDir)
        try? FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true)
        calculateStorageUsage()
    }
}
