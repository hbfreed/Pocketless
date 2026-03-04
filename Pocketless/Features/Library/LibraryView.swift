import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Recording.createdAt, order: .reverse) private var recordings: [Recording]

    var body: some View {
        NavigationStack {
            Group {
                if recordings.isEmpty {
                    ContentUnavailableView(
                        "No Recordings",
                        systemImage: "mic.slash",
                        description: Text("Record your first conversation from the Record tab.")
                    )
                } else {
                    List {
                        ForEach(recordings) { recording in
                            NavigationLink(value: recording) {
                                RecordingRow(recording: recording)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteRecording(recording)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Library")
            .navigationDestination(for: Recording.self) { recording in
                RecordingDetailView(recording: recording)
            }
        }
    }

    private func deleteRecording(_ recording: Recording) {
        try? FileManager.default.removeItem(at: recording.audioFileURL)
        modelContext.delete(recording)
    }
}

struct RecordingRow: View {
    let recording: Recording

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(recording.createdAt, style: .date)
                .font(.headline)

            HStack {
                Text(recording.createdAt, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("·")
                    .foregroundStyle(.secondary)

                Text(recording.formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(recording.statusText)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.fill.tertiary)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 2)
    }
}
