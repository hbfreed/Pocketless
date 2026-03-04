import SwiftUI

struct STTConfigView: View {
    @State private var config = STTConfig()
    @State private var apiKeyInput = ""
    @State private var testResult: String?
    @State private var isTesting = false

    var body: some View {
        Form {
            Section("Provider") {
                Picker("Provider", selection: $config.provider) {
                    Text("On-Device (WhisperKit)").tag(STTConfig.Provider.onDevice)
                    Text("Cloud (OpenAI-compatible)").tag(STTConfig.Provider.openaiCompatible)
                }
                .pickerStyle(.inline)
            }

            if config.provider == .openaiCompatible {
                Section("API Configuration") {
                    TextField("Base URL", text: Binding(
                        get: { config.baseURL ?? "https://api.openai.com/v1" },
                        set: { config.baseURL = $0 }
                    ))
                    .keyboardType(.URL)
                    .autocapitalization(.none)

                    SecureField("API Key", text: $apiKeyInput)
                        .autocapitalization(.none)

                    TextField("Model Name", text: Binding(
                        get: { config.modelName ?? "whisper-1" },
                        set: { config.modelName = $0 }
                    ))
                    .autocapitalization(.none)
                }

                Section {
                    Button {
                        Task { await testConnection() }
                    } label: {
                        HStack {
                            if isTesting {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Testing...")
                            } else {
                                Text("Test Connection")
                            }
                        }
                    }
                    .disabled(apiKeyInput.isEmpty || isTesting)

                    if let result = testResult {
                        Text(result)
                            .font(.caption)
                            .foregroundStyle(result.contains("Success") ? .green : .red)
                    }
                }
            }

            if config.provider == .onDevice {
                Section {
                    Text("On-device transcription uses WhisperKit with the large-v3-turbo model. No API key or network connection required.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("STT Provider")
        .onAppear(perform: loadConfig)
        .onDisappear(perform: saveConfig)
    }

    private func loadConfig() {
        if let data = UserDefaults.standard.data(forKey: "sttConfig"),
           let saved = try? JSONDecoder().decode(STTConfig.self, from: data) {
            config = saved
        }
        apiKeyInput = KeychainService.load(key: STTConfig.keychainKey) ?? ""
    }

    private func saveConfig() {
        config.apiKeyKeychainKey = STTConfig.keychainKey
        if !apiKeyInput.isEmpty {
            try? KeychainService.save(key: STTConfig.keychainKey, value: apiKeyInput)
        }
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: "sttConfig")
        }
    }

    private func testConnection() async {
        isTesting = true
        defer { isTesting = false }

        guard let baseURL = URL(string: config.baseURL ?? "") else {
            testResult = "Invalid URL"
            return
        }

        let client = OpenAICompatibleClient(baseURL: baseURL, apiKey: apiKeyInput)

        // Simple test: try to list models (most OpenAI-compatible APIs support this)
        var request = URLRequest(url: baseURL.appendingPathComponent("models"))
        request.setValue("Bearer \(apiKeyInput)", forHTTPHeaderField: "Authorization")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                testResult = "Success — Connection verified"
            } else {
                testResult = "Failed — Check your URL and API key"
            }
        } catch {
            testResult = "Failed — \(error.localizedDescription)"
        }
    }
}
