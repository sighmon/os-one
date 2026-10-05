import SwiftUI

struct SettingsView: View {
    @AppStorage("name") private var name = "Samantha"
    @AppStorage("overrideSystemPrompt") private var overrideSystemPrompt = ""
    @AppStorage("overrideVoiceID") private var overrideVoiceID = ""
    @AppStorage("overrideOpenAIModel") private var overrideOpenAIModel = ""
    @AppStorage("grokOverrideModel") private var grokOverrideModel = ""
    @AppStorage("openAIApiKey") private var openAIApiKey = ""
    @AppStorage("openAISessionKey") private var openAISessionKey = ""
    @AppStorage("grokApiKey") private var grokApiKey = ""
    @AppStorage("elevenLabsApiKey") private var elevenLabsApiKey = ""
    @AppStorage("elevenLabs") private var elevenLabs = false
    @AppStorage("openAIVoice") private var openAIVoice = false
    @AppStorage("grokVoice") private var grokVoice = false
    @AppStorage("grokVoiceID") private var grokVoiceID = "eve"
    @AppStorage("openAIVoiceID") private var openAIVoiceID = "nova"
    @StateObject private var openAIModels = ProviderModelList()
    @StateObject private var grokModels = ProviderModelList()
    @State private var openAIModelRefresh = 0
    @State private var grokModelRefresh = 0
    @State private var grokVoices: [SpeechVoice] = []
    @State private var voicesLoading = false
    @State private var voicesError: String?
    @State private var voiceRequestID = UUID()
    @State private var voiceRefresh = 0
    @AppStorage("allowLocation") private var allowLocation = false
    @AppStorage("allowSearch") private var allowSearch = false
    @AppStorage("vision") private var vision = false
    @AppStorage("gatewayURL") private var gatewayURL = ""
    @AppStorage("gatewayToken") private var gatewayToken = ""
    @AppStorage("gatewaySessionKey") private var gatewaySessionKey = "main"
    @State private var keyTestMessage = ""
    @State private var keyTestRunning = false
    @State private var usageMessage = ""
    @State private var provider = AssistantProvider.current
    @State private var gatewayTestInProgress = false
    @State private var gatewayTestMessage = ""
    @State private var showGatewayTestAlert = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TabView {
                personalityTab.tabItem { Label("Personality", systemImage: "person.crop.circle") }
                modelsTab.tabItem { Label("Models", systemImage: "cpu") }
                settingsTab.tabItem { Label("Settings", systemImage: "gearshape") }
            }
            .navigationTitle("OS One")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
            .onChange(of: provider) { $0.save() }
            .onChange(of: openAIApiKey) { _ in keyTestMessage = "" }
            .alert("Gateway Test", isPresented: $showGatewayTestAlert) {
                Button("OK", role: .cancel) {}
            } message: { Text(gatewayTestMessage) }
        }
    }

    private var personalityTab: some View {
        Form {
            Section("Personality") {
                        Picker("Name of your voice assistant", selection: $name) {
                            Group {
                                Text("Samantha").tag("Samantha")
                                Text("Custom").tag("Custom")
                                Text("KITT").tag("KITT")
                                Text("Mr.Robot").tag("Mr.Robot")
                                Text("Elliot").tag("Elliot")
                                Text("GLaDOS").tag("GLaDOS")
                                Text("Spock").tag("Spock")
                                Text("The Oracle").tag("The Oracle")
                                Text("Janet").tag("Janet")
                                Text("Moss").tag("Moss")
                            }
                            Group {
                                Text("Ava").tag("Ava")
                                Text("Darth Vader").tag("Darth Vader")
                                Text("Johnny Five").tag("Johnny Five")
                                Text("J.A.R.V.I.S.").tag("J.A.R.V.I.S.")
                                Text("Clawdbot").tag("Clawdbot")
                            }
                            Group {
                                Text("Amy Remeikis").tag("Amy Remeikis")
                                Text("Jane Caro").tag("Jane Caro")
                            }
                            Group {
                                Text("Martha Wells").tag("Murderbot")
                            }
                            Group {
                                Text("Fei-Fei Li").tag("Fei-Fei Li")
                                Text("Andrew Ng").tag("Andrew Ng")
                                Text("Corinna Cortes").tag("Corinna Cortes")
                                Text("Andrej Karpathy").tag("Andrej Karpathy")
                            }
                            Group {
                                Text("Judith Butler").tag("Butler")
                                Text("Noam Chomsky").tag("Chomsky")
                                Text("Angela Davis").tag("Davis")
                                Text("Slavoj Žižek").tag("Žižek")
                            }
                            Group {
                                Text("Seb Chan").tag("Seb Chan")
                            }
                        }

                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .frame(height: 250)
                    .labelsHidden()
                Text("Choose the personality your assistant uses in conversation.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Custom personality") {
                TextField("System prompt", text: $overrideSystemPrompt, axis: .vertical)
                    .lineLimit(4...10)
                TextField("ElevenLabs voice ID", text: $overrideVoiceID)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                Text("A custom prompt or voice overrides the selected personality. Clear these fields to use the preset again.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private var modelsTab: some View {
        Form {
            Section("Assistant") {
                Picker("Provider", selection: $provider) {
                    ForEach(AssistantProvider.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu)
            }
            Section("Voice") {
                Picker("Voice provider", selection: Binding(
                    get: { elevenLabs ? "elevenLabs" : (grokVoice ? "grok" : (openAIVoice ? "openAI" : "system")) },
                    set: { elevenLabs = $0 == "elevenLabs"; openAIVoice = $0 == "openAI"; grokVoice = $0 == "grok" }
                )) {
                    Text("System voice").tag("system")
                    Text("OpenAI").tag("openAI")
                    Text("Grok Voice").tag("grok")
                    Text("ElevenLabs").tag("elevenLabs")
                }
                .accessibilityIdentifier("voiceProviderPicker")
                if grokVoice {
                    SecureField("Grok API key", text: $grokApiKey)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    if grokApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Add your Grok API key to load available voices.").font(.footnote)
                    } else {
                        if voicesLoading { ProgressView("Loading voices…") }
                        if !grokVoices.isEmpty {
                            voiceWheel(voices: grokVoices, selection: $grokVoiceID)
                        }
                        if let error = voicesError { Text(error).font(.footnote).foregroundStyle(.secondary) }
                        Button("Refresh voices") { voiceRefresh += 1 }.disabled(voicesLoading)
                    }
                } else if openAIVoice {
                    SecureField("OpenAI API key", text: $openAIApiKey)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    voiceWheel(voices: SpeechVoice.openAI, selection: $openAIVoiceID)
                    Text("Choose from OpenAI's 13 built-in voices.")
                        .font(.footnote).foregroundStyle(.secondary)
                    if openAIApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Add your OpenAI API key to use this voice.").font(.footnote)
                    }
                } else if elevenLabs {
                    SecureField("ElevenLabs API key", text: $elevenLabsApiKey)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                }
            }
            Section("OpenAI") {
                modelPicker(selection: $overrideOpenAIModel, fallback: ModelCatalog.openAI,
                            list: openAIModels, apiKey: openAIApiKey, identifier: "openAICustomModel") {
                    openAIModelRefresh += 1
                }
                SecureField("OpenAI API key", text: $openAIApiKey)
                Button(keyTestRunning ? "Testing key…" : "Test API key") {
                    let key = openAIApiKey
                    keyTestRunning = true
                    keyTestMessage = ""
                    Task { @MainActor in
                        defer { keyTestRunning = false }
                        do {
                            let message = try await OpenAICredentials.test(apiKey: key)
                            if key == openAIApiKey { keyTestMessage = message }
                        } catch {
                            if key == openAIApiKey { keyTestMessage = error.localizedDescription }
                        }
                    }
                }.disabled(keyTestRunning)
                if !keyTestMessage.isEmpty { Text(keyTestMessage).font(.footnote) }
            }
            Section("xAI / Grok") {
                modelPicker(selection: $grokOverrideModel, fallback: ModelCatalog.grok,
                            list: grokModels, apiKey: grokApiKey, identifier: "grokCustomModel") {
                    grokModelRefresh += 1
                }
                SecureField("API key", text: $grokApiKey)
            }
            Section("Apple Foundation Models") {
                LabeledContent("Model", value: "On-device · System default")
                Text(appleModelAvailabilityMessage).font(.footnote).foregroundStyle(.secondary)
                Text("Text conversations run on this device without an API key. Camera analysis, web search and HomeKit tools are unavailable with this provider. Select System voice to avoid a cloud voice service.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("OpenClaw gateway") {
                TextField("Gateway URL (ws://host:18789)", text: $gatewayURL)
                SecureField("Gateway token (optional)", text: $gatewayToken)
                TextField("Session key", text: $gatewaySessionKey)
                Text("The model is configured by your gateway. Camera images are not supported by this connection.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button(action: testGatewayConnection) {
                    if gatewayTestInProgress { ProgressView() } else { Text("Test connection") }
                }
                .disabled(gatewayTestInProgress || gatewayURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .textInputAutocapitalization(.never).autocorrectionDisabled()
        .task(id: "\(openAIApiKey)-\(openAIModelRefresh)") {
            await openAIModels.load(provider: .openAI, apiKey: openAIApiKey)
        }
        .task(id: "\(grokApiKey)-\(grokModelRefresh)") {
            await grokModels.load(provider: .grok, apiKey: grokApiKey)
        }
        .task(id: "\(grokVoice)-\(grokApiKey)-\(voiceRefresh)") {
            await loadGrokVoices()
        }
    }

    private func modelPicker(selection: Binding<String>, fallback: [String], list: ProviderModelList,
                             apiKey: String, identifier: String, refresh: @escaping () -> Void) -> some View {
        let models = list.models ?? fallback
        return Group {
            Picker("Model", selection: selection) {
                Text("Latest (\(fallback[0]))").tag("")
                ForEach(models, id: \.self) { Text($0).tag($0) }
                if !selection.wrappedValue.isEmpty && !models.contains(selection.wrappedValue) {
                    Text("\(selection.wrappedValue) (custom)").tag(selection.wrappedValue)
                }
            }
            .pickerStyle(.menu)
            TextField("Model name or custom ID", text: selection)
                .accessibilityIdentifier(identifier)
            Text("Choose a chat model from the list or enter its name. Clear the name to use Latest.")
                .font(.footnote).foregroundStyle(.secondary)
            if list.isLoading { ProgressView("Loading models…") }
            if let error = list.errorMessage {
                Text("\(error) Showing built-in choices.").font(.footnote).foregroundStyle(.secondary)
            } else if list.models != nil {
                Text("Models loaded from your provider. Speech-only and image-generation models cannot be used for chat.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button("Refresh models", action: refresh).disabled(list.isLoading)
            } else {
                Text("Add an API key to load available models. Built-in choices and custom names work without loading the list.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private var settingsTab: some View {
        Form {
            Section("Features") {
                Toggle("Allow location", isOn: $allowLocation)
                Toggle("Allow web search", isOn: $allowSearch).disabled(!provider.supportsCamera)
                Toggle("Live camera", isOn: $vision).disabled(!provider.supportsCamera)
                Text("With the camera on, the latest frame is sent with your words when you finish speaking.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Account usage") {
                SecureField("OpenAI session key (optional)", text: $openAISessionKey)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("Check ElevenLabs usage") {
                    elevenLabsGetUsage { result in
                        DispatchQueue.main.async {
                            switch result {
                            case .success(let usage): usageMessage = "ElevenLabs: \(floatToPercent(float: usage)) used"
                            case .failure(let error): usageMessage = error.localizedDescription
                            }
                        }
                    }
                }.disabled(elevenLabsApiKey.isEmpty)
                Button("Check OpenAI usage") {
                    getOpenAIUsage { result in
                        DispatchQueue.main.async {
                            switch result {
                            case .success(let usage): usageMessage = String(format: "OpenAI: $%.2f", usage / 100)
                            case .failure(let error): usageMessage = error.localizedDescription
                            }
                        }
                    }
                }.disabled(openAISessionKey.isEmpty)
                if !usageMessage.isEmpty { Text(usageMessage).font(.footnote) }
            }
            Section("About") { LabeledContent("Version", value: appVersionAndBuild()) }
        }
    }

    private func voiceWheel(voices: [SpeechVoice], selection: Binding<String>) -> some View {
        Picker("Voice", selection: selection) {
            ForEach(voices) { Text($0.name).tag($0.id) }
            if !voices.contains(where: { $0.id == selection.wrappedValue }) {
                Text("\(selection.wrappedValue) (saved)").tag(selection.wrappedValue)
            }
        }
        .pickerStyle(.wheel)
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .labelsHidden()
        .accessibilityIdentifier("voiceWheel")
    }

    @MainActor private func loadGrokVoices() async {
        let requestID = UUID()
        voiceRequestID = requestID
        voicesLoading = false
        voicesError = nil
        grokVoices = []
        let key = grokApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard grokVoice, !key.isEmpty else { return }
        voicesLoading = true
        defer { if voiceRequestID == requestID { voicesLoading = false } }
        do {
            // Debounce key entry and cancel in-flight work when the provider or key changes.
            try await Task.sleep(nanoseconds: 400_000_000)
            let voices = try await GrokSpeechAPI.voices(apiKey: key)
            try Task.checkCancellation()
            guard voiceRequestID == requestID else { return }
            grokVoices = voices
        } catch {
            guard !Task.isCancelled, voiceRequestID == requestID else { return }
            voicesError = error.localizedDescription
        }
    }

    func testGatewayConnection() {
        gatewayTestInProgress = true
        let token = gatewayToken.isEmpty ? nil : gatewayToken
        let sessionKey = gatewaySessionKey.isEmpty ? "main" : gatewaySessionKey
        GatewayChatClient.shared.sendChatMessage(
            message: "ping",
            sessionKey: sessionKey,
            gatewayURL: gatewayURL,
            token: token
        ) { result in
            DispatchQueue.main.async {
                gatewayTestInProgress = false
                switch result {
                case .success(let content):
                    gatewayTestMessage = content.isEmpty ? "Gateway replied, but the message was empty." : content
                case .failure(let error):
                    gatewayTestMessage = "Gateway error: \(error.localizedDescription)"
                }
                showGatewayTestAlert = true
            }
        }
    }

    func appVersionAndBuild() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"

        return "\(version) (\(build))"
    }

    func floatToPercent(float: Float) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        return formatter.string(from: float as NSNumber) ?? "0%"
    }
}
