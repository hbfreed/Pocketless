import SwiftUI

struct LLMConfigView: View {
    @State private var config = LLMConfig()
    @State private var apiKeyInput = ""
    @State private var testResult: String?
    @State private var isTesting = false

    var body: some View {
        Form {
            Section("Provider") {
                Picker("Provider", selection: $config.providerType) {
                    ForEach(LLMProviderType.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .onChange(of: config.providerType) { _, newValue in
                    config.baseURL = newValue.defaultBaseURL
                    config.modelName = newValue.defaultModel
                    testResult = nil
                }
            }

            Section("Endpoint") {
                if config.providerType == .custom {
                    TextField("Base URL", text: $config.baseURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                } else {
                    LabeledContent("Base URL", value: config.baseURL)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Authentication") {
                SecureField("API Key", text: $apiKeyInput)
                    .autocapitalization(.none)

                if let keyURL = config.providerType.keyURL,
                   let url = URL(string: keyURL) {
                    Link("Get a \(config.providerType.displayName) API key", destination: url)
                        .font(.caption)
                }
            }

            Section("Model") {
                TextField("Model Name", text: $config.modelName)
                    .autocapitalization(.none)

                if config.providerType != .custom {
                    Text("Default: \(config.providerType.defaultModel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

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

        // Temporarily save key so makeProvider() can find it
        if !apiKeyInput.isEmpty {
            try? KeychainService.save(key: LLMConfig.keychainKey, value: apiKeyInput)
        }

        guard let provider = config.makeProvider() else {
            testResult = "Invalid URL or missing API key"
            return
        }

        do {
            let response = try await provider.chatCompletion(
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
