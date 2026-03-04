import SwiftUI

struct PresetPickerView: View {
    let onSelect: (SummaryPreset, String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var customPrompt = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(SummaryPreset.allCases) { preset in
                    if preset == .custom {
                        Section("Custom Prompt") {
                            TextEditor(text: $customPrompt)
                                .frame(minHeight: 100)

                            Button("Summarize with Custom Prompt") {
                                onSelect(.custom, customPrompt)
                            }
                            .disabled(customPrompt.isEmpty)
                        }
                    } else {
                        Button {
                            onSelect(preset, nil)
                        } label: {
                            HStack {
                                Image(systemName: preset.icon)
                                    .frame(width: 24)
                                    .foregroundStyle(.blue)

                                VStack(alignment: .leading) {
                                    Text(preset.displayName)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(preset.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Choose Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
