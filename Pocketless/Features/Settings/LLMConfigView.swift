import SwiftUI

struct LLMConfigView: View {
    @State private var config = LLMConfig()
    @State private var apiKeyInput = ""
    @State private var testResult: String?
    @State private var isTesting = false

    var body: some View {
        Form {
            Section("Endpoint") {
                TextField("Base URL", text: $config.baseURL)
                    .keyboardType(.URL)
                    .autocapitalization(.none)

                Text("Default: OpenRouter (https://openrouter.ai/api/v1)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Authentication") {
                SecureField("API Key", text: $apiKeyInput)
                    .autocapitalization(.none)

                Link("Get an OpenRouter API key", destination: URL(string: "https://openrouter.ai/keys")!)
                    .font(.caption)
            }

            Section("Model") {
                TextField("Model Name", text: $config.modelName)
                    .autocapitalization(.none)

                Text("Default: anthropic/claude-sonnet-4-20250514")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Stepper("Max Tokens: \(config.maxTokens)", value: $config.maxTokens, in: 256...16384, step: 256)
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
        .navigationTitle("LLM Provider")
        .onAppear(perform: loadConfig)
        .onDisappear(perform: saveConfig)
    }

    private func loadConfig() {
        if let data = UserDefaults.standard.data(forKey: "llmConfig"),
           let saved = try? JSONDecoder().decode(LLMConfig.self, from: data) {
            config = saved
        }
        apiKeyInput = KeychainService.load(key: LLMConfig.keychainKey) ?? ""
    }

    private func saveConfig() {
        if !apiKeyInput.isEmpty {
            try? KeychainService.save(key: LLMConfig.keychainKey, value: apiKeyInput)
        }
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: "llmConfig")
        }
    }

    private func testConnection() async {
        isTesting = true
        defer { isTesting = false }

        guard let url = URL(string: config.baseURL) else {
            testResult = "Invalid URL"
            return
        }

        let client = OpenAICompatibleClient(baseURL: url, apiKey: apiKeyInput)

        do {
            let response = try await client.chatCompletion(
                model: config.modelName,
                systemPrompt: "Respond with exactly: OK",
                userMessage: "Test",
                maxTokens: 10
            )
            testResult = "Success — \(response.prefix(50))"
        } catch {
            testResult = "Failed — \(error.localizedDescription)"
        }
    }
}
