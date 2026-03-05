import SwiftUI

struct ExportView: View {
    let recording: Recording
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFormat: ExportFormat = .markdown

    enum ExportFormat: String, CaseIterable, Identifiable {
        case plainText = "Plain Text"
        case markdown = "Markdown"
        case json = "JSON"

        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Format") {
                    Picker("Export Format", selection: $selectedFormat) {
                        ForEach(ExportFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.inline)
                }

                Section("Preview") {
                    ScrollView {
                        Text(exportContent)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 300)
                }

                Section {
                    ShareLink(item: exportContent) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        UIPasteboard.general.string = exportContent
                        dismiss()
                    } label: {
                        Label("Copy to Clipboard", systemImage: "doc.on.doc")
                    }
                }
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var exportContent: String {
        switch selectedFormat {
        case .plainText:
            return plainTextExport
        case .markdown:
            return markdownExport
        case .json:
            return jsonExport
        }
    }

    private var plainTextExport: String {
        var text = "Recording: \(recording.createdAt.formatted())\n"
        text += "Duration: \(recording.formattedDuration)\n\n"

        if let transcript = recording.cleanTranscript ?? recording.rawTranscript {
            text += "TRANSCRIPT\n"
            let segments = transcript.segments
            if segments.count > 1 {
                for segment in segments {
                    let timestamp = formatTimestamp(segment.startTime)
                    let speaker = segment.speaker.map { "\($0): " } ?? ""
                    text += "[\(timestamp)] \(speaker)\(segment.text)\n"
                }
            } else {
                text += transcript.fullText
            }
            text += "\n"
        }

        for summary in recording.summaries {
            text += "SUMMARY (\(summary.presetUsed))\n\(summary.content)\n\n"
        }

        return text
    }

    private var markdownExport: String {
        var text = "# Recording — \(recording.createdAt.formatted())\n\n"
        text += "**Duration:** \(recording.formattedDuration)\n\n"

        if let transcript = recording.cleanTranscript ?? recording.rawTranscript {
            text += "## Transcript\n\n"
            let segments = transcript.segments
            if segments.count > 1 {
                for segment in segments {
                    let timestamp = formatTimestamp(segment.startTime)
                    let speaker = segment.speaker.map { "**\($0):** " } ?? ""
                    text += "`\(timestamp)` \(speaker)\(segment.text)\n\n"
                }
            } else {
                text += "\(transcript.fullText)\n\n"
            }
        }

        for summary in recording.summaries {
            text += "## Summary (\(summary.presetUsed.capitalized))\n\n\(summary.content)\n\n"
        }

        return text
    }

    private var jsonExport: String {
        var dict: [String: Any] = [
            "createdAt": recording.createdAt.ISO8601Format(),
            "duration": recording.duration,
        ]

        if let transcript = recording.cleanTranscript ?? recording.rawTranscript {
            dict["transcript"] = transcript.fullText
            let segments = transcript.segments
            if segments.count > 1 {
                dict["segments"] = segments.map { segment in
                    var segDict: [String: Any] = [
                        "startTime": segment.startTime,
                        "endTime": segment.endTime,
                        "text": segment.text,
                    ]
                    if let speaker = segment.speaker {
                        segDict["speaker"] = speaker
                    }
                    return segDict
                }
            }
        }

        if !recording.summaries.isEmpty {
            dict["summaries"] = recording.summaries.map { summary in
                [
                    "preset": summary.presetUsed,
                    "model": summary.modelUsed,
                    "content": summary.content,
                ] as [String: String]
            }
        }

        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    private func formatTimestamp(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
